#!/usr/bin/env python3
"""
PiTrac Web Server - Lightweight replacement for TomEE
Serves dashboard, handles ActiveMQ messages, and manages shot images
"""

import asyncio
import json
import logging
import os
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
        
    def on_error(self, frame):
        logger.error(f'ActiveMQ error: {frame.body}')
        
    def on_message(self, frame):
        """Process incoming message from ActiveMQ"""
        try:
            data = msgpack.unpackb(frame.body, raw=False)
            asyncio.create_task(process_shot_data(data))
        except Exception as e:
            logger.error(f"Error processing message: {e}")
            
    def on_connected(self, frame):
        logger.info("Connected to ActiveMQ")
        self.connected = True
        
    def on_disconnected(self):
        logger.warning("Disconnected from ActiveMQ")
        self.connected = False


async def process_shot_data(data: Dict):
    """Process shot data and notify clients"""
    global current_shot
    
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
    
    current_shot["timestamp"] = datetime.now().isoformat()
    
    if "image_paths" in data:
        current_shot["images"] = data["image_paths"]
    
    for client in websocket_clients:
        try:
            await client.send_json(current_shot)
        except:
            websocket_clients.remove(client)


def setup_activemq():
    """Connect to ActiveMQ broker"""
    try:
        config = {}
        if CONFIG_FILE.exists():
            with open(CONFIG_FILE) as f:
                config = yaml.safe_load(f)
        
        broker_host = config.get("network", {}).get("broker_host", "localhost")
        broker_port = config.get("network", {}).get("broker_port", 61613)  # STOMP port
        
        conn = stomp.Connection([(broker_host, broker_port)])
        listener = ActiveMQListener()
        conn.set_listener('', listener)
        conn.connect('admin', 'admin', wait=True)
        conn.subscribe(destination='/topic/pitrac.shots', id=1, ack='auto')
        
        logger.info(f"Connected to ActiveMQ at {broker_host}:{broker_port}")
        return conn
    except Exception as e:
        logger.error(f"Failed to connect to ActiveMQ: {e}")
        return None


@app.on_event("startup")
async def startup_event():
    """Initialize connections on startup"""
    app.state.mq_conn = setup_activemq()


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
    
    return {
        "status": "healthy",
        "activemq_connected": mq_connected,
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