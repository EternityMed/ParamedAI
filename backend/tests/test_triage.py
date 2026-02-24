"""Tests for START triage algorithm."""
import pytest
from app.services.triage_engine import TriageEngine


class TestSTARTTriage:
    """START triage must follow exact algorithm — deterministic."""

    def test_walking_wounded_green(self):
        result = TriageEngine.classify_start(can_walk=True)
        assert result["category"] == "GREEN"

    def test_not_breathing_black(self):
        result = TriageEngine.classify_start(
            can_walk=False, breathing=False
        )
        assert result["category"] == "BLACK"

    def test_high_respiratory_rate_red(self):
        result = TriageEngine.classify_start(
            can_walk=False, breathing=True, respiratory_rate=35
        )
        assert result["category"] == "RED"

    def test_no_radial_pulse_red(self):
        result = TriageEngine.classify_start(
            can_walk=False, breathing=True, respiratory_rate=20,
            radial_pulse=False
        )
        assert result["category"] == "RED"

    def test_slow_capillary_refill_red(self):
        result = TriageEngine.classify_start(
            can_walk=False, breathing=True, respiratory_rate=20,
            capillary_refill=3.0
        )
        assert result["category"] == "RED"

    def test_not_following_commands_red(self):
        result = TriageEngine.classify_start(
            can_walk=False, breathing=True, respiratory_rate=20,
            radial_pulse=True, follows_commands=False
        )
        assert result["category"] == "RED"

    def test_delayed_yellow(self):
        result = TriageEngine.classify_start(
            can_walk=False, breathing=True, respiratory_rate=20,
            radial_pulse=True, follows_commands=True
        )
        assert result["category"] == "YELLOW"

    def test_priority_ordering(self):
        """RED=1, YELLOW=2, GREEN=3, BLACK=4."""
        red = TriageEngine.classify_start(can_walk=False, breathing=True, respiratory_rate=35)
        yellow = TriageEngine.classify_start(can_walk=False, breathing=True, respiratory_rate=20, radial_pulse=True, follows_commands=True)
        green = TriageEngine.classify_start(can_walk=True)
        black = TriageEngine.classify_start(can_walk=False, breathing=False)

        assert red["priority"] < yellow["priority"] < green["priority"]
        assert black["priority"] == 4


class TestJumpSTART:
    """JumpSTART for pediatric patients."""

    def test_pediatric_walking_green(self):
        result = TriageEngine.classify_jumpstart(age_years=5, can_walk=True)
        assert result["category"] == "GREEN"

    def test_pediatric_not_breathing_red(self):
        result = TriageEngine.classify_jumpstart(
            age_years=3, can_walk=False, breathing=False
        )
        assert result["category"] == "RED"
        assert "rescue breaths" in result["action"].lower()

    def test_pediatric_abnormal_rr_red(self):
        result = TriageEngine.classify_jumpstart(
            age_years=4, can_walk=False, breathing=True, respiratory_rate=50
        )
        assert result["category"] == "RED"

    def test_pediatric_unresponsive_red(self):
        result = TriageEngine.classify_jumpstart(
            age_years=6, can_walk=False, breathing=True,
            respiratory_rate=25, radial_pulse=True, avpu="U"
        )
        assert result["category"] == "RED"
