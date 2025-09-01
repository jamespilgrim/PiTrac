import asyncio
import json
import pytest
from unittest.mock import MagicMock, AsyncMock, patch
from fastapi.testclient import TestClient


@pytest.mark.websocket
class TestWebSocket:
    """Test WebSocket real-time updates"""
    
    def test_websocket_connection(self, client):
        """Test WebSocket connection establishment"""
        from main import websocket_clients
        
        websocket_clients.clear()
        
        with client.websocket_connect("/ws") as websocket:
            data = websocket.receive_json()
            assert "speed" in data
            assert "carry" in data
            assert "timestamp" in data
            
            assert len(websocket_clients) == 1
        
        assert len(websocket_clients) == 0
    
    def test_websocket_receives_updates(self, client):
        """Test WebSocket receives shot updates"""
        from main import current_shot, websocket_clients
        
        websocket_clients.clear()
        
        test_data = {
            "speed": 155.5,
            "carry": 285.0,
            "launch_angle": 14.2,
            "side_angle": 1.5,
            "back_spin": 3200,
            "side_spin": 150,
            "result_type": "Hit",
            "message": "Perfect strike!",
            "timestamp": "2024-01-01T12:00:00"
        }
        current_shot.update(test_data)
        
        with client.websocket_connect("/ws") as websocket:
            data = websocket.receive_json()
            assert data["speed"] == 155.5
            assert data["carry"] == 285.0
            assert data["message"] == "Perfect strike!"
    
    def test_multiple_websocket_clients(self, client):
        """Test multiple WebSocket clients can connect"""
        from main import websocket_clients
        
        websocket_clients.clear()
        
        with client.websocket_connect("/ws") as ws1:
            ws1.receive_json()
            assert len(websocket_clients) == 1
            
            with client.websocket_connect("/ws") as ws2:
                ws2.receive_json()
                assert len(websocket_clients) == 2
                
                with client.websocket_connect("/ws") as ws3:
                    ws3.receive_json()
                    assert len(websocket_clients) == 3
                
                assert len(websocket_clients) == 2
            
            assert len(websocket_clients) == 1
        
        assert len(websocket_clients) == 0
    
    def test_websocket_disconnection_handling(self, client):
        """Test WebSocket disconnection is handled properly"""
        from main import websocket_clients
        
        websocket_clients.clear()
        
        with client.websocket_connect("/ws") as websocket:
            websocket.receive_json()
            assert len(websocket_clients) == 1
        
        assert len(websocket_clients) == 0
    
    def test_websocket_reconnection(self, client):
        """Test WebSocket reconnection scenario"""
        from main import current_shot, websocket_clients
        
        websocket_clients.clear()
        
        current_shot["speed"] = 100.0
        
        with client.websocket_connect("/ws") as ws1:
            data1 = ws1.receive_json()
            assert "speed" in data1
            assert data1["speed"] == 100.0
        
        current_shot["speed"] = 200.0
        
        with client.websocket_connect("/ws") as ws2:
            data2 = ws2.receive_json()
            assert "speed" in data2
            assert data2["speed"] == 200.0


@pytest.mark.asyncio
@pytest.mark.websocket
class TestWebSocketAsync:
    """Async WebSocket tests for real-time shot updates"""
    
    async def test_websocket_shot_update_flow(self, app):
        """Test complete flow of shot update through WebSocket"""
        from main import process_shot_data, websocket_clients
        
        websocket_clients.clear()
        
        mock_ws = AsyncMock()
        mock_ws.send_json = AsyncMock()
        websocket_clients.append(mock_ws)
        
        shot_data = {
            "speed": 165.0,
            "carry": 295.0,
            "launch_angle": 15.5,
            "side_angle": -1.2,
            "back_spin": 2750,
            "side_spin": -200,
            "result_type": 7,
            "message": "Excellent shot!",
            "image_paths": ["shot_123.jpg"]
        }
        
        await process_shot_data(shot_data)
        
        mock_ws.send_json.assert_called()
        call_args = mock_ws.send_json.call_args[0][0]
        assert call_args["speed"] == 165.0
        assert call_args["carry"] == 295.0
        assert "timestamp" in call_args
        
        websocket_clients.clear()
    
    async def test_websocket_broadcast_to_all_clients(self, app):
        """Test that updates are broadcast to all connected clients"""
        from main import process_shot_data, websocket_clients
        
        websocket_clients.clear()
        
        mock_clients = []
        for i in range(5):
            mock_ws = AsyncMock()
            mock_ws.send_json = AsyncMock()
            mock_clients.append(mock_ws)
            websocket_clients.append(mock_ws)
        
        shot_data = {
            "speed": 145.0,
            "carry": 265.0,
            "launch_angle": 12.0,
            "side_angle": 0.0,
            "back_spin": 3000,
            "side_spin": 0,
            "result_type": 7,
            "message": "Straight shot"
        }
        
        await process_shot_data(shot_data)
        
        for mock_ws in mock_clients:
            mock_ws.send_json.assert_called_once()
            call_args = mock_ws.send_json.call_args[0][0]
            assert call_args["speed"] == 145.0
            assert call_args["message"] == "Straight shot"
        
        websocket_clients.clear()
    
    async def test_websocket_client_error_handling(self, app):
        """Test handling of client errors during broadcast"""
        from main import process_shot_data, websocket_clients
        
        websocket_clients.clear()
        
        good_client = AsyncMock()
        good_client.send_json = AsyncMock()
        
        bad_client = AsyncMock()
        bad_client.send_json = AsyncMock(side_effect=Exception("Connection lost"))
        
        websocket_clients.extend([good_client, bad_client])
        
        shot_data = {"speed": 150.0, "carry": 270.0}
        await process_shot_data(shot_data)
        
        good_client.send_json.assert_called_once()
        
        assert bad_client not in websocket_clients
        assert good_client in websocket_clients
        
        websocket_clients.clear()