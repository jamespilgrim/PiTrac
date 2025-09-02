import json
import msgpack
import pytest
from unittest.mock import MagicMock, patch, call


@pytest.mark.integration
class TestActiveMQIntegration:
    """Test ActiveMQ message handling"""
    
    def test_activemq_connection_setup(self, app, mock_activemq):
        """Test ActiveMQ connection is established on startup"""
        assert hasattr(app.state, 'mq_conn')
        assert app.state.mq_conn == mock_activemq
        assert mock_activemq.is_connected.return_value is True
    
    def test_activemq_listener_processes_messages(self):
        """Test ActiveMQ listener processes incoming messages"""
        from main import ActiveMQListener
        
        listener = ActiveMQListener()
        
        mock_loop = MagicMock()
        listener.loop = mock_loop
        
        shot_data = {
            "speed": 150.0,
            "carry": 270.0,
            "launch_angle": 13.0,
            "side_angle": 0.5,
            "back_spin": 2900,
            "side_spin": 50,
            "result_type": 7,
            "message": "Good shot"
        }
        
        packed_data = msgpack.packb(shot_data)
        
        mock_frame = MagicMock()
        mock_frame.body = packed_data
        
        with patch('main.asyncio.run_coroutine_threadsafe') as mock_run_coroutine:
            listener.on_message(mock_frame)
            mock_run_coroutine.assert_called_once()
    
    def test_activemq_error_handling(self):
        """Test ActiveMQ error handling"""
        from main import ActiveMQListener
        
        listener = ActiveMQListener()
        
        mock_frame = MagicMock()
        mock_frame.body = "Error message"
        
        listener.on_error(mock_frame)
    
    def test_activemq_disconnection_handling(self):
        """Test ActiveMQ disconnection handling"""
        from main import ActiveMQListener
        
        listener = ActiveMQListener()
        assert listener.connected is False
        
        listener.on_connected(MagicMock())
        assert listener.connected is True
        
        listener.on_disconnected()
        assert listener.connected is False
    
    def test_malformed_message_handling(self):
        """Test handling of malformed messages"""
        from main import ActiveMQListener
        
        listener = ActiveMQListener()
        
        mock_frame = MagicMock()
        mock_frame.body = b"not valid msgpack data"
        
        with patch('main.logger') as mock_logger:
            listener.on_message(mock_frame)
            mock_logger.error.assert_called()
    
    @pytest.mark.asyncio
    async def test_message_to_websocket_flow(self):
        """Test complete flow from ActiveMQ message to WebSocket clients"""
        from main import process_shot_data, websocket_clients
        
        mock_ws = MagicMock()
        mock_ws.send_json = MagicMock(return_value=None)
        websocket_clients.append(mock_ws)
        
        shot_data = {
            "speed": 175.0,
            "carry": 310.0,
            "launch_angle": 16.0,
            "side_angle": -2.0,
            "back_spin": 2600,
            "side_spin": -400,
            "result_type": 7,
            "message": "Draw shot",
            "image_paths": ["draw_001.jpg", "draw_002.jpg"]
        }
        
        await process_shot_data(shot_data)
        
        mock_ws.send_json.assert_called_once()
        sent_data = mock_ws.send_json.call_args[0][0]
        
        assert sent_data["speed"] == 175.0
        assert sent_data["carry"] == 310.0
        assert sent_data["message"] == "Draw shot"
        assert sent_data["images"] == ["draw_001.jpg", "draw_002.jpg"]
        assert "timestamp" in sent_data
    
    def test_activemq_config_loading(self, mock_home_dir):
        """Test loading ActiveMQ configuration from config file"""
        with patch('main.CONFIG_FILE', mock_home_dir / ".pitrac" / "config" / "pitrac.yaml"):
            with patch('main.stomp.Connection') as mock_conn:
                from main import setup_activemq
                
                conn = setup_activemq()
                
                mock_conn.assert_called_with([('localhost', 61613)])
    
    def test_activemq_reconnection_logic(self, mock_activemq):
        """Test ActiveMQ reconnection behavior"""
        from main import ActiveMQListener
        
        listener = ActiveMQListener()
        
        listener.on_connected(MagicMock())
        assert listener.connected is True
        
        listener.on_disconnected()
        assert listener.connected is False
        
        listener.on_connected(MagicMock())
        assert listener.connected is True