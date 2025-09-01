import asyncio
import json
import os
import sys
from pathlib import Path
from typing import AsyncGenerator, Generator
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient
from httpx import AsyncClient

sys.path.insert(0, str(Path(__file__).parent.parent))

# Set test environment
os.environ["TESTING"] = "true"


@pytest.fixture
def mock_activemq():
    """Mock ActiveMQ connection"""
    with patch('main.stomp.Connection') as mock_conn:
        mock_instance = MagicMock()
        mock_conn.return_value = mock_instance
        mock_instance.is_connected.return_value = True
        yield mock_instance


@pytest.fixture
def app(mock_activemq):
    """Create FastAPI app instance with mocked dependencies"""
    from main import app as _app
    
    # Mock the ActiveMQ connection in app state
    _app.state.mq_conn = mock_activemq
    
    return _app


@pytest.fixture
def client(app):
    """Create test client for synchronous tests"""
    return TestClient(app)


@pytest.fixture
async def async_client(app) -> AsyncGenerator:
    """Create async test client for async tests"""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def sample_shot_data():
    """Sample shot data for testing"""
    return {
        "speed": 145.5,
        "carry": 265.3,
        "launch_angle": 12.4,
        "side_angle": -2.1,
        "back_spin": 2850,
        "side_spin": -320,
        "result_type": 7,  # HIT
        "message": "Great shot!",
        "image_paths": ["shot_001.jpg", "shot_002.jpg"]
    }


@pytest.fixture
def mock_home_dir(tmp_path):
    """Mock home directory for testing"""
    home = tmp_path / "home"
    home.mkdir()
    
    (home / ".pitrac" / "config").mkdir(parents=True)
    (home / "LM_Shares" / "Images").mkdir(parents=True)
    
    # Create a test config file
    config = {
        "network": {
            "broker_host": "localhost",
            "broker_port": 61613
        }
    }
    
    config_file = home / ".pitrac" / "config" / "pitrac.yaml"
    import yaml
    with open(config_file, 'w') as f:
        yaml.dump(config, f)
    
    with patch('main.Path.home', return_value=home):
        yield home


@pytest.fixture
def mock_websocket():
    """Mock WebSocket for testing"""
    ws = MagicMock()
    ws.accept = MagicMock(return_value=asyncio.coroutine(lambda: None)())
    ws.send_json = MagicMock(return_value=asyncio.coroutine(lambda: None)())
    ws.receive_text = MagicMock(side_effect=asyncio.TimeoutError)
    return ws


@pytest.fixture
def shot_simulator():
    """Factory for simulating golf shots"""
    class ShotSimulator:
        @staticmethod
        def generate_shot(
            speed_range=(100, 180),
            carry_range=(150, 350),
            launch_range=(8, 20),
            side_range=(-5, 5),
            backspin_range=(1500, 4000),
            sidespin_range=(-1000, 1000)
        ):
            """Generate random realistic shot data"""
            import random
            
            return {
                "speed": round(random.uniform(*speed_range), 1),
                "carry": round(random.uniform(*carry_range), 1),
                "launch_angle": round(random.uniform(*launch_range), 1),
                "side_angle": round(random.uniform(*side_range), 1),
                "back_spin": random.randint(*backspin_range),
                "side_spin": random.randint(*sidespin_range),
                "result_type": 7,  # HIT
                "message": random.choice([
                    "Great shot!",
                    "Nice swing!",
                    "Perfect contact!",
                    "Solid strike!"
                ]),
                "image_paths": [f"shot_{random.randint(1000, 9999)}.jpg"]
            }
        
        @staticmethod
        def generate_sequence(count=10):
            """Generate a sequence of shots"""
            return [ShotSimulator.generate_shot() for _ in range(count)]
    
    return ShotSimulator()


@pytest.fixture(autouse=True)
def reset_singleton_state():
    """Reset any singleton state between tests"""
    # Reset current_shot data
    from main import current_shot, websocket_clients
    
    current_shot.clear()
    current_shot.update({
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
    })
    
    websocket_clients.clear()
    
    yield
    
    current_shot.clear()
    websocket_clients.clear()