import asyncio
import json
import time
import pytest
from unittest.mock import patch, MagicMock
import msgpack


@pytest.mark.integration
class TestShotSimulation:
    """Test realistic shot simulation scenarios"""
    
    @pytest.mark.asyncio
    async def test_rapid_shot_sequence(self, app, shot_simulator):
        """Test handling rapid sequence of shots"""
        from main import process_shot_data, current_shot
        
        shots = shot_simulator.generate_sequence(10)
        
        for shot in shots:
            await process_shot_data(shot)
            assert current_shot["speed"] == shot["speed"]
            assert current_shot["carry"] == shot["carry"]
            await asyncio.sleep(0.01)
    
    @pytest.mark.asyncio
    async def test_concurrent_shot_updates(self, app, shot_simulator):
        """Test handling concurrent shot updates"""
        from main import process_shot_data
        
        shots = shot_simulator.generate_sequence(5)
        
        tasks = [process_shot_data(shot) for shot in shots]
        await asyncio.gather(*tasks)
        
        from main import current_shot
        assert current_shot["speed"] > 0
    
    def test_shot_data_validation(self, shot_simulator):
        """Test shot data validation and bounds"""
        shot = shot_simulator.generate_shot()
        
        assert 100 <= shot["speed"] <= 180
        assert 150 <= shot["carry"] <= 350
        assert 8 <= shot["launch_angle"] <= 20
        assert -5 <= shot["side_angle"] <= 5
        assert 1500 <= shot["back_spin"] <= 4000
        assert -1000 <= shot["side_spin"] <= 1000
    
    @pytest.mark.asyncio
    async def test_shot_with_images(self, app, tmp_path):
        """Test shot processing with image handling"""
        from main import process_shot_data, current_shot
        
        image_files = []
        for i in range(3):
            img_path = tmp_path / f"shot_{i}.jpg"
            img_path.write_bytes(b"fake image data")
            image_files.append(f"shot_{i}.jpg")
        
        shot_data = {
            "speed": 155.0,
            "carry": 280.0,
            "launch_angle": 14.0,
            "side_angle": 0.0,
            "back_spin": 2800,
            "side_spin": 0,
            "result_type": 7,
            "message": "Perfect shot",
            "image_paths": image_files
        }
        
        with patch('main.IMAGES_DIR', tmp_path):
            await process_shot_data(shot_data)
            
            assert current_shot["images"] == image_files
            assert len(current_shot["images"]) == 3
    
    @pytest.mark.slow
    @pytest.mark.asyncio
    async def test_sustained_shot_stream(self, app, shot_simulator):
        """Test sustained stream of shots over time"""
        from main import process_shot_data, websocket_clients
        
        mock_ws = MagicMock()
        async def mock_send_json(*args, **kwargs):
            return None
        mock_ws.send_json = MagicMock(side_effect=mock_send_json)
        websocket_clients.append(mock_ws)
        
        start_time = time.time()
        shot_count = 0
        
        while time.time() - start_time < 2:
            shot = shot_simulator.generate_shot()
            await process_shot_data(shot)
            shot_count += 1
            await asyncio.sleep(0.1)
        
        assert shot_count > 0
        assert mock_ws.send_json.call_count == shot_count
    
    def test_shot_result_types(self):
        """Test different shot result types"""
        from main import ResultType
        
        result_types = {
            ResultType.UNKNOWN: "Unknown",
            ResultType.INITIALIZING: "Initializing",
            ResultType.WAITING_FOR_BALL: "Waiting For Ball",
            ResultType.BALL_READY: "Ball Ready",
            ResultType.HIT: "Hit",
            ResultType.ERROR: "Error"
        }
        
        for enum_val, expected_text in result_types.items():
            formatted = enum_val.name.replace("_", " ").title()
            assert formatted == expected_text or formatted.replace(" ", "") == expected_text.replace(" ", "")
    
    @pytest.mark.asyncio
    async def test_shot_timestamp_generation(self, app, shot_simulator):
        """Test that timestamps are properly generated"""
        from main import process_shot_data, current_shot
        from datetime import datetime
        
        shot = shot_simulator.generate_shot()
        
        before = datetime.now()
        await process_shot_data(shot)
        after = datetime.now()
        
        assert current_shot["timestamp"] is not None
        
        timestamp = datetime.fromisoformat(current_shot["timestamp"])
        assert before <= timestamp <= after
    
    @pytest.mark.asyncio
    async def test_shot_data_persistence(self, app, shot_simulator):
        """Test that shot data persists between requests"""
        from main import process_shot_data, current_shot
        
        shot = shot_simulator.generate_shot()
        await process_shot_data(shot)
        
        stored_speed = current_shot["speed"]
        stored_carry = current_shot["carry"]
        
        await asyncio.sleep(0.1)
        
        assert current_shot["speed"] == stored_speed
        assert current_shot["carry"] == stored_carry
    
    @pytest.mark.parametrize("club_type,speed_range,carry_range", [
        ("driver", (140, 180), (250, 350)),
        ("iron", (100, 140), (150, 200)),
        ("wedge", (70, 100), (50, 120)),
    ])
    def test_club_specific_shots(self, shot_simulator, club_type, speed_range, carry_range):
        """Test generating club-specific shot data"""
        shot = shot_simulator.generate_shot(
            speed_range=speed_range,
            carry_range=carry_range
        )
        
        assert speed_range[0] <= shot["speed"] <= speed_range[1]
        assert carry_range[0] <= shot["carry"] <= carry_range[1]