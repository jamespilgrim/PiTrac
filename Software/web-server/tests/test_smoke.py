import pytest
import sys
from pathlib import Path


@pytest.mark.unit
class TestSmoke:
    """Basic smoke tests to verify the system is working"""
    
    def test_imports(self):
        """Test that all required modules can be imported"""
        import fastapi
        import uvicorn
        import msgpack
        import yaml
        import websocket
        import stomp
        import PIL
        import aiofiles
        import jinja2
    
    def test_main_module_imports(self):
        """Test that main module can be imported"""
        parent = Path(__file__).parent.parent
        if str(parent) not in sys.path:
            sys.path.insert(0, str(parent))
        
        import main
        
        assert hasattr(main, 'app')
        assert hasattr(main, 'process_shot_data')
        assert hasattr(main, 'current_shot')
        assert hasattr(main, 'websocket_clients')
    
    def test_fastapi_app_exists(self):
        """Test that FastAPI app is properly configured"""
        from main import app
        
        assert app is not None
        assert app.title == "PiTrac Dashboard"
        
        routes = [route.path for route in app.routes]
        assert "/" in routes
        assert "/api/shot" in routes
        assert "/api/reset" in routes
        assert "/health" in routes
        assert "/ws" in routes
    
    def test_templates_exist(self):
        """Test that template files exist"""
        template_dir = Path(__file__).parent.parent / "templates"
        assert template_dir.exists()
        
        dashboard = template_dir / "dashboard.html"
        assert dashboard.exists()
    
    def test_static_files_exist(self):
        """Test that static files exist"""
        static_dir = Path(__file__).parent.parent / "static"
        assert static_dir.exists()
        
        css_file = static_dir / "dashboard.css"
        js_file = static_dir / "dashboard.js"
        
        assert css_file.exists()
        assert js_file.exists()
    
    def test_initial_shot_state(self):
        """Test initial shot state is correct"""
        from main import current_shot
        
        assert current_shot is not None
        assert "speed" in current_shot
        assert "carry" in current_shot
        assert "launch_angle" in current_shot
        assert "side_angle" in current_shot
        assert "back_spin" in current_shot
        assert "side_spin" in current_shot
    
    def test_environment_detection(self):
        """Test that testing environment is detected"""
        import os
        assert os.environ.get("TESTING") == "true"