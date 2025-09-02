#!/usr/bin/env python3
"""
PiTrac Web Server - Lightweight replacement for TomEE
Serves dashboard, handles ActiveMQ messages, and manages shot images
"""

import asyncio
import base64
import json
import logging
import os
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional, List
from enum import Enum

import msgpack
import stomp
import yaml
from fastapi import FastAPI, WebSocket, Request, WebSocketDisconnect
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import shutil
from PIL import Image
import uvicorn

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="PiTrac Dashboard")
templates = Jinja2Templates(directory="templates")

HOME_DIR = Path.home()
PITRAC_DIR = HOME_DIR / ".pitrac"
IMAGES_DIR = HOME_DIR / "LM_Shares" / "Images"
CONFIG_FILE = PITRAC_DIR / "config" / "pitrac.yaml"

IMAGES_DIR.mkdir(parents=True, exist_ok=True)

app.mount("/static", StaticFiles(directory="static"), name="static")
app.mount("/images", StaticFiles(directory=str(IMAGES_DIR)), name="images")

current_shot = {
    "speed": 0.0,
    "carry": 0.0,
    "launch_angle": 0.0,
    "side_angle": 0.0,
    "back_spin": 0,
    "side_spin": 0,
    "result_type": "Waiting for ball...",
    "message": "",
    "timestamp": None,
    "images": []
}

websocket_clients: List[WebSocket] = []


class ResultType(Enum):
    UNKNOWN = 0
    INITIALIZING = 1
    WAITING_FOR_BALL = 2
    WAITING_FOR_SIMULATOR = 3
    PAUSING_FOR_STABILIZATION = 4
    MULTIPLE_BALLS = 5
    BALL_READY = 6
    HIT = 7
    ERROR = 8
    CALIBRATION = 9


class ActiveMQListener(stomp.ConnectionListener):
    """Listen for messages from ActiveMQ"""

    def __init__(self):
        self.connected = False
        self.loop = None 

    def on_error(self, frame):
        logger.error(f'ActiveMQ error: {frame.body}')

    def on_message(self, frame):
        """Process incoming message from ActiveMQ"""
        try:
            if hasattr(frame, 'body'):
                if isinstance(frame.body, bytes):
                    body = frame.body
                else:
                    try:
                        body = bytes(frame.body, 'latin-1')
                    except:
                        body = bytes([ord(c) if ord(c) < 256 else ord(c) & 0xFF for c in frame.body])


                if hasattr(frame, 'headers'):
                    logger.info(f"Frame headers: {frame.headers}")

                    if frame.headers.get('encoding') == 'base64':
                        logger.info("Message is base64 encoded, decoding...")
                        if isinstance(body, bytes):
                            base64_str = body.decode('utf-8')
                        else:
                            base64_str = body
                        msgpack_data = base64.b64decode(base64_str)
                        logger.info(f"Decoded {len(msgpack_data)} bytes from base64")
                    else:
                        msgpack_data = body
                else:
                    # No headers, assume old format
                    msgpack_data = body

                # Unpack msgpack data
                data = msgpack.unpackb(msgpack_data, raw=False, strict_map_key=False)

                if self.loop:
                    asyncio.run_coroutine_threadsafe(process_shot_data(data), self.loop)
                else:
                    logger.error("Event loop not set in listener")
            else:
                logger.error("Frame has no body attribute")
        except Exception as e:
            logger.error(f"Error processing message: {e}")

    def on_connected(self, frame):
        logger.info("Connected to ActiveMQ")
        self.connected = True

    def on_disconnected(self):
        logger.warning("Disconnected from ActiveMQ")
        self.connected = False


async def process_shot_data(data):
    """Process shot data and notify clients"""
    global current_shot

    if isinstance(data, list):
        # Array format from C++ MessagePack (MSGPACK_DEFINE order)
        # [carry_meters, speed_mpers, launch_angle_deg, side_angle_deg,
        #  back_spin_rpm, side_spin_rpm, confidence, club_type, result_type, message, log_messages]
        if len(data) >= 11:
            carry_meters = data[0]
            speed_mpers = data[1]
            launch_angle_deg = data[2]
            side_angle_deg = data[3]
            back_spin_rpm = data[4]
            side_spin_rpm = data[5]
            confidence = data[6]
            club_type = data[7]
            result_type = data[8]
            message = data[9]
            log_messages = data[10] if len(data) > 10 else []

            # Convert to UI format
            current_shot["carry"] = carry_meters
            current_shot["speed"] = round(speed_mpers * 2.237, 1)  # Convert m/s to mph
            current_shot["launch_angle"] = round(launch_angle_deg, 1)
            current_shot["side_angle"] = round(side_angle_deg, 1)
            current_shot["back_spin"] = int(back_spin_rpm)
            current_shot["side_spin"] = int(side_spin_rpm)

            try:
                current_shot["result_type"] = ResultType(result_type).name.replace("_", " ").title()
            except:
                current_shot["result_type"] = f"Type {result_type}"

            current_shot["message"] = message
            logger.info(f"Processed shot: speed={current_shot['speed']} mph, launch={current_shot['launch_angle']}°, side={current_shot['side_angle']}°")
    else:
        if "speed" in data:
            current_shot["speed"] = round(data["speed"], 1)
        if "carry" in data:
            current_shot["carry"] = round(data["carry"], 1)
        if "launch_angle" in data:
            current_shot["launch_angle"] = round(data["launch_angle"], 1)
        if "side_angle" in data:
            current_shot["side_angle"] = round(data["side_angle"], 1)
        if "back_spin" in data:
            current_shot["back_spin"] = int(data["back_spin"])
        if "side_spin" in data:
            current_shot["side_spin"] = int(data["side_spin"])
        if "result_type" in data:
            current_shot["result_type"] = ResultType(data["result_type"]).name.replace("_", " ").title()
        if "message" in data:
            current_shot["message"] = data["message"]
        if "image_paths" in data:
            current_shot["images"] = data["image_paths"]

    current_shot["timestamp"] = datetime.now().isoformat()

    for client in websocket_clients:
        try:
            await client.send_json(current_shot)
        except:
            websocket_clients.remove(client)


def setup_activemq(loop=None):
    """Connect to ActiveMQ broker"""
    try:
        config = {}
        if CONFIG_FILE.exists():
            with open(CONFIG_FILE) as f:
                config = yaml.safe_load(f)

        broker_address = config.get("network", {}).get("broker_address", "tcp://localhost:61616")
        if broker_address.startswith("tcp://"):
            broker_address = broker_address[6:]  # Remove tcp:// prefix

        if ":" in broker_address:
            broker_host = broker_address.split(":")[0]
        else:
            broker_host = broker_address
        broker_port = 61613  # Always use STOMP port

        conn = stomp.Connection([(broker_host, broker_port)])
        listener = ActiveMQListener()
        listener.loop = loop  # Set the event loop in the listener
        conn.set_listener('', listener)
        conn.connect('admin', 'admin', wait=True)
        conn.subscribe(destination='/topic/Golf.Sim', id=1, ack='auto')

        logger.info(f"Connected to ActiveMQ at {broker_host}:{broker_port}")
        return conn
    except Exception as e:
        logger.error(f"Failed to connect to ActiveMQ: {e}")
        return None


@app.on_event("startup")
async def startup_event():
    """Initialize connections on startup"""
    loop = asyncio.get_event_loop()
    app.state.mq_conn = setup_activemq(loop)


@app.on_event("shutdown")
async def shutdown_event():
    """Clean up connections on shutdown"""
    if hasattr(app.state, 'mq_conn') and app.state.mq_conn:
        app.state.mq_conn.disconnect()


@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    """Serve the main dashboard"""
    return templates.TemplateResponse(
        "dashboard.html",
        {"request": request, "shot": current_shot}
    )


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket for live updates"""
    await websocket.accept()
    websocket_clients.append(websocket)

    await websocket.send_json(current_shot)

    try:
        while True:
            # In testing, this will raise WebSocketDisconnect when client disconnects
            await websocket.receive_text()
    except (WebSocketDisconnect, Exception):
        if websocket in websocket_clients:
            websocket_clients.remove(websocket)


@app.get("/api/shot")
async def get_current_shot():
    """REST API endpoint for current shot data"""
    return current_shot


@app.get("/api/images/{filename}")
async def get_image(filename: str):
    """Serve shot images"""
    image_path = IMAGES_DIR / filename
    if image_path.exists():
        return FileResponse(image_path)
    return {"error": "Image not found"}



@app.post("/api/reset")
async def reset_shot():
    """Reset current shot data"""
    global current_shot
    current_shot = {
        "speed": 0.0,
        "carry": 0.0,
        "launch_angle": 0.0,
        "side_angle": 0.0,
        "back_spin": 0,
        "side_spin": 0,
        "result_type": "Waiting for ball...",
        "message": "",
        "timestamp": None,
        "images": []
    }

    for client in websocket_clients:
        try:
            await client.send_json(current_shot)
        except:
            pass

    return {"status": "reset"}


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    mq_connected = False
    if hasattr(app.state, 'mq_conn') and app.state.mq_conn:
        mq_connected = app.state.mq_conn.is_connected()

    pitrac_running = False
    try:
        result = subprocess.run(["pgrep", "-f", "golf_sim"],
                              capture_output=True, text=True, timeout=1)
        pitrac_running = result.returncode == 0
    except:
        pass

    activemq_running = False
    try:
        result = subprocess.run(["ss", "-tln"],
                              capture_output=True, text=True, timeout=1)
        activemq_running = ":61616" in result.stdout or ":61613" in result.stdout
    except:
        pass

    return {
        "status": "healthy",
        "activemq_connected": mq_connected,
        "activemq_running": activemq_running,
        "pitrac_running": pitrac_running,
        "websocket_clients": len(websocket_clients)
    }


if __name__ == "__main__":
    # Run with auto-reload for development
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8080,
        reload=True,
        log_level="info"
    )