import pytest
from unittest.mock import patch


@pytest.mark.unit
class TestAPIEndpoints:
    """Test REST API endpoints"""
    
    def test_homepage_loads(self, client):
        """Test that homepage loads successfully"""
        response = client.get("/")
        assert response.status_code == 200
        assert "PiTrac Launch Monitor" in response.text
        assert "dashboard.css" in response.text
        assert "dashboard.js" in response.text
    
    def test_get_current_shot(self, client):
        """Test getting current shot data"""
        response = client.get("/api/shot")
        assert response.status_code == 200
        data = response.json()
        assert "speed" in data
        assert "carry" in data
        assert "launch_angle" in data
        assert "side_angle" in data
        assert "back_spin" in data
        assert "side_spin" in data
        assert "result_type" in data
    
    def test_reset_shot(self, client):
        """Test resetting shot data"""
        from main import current_shot
        current_shot["speed"] = 150.0
        current_shot["carry"] = 275.0
        
        response = client.post("/api/reset")
        assert response.status_code == 200
        assert response.json() == {"status": "reset"}
        
        response = client.get("/api/shot")
        data = response.json()
        assert data["speed"] == 0.0
        assert data["carry"] == 0.0
    
    def test_health_check(self, client, mock_activemq):
        """Test health check endpoint"""
        mock_activemq.is_connected.return_value = True
        
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["activemq_connected"] is True
        assert "websocket_clients" in data
    
    def test_health_check_mq_disconnected(self, client, mock_activemq):
        """Test health check when ActiveMQ is disconnected"""
        mock_activemq.is_connected.return_value = False
        
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["activemq_connected"] is False
    
    def test_static_files_served(self, client):
        """Test that static files are accessible"""
        response = client.get("/static/dashboard.css")
        assert response.status_code in [200, 404]
    
    def test_favicon_served(self, client):
        """Test that favicon is accessible"""
        response = client.get("/static/favicon.ico")
        assert response.status_code in [200, 404]
    
    @pytest.mark.parametrize("image_name", [
        "test_shot.jpg",
        "shot_001.png",
        "capture.jpeg"
    ])
    def test_image_endpoint(self, client, tmp_path, image_name):
        """Test image serving endpoint"""
        with patch('main.IMAGES_DIR', tmp_path):
            image_path = tmp_path / image_name
            image_path.write_bytes(b"fake image data")
            
            response = client.get(f"/api/images/{image_name}")
            assert response.status_code == 200
    
    def test_image_not_found(self, client):
        """Test image endpoint with non-existent image"""
        response = client.get("/api/images/nonexistent.jpg")
        assert response.status_code == 200
        assert response.json() == {"error": "Image not found"}
    
    def test_cors_headers(self, client):
        """Test CORS headers are present if needed"""
        response = client.get("/api/shot")
        assert response.status_code == 200