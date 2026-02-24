"""Tests for chat API schemas and prompt builder."""
import pytest


class TestChatEndpoint:
    """Chat endpoint schema tests."""

    def test_chat_request_schema(self):
        """Verify ChatRequest schema accepts required fields."""
        from app.models.schemas import ChatRequest

        req = ChatRequest(message="Test message")
        assert req.message == "Test message"
        assert req.genui_mode is True
        assert req.language == "tr"

    def test_chat_request_with_options(self):
        from app.models.schemas import ChatRequest

        req = ChatRequest(
            message="Anafilaksi protokolü",
            genui_mode=True,
            language="tr",
            patient_context={"weight_kg": 70},
        )
        assert req.patient_context["weight_kg"] == 70

    def test_chat_response_schema(self):
        from app.models.schemas import ChatResponse, GenUIWidget

        resp = ChatResponse(
            text="Test response",
            widgets=[GenUIWidget(type="WarningCard", data={"title": "Test", "message": "Test", "severity": "INFO"})],
        )
        assert len(resp.widgets) == 1
        assert resp.widgets[0].type == "WarningCard"

    def test_drug_calc_request_schema(self):
        from app.models.schemas import DrugCalcRequest

        req = DrugCalcRequest(
            drug_name="adrenalin",
            indication="anaphylaxis",
            weight_kg=70,
        )
        assert req.weight_kg == 70

    def test_triage_request_schema(self):
        from app.models.schemas import TriageRequest

        req = TriageRequest(
            can_walk=True,
        )
        assert req.can_walk is True

    def test_triage_request_full(self):
        from app.models.schemas import TriageRequest

        req = TriageRequest(
            patient_id="P001",
            can_walk=False,
            breathing=True,
            respiratory_rate=35,
            follows_commands=True,
            radial_pulse=True,
        )
        assert req.respiratory_rate == 35


class TestPromptBuilder:
    """Test prompt builder GenUI parsing."""

    def test_parse_valid_json(self):
        from app.core.prompt_builder import PromptBuilder

        pb = PromptBuilder()
        response = '{"text": "Test", "widgets": [{"type": "WarningCard", "data": {"title": "Alert", "message": "Test", "severity": "INFO"}}]}'
        result = pb.parse_genui_response(response)
        assert result["text"] == "Test"
        assert len(result["widgets"]) == 1
        assert result["widgets"][0]["type"] == "WarningCard"

    def test_parse_json_in_markdown(self):
        from app.core.prompt_builder import PromptBuilder

        pb = PromptBuilder()
        response = """Here is the response:
```json
{"text": "Protocol info", "widgets": []}
```"""
        result = pb.parse_genui_response(response)
        assert result["text"] == "Protocol info"

    def test_parse_invalid_json_returns_text(self):
        from app.core.prompt_builder import PromptBuilder

        pb = PromptBuilder()
        response = "This is just plain text without JSON"
        result = pb.parse_genui_response(response)
        assert result["text"] == response
        assert result["widgets"] == []

    def test_build_system_prompt_types(self):
        from app.core.prompt_builder import PromptBuilder

        pb = PromptBuilder()
        assert "ParaMed AI" in pb.build_system_prompt(genui_mode=True, prompt_type="chat")
        assert "translator" in pb.build_system_prompt(prompt_type="translation")
        assert "triage" in pb.build_system_prompt(prompt_type="triage")
        assert "image" in pb.build_system_prompt(prompt_type="image")
