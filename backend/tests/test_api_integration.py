"""Integration tests for FastAPI API endpoints.

Tests the deterministic endpoints (drug calculator, triage, drug list)
using FastAPI TestClient without needing ML models loaded.
"""
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi.testclient import TestClient


# We need to mock the lifespan to avoid loading ML models
@pytest.fixture(scope="module")
def client():
    """Create a TestClient with mocked ML dependencies."""
    # Mock the heavy dependencies before importing the app
    with patch("app.main._load_medgemma_engine") as mock_engine, \
         patch("app.core.rag_engine.SentenceTransformer"), \
         patch("app.core.rag_engine.chromadb"):

        # Setup mock engine
        mock_medgemma = MagicMock()
        mock_medgemma.generate = AsyncMock(return_value={
            "text": "Mock response",
            "widgets": [],
        })
        mock_engine.return_value = (mock_medgemma, "mock")

        from app.main import app

        # Set required app state
        app.state.medgemma = mock_medgemma
        app.state.inference_mode = "mock"
        app.state.start_time = 0

        # Mock RAG engine
        mock_rag = MagicMock()
        mock_rag.initialize = AsyncMock()
        mock_rag.retrieve = AsyncMock(return_value="")
        mock_rag.get_collection_stats = MagicMock(return_value={"count": 10})
        app.state.rag = mock_rag

        with TestClient(app, raise_server_exceptions=False) as c:
            yield c


class TestDrugCalculateEndpoint:
    """Test POST /api/v1/drug/calculate."""

    def test_adult_adrenaline_anaphylaxis(self, client):
        response = client.post("/api/v1/drug/calculate", json={
            "drug_name": "adrenalin",
            "weight_kg": 70,
            "indication": "anaphylaxis",
        })
        assert response.status_code == 200
        data = response.json()
        assert data["drug_name"] == "Epinephrine (Adrenaline)"
        assert data["indication"] == "anaphylaxis"
        assert "0.5" in data["calculated_dose"]
        assert data["widget"]["type"] == "DrugDoseCard"

    def test_pediatric_adrenaline(self, client):
        response = client.post("/api/v1/drug/calculate", json={
            "drug_name": "adrenalin",
            "weight_kg": 25,
            "indication": "anaphylaxis",
            "age_years": 8,
        })
        assert response.status_code == 200
        data = response.json()
        assert "0.25" in data["calculated_dose"]
        assert data["pediatric_note"] is not None

    def test_amiodarone_vf(self, client):
        response = client.post("/api/v1/drug/calculate", json={
            "drug_name": "amiodaron",
            "weight_kg": 75,
            "indication": "vf_vt",
        })
        assert response.status_code == 200
        data = response.json()
        assert "300" in data["calculated_dose"]

    def test_midazolam_pediatric_seizure(self, client):
        response = client.post("/api/v1/drug/calculate", json={
            "drug_name": "midazolam",
            "weight_kg": 20,
            "indication": "seizure",
            "age_years": 6,
        })
        assert response.status_code == 200
        data = response.json()
        assert data["widget"]["type"] == "DrugDoseCard"

    def test_unknown_drug_returns_error(self, client):
        response = client.post("/api/v1/drug/calculate", json={
            "drug_name": "fakedrug",
            "weight_kg": 70,
        })
        assert response.status_code == 200
        data = response.json()
        assert data["route"] == "N/A"
        assert data["widget"]["type"] == "WarningCard"

    def test_invalid_request_missing_weight(self, client):
        response = client.post("/api/v1/drug/calculate", json={
            "drug_name": "adrenalin",
        })
        assert response.status_code == 422  # Validation error

    def test_invalid_weight_zero(self, client):
        response = client.post("/api/v1/drug/calculate", json={
            "drug_name": "adrenalin",
            "weight_kg": 0,
        })
        assert response.status_code == 422

    def test_negative_weight(self, client):
        response = client.post("/api/v1/drug/calculate", json={
            "drug_name": "adrenalin",
            "weight_kg": -10,
        })
        assert response.status_code == 422

    def test_all_drugs_calculable(self, client):
        """Every drug in the database should return a valid calculation."""
        drugs_indications = {
            "adrenalin": "anaphylaxis",
            "amiodaron": "vf_vt",
            "midazolam": "seizure",
            "atropine": "bradycardia",
            "morphine": "pain",
            "salbutamol": "asthma",
            "sodium_bicarbonate": "acidosis",
            "calcium_gluconate": "hyperkalemia",
            "aspirin": "acs",
            "nitroglycerin": "chest_pain",
            "magnesium_sulfate": "eclampsia",
            "ketamine": "sedation",
            "ondansetron": "nausea",
            "dexamethasone": "inflammation",
            "furosemide": "pulmonary_edema",
        }
        for drug, indication in drugs_indications.items():
            response = client.post("/api/v1/drug/calculate", json={
                "drug_name": drug,
                "weight_kg": 70,
                "indication": indication,
            })
            assert response.status_code == 200, f"Failed for {drug}/{indication}"
            data = response.json()
            assert data["widget"]["type"] == "DrugDoseCard", f"Wrong widget for {drug}"

    def test_pregnancy_warning_included(self, client):
        response = client.post("/api/v1/drug/calculate", json={
            "drug_name": "adrenalin",
            "weight_kg": 65,
            "indication": "anaphylaxis",
            "is_pregnant": True,
        })
        assert response.status_code == 200
        data = response.json()
        assert "GEBELIK" in data["warning"] or "gebelik" in data["warning"].lower()

    def test_pediatric_max_dose_cap(self, client):
        """Heavy pediatric patient should be capped at max dose."""
        response = client.post("/api/v1/drug/calculate", json={
            "drug_name": "adrenalin",
            "weight_kg": 60,
            "indication": "anaphylaxis",
            "age_years": 15,
        })
        assert response.status_code == 200
        data = response.json()
        # 0.01 * 60 = 0.6 mg, should be capped at 0.5
        assert "0.5" in data["calculated_dose"]
        assert "max" in data["calculated_dose"].lower() or "0.5 mg" in data["calculated_dose"]


class TestDrugListEndpoint:
    """Test GET /api/v1/drug/list."""

    def test_list_drugs(self, client):
        response = client.get("/api/v1/drug/list")
        assert response.status_code == 200
        data = response.json()
        assert "drugs" in data
        assert "count" in data
        assert data["count"] == 15  # 15 drugs in the database
        assert "adrenalin" in data["drugs"]
        assert "anaphylaxis" in data["drugs"]["adrenalin"]


class TestTriageEndpoint:
    """Test POST /api/v1/triage/classify."""

    def test_walking_wounded_green(self, client):
        response = client.post("/api/v1/triage/classify", json={
            "can_walk": True,
        })
        assert response.status_code == 200
        data = response.json()
        assert data["category"] == "GREEN"
        assert data["priority"] == 3
        assert data["widget"]["type"] == "TriageCard"

    def test_not_breathing_black(self, client):
        response = client.post("/api/v1/triage/classify", json={
            "can_walk": False,
            "breathing": False,
        })
        assert response.status_code == 200
        data = response.json()
        assert data["category"] == "BLACK"
        assert data["priority"] == 4

    def test_high_rr_red(self, client):
        response = client.post("/api/v1/triage/classify", json={
            "can_walk": False,
            "breathing": True,
            "respiratory_rate": 35,
        })
        assert response.status_code == 200
        data = response.json()
        assert data["category"] == "RED"
        assert data["priority"] == 1

    def test_no_pulse_red(self, client):
        response = client.post("/api/v1/triage/classify", json={
            "can_walk": False,
            "breathing": True,
            "respiratory_rate": 20,
            "radial_pulse": False,
        })
        assert response.status_code == 200
        data = response.json()
        assert data["category"] == "RED"

    def test_delayed_yellow(self, client):
        response = client.post("/api/v1/triage/classify", json={
            "can_walk": False,
            "breathing": True,
            "respiratory_rate": 20,
            "radial_pulse": True,
            "follows_commands": True,
        })
        assert response.status_code == 200
        data = response.json()
        assert data["category"] == "YELLOW"
        assert data["priority"] == 2

    def test_jumpstart_pediatric(self, client):
        response = client.post("/api/v1/triage/classify", json={
            "age_years": 5,
            "can_walk": False,
            "breathing": True,
            "respiratory_rate": 50,  # > 45 for pediatric = RED
        })
        assert response.status_code == 200
        data = response.json()
        assert data["category"] == "RED"
        assert data["algorithm"] == "JumpSTART"

    def test_jumpstart_walking_green(self, client):
        response = client.post("/api/v1/triage/classify", json={
            "age_years": 4,
            "can_walk": True,
        })
        assert response.status_code == 200
        data = response.json()
        assert data["category"] == "GREEN"
        assert data["algorithm"] == "JumpSTART"

    def test_triage_with_patient_id(self, client):
        response = client.post("/api/v1/triage/classify", json={
            "patient_id": "PT-001",
            "can_walk": True,
        })
        assert response.status_code == 200
        data = response.json()
        assert data["patient_id"] == "PT-001"

    def test_triage_with_vitals_and_injuries(self, client):
        response = client.post("/api/v1/triage/classify", json={
            "patient_id": "PT-002",
            "can_walk": False,
            "breathing": True,
            "respiratory_rate": 22,
            "radial_pulse": True,
            "follows_commands": True,
            "vitals": {"hr": 88, "spo2": 97, "bp": "120/80"},
            "injuries": ["Left femur fracture", "Abrasions"],
            "gcs": 15,
        })
        assert response.status_code == 200
        data = response.json()
        assert data["category"] == "YELLOW"
        widget_data = data["widget"]["data"]
        assert widget_data["patientId"] == "PT-002"

    def test_avpu_unresponsive_red(self, client):
        """AVPU 'U' should classify as RED in JumpSTART."""
        response = client.post("/api/v1/triage/classify", json={
            "age_years": 3,
            "can_walk": False,
            "breathing": True,
            "respiratory_rate": 25,
            "radial_pulse": True,
            "avpu": "U",
        })
        assert response.status_code == 200
        data = response.json()
        assert data["category"] == "RED"

    def test_capillary_refill_slow_red(self, client):
        response = client.post("/api/v1/triage/classify", json={
            "can_walk": False,
            "breathing": True,
            "respiratory_rate": 22,
            "capillary_refill": 3.5,
        })
        assert response.status_code == 200
        data = response.json()
        assert data["category"] == "RED"


class TestHealthEndpoint:
    """Test GET /api/v1/health."""

    def test_health_check(self, client):
        response = client.get("/api/v1/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert "model" in data
        assert "rag_documents" in data
        assert "uptime_seconds" in data


class TestModelInfoEndpoint:
    """Test GET /api/v1/model/info."""

    def test_model_info(self, client):
        response = client.get("/api/v1/model/info")
        assert response.status_code == 200
        data = response.json()
        assert "model_name" in data
        assert "genui_widgets" in data
        assert len(data["genui_widgets"]) == 8
        expected_widgets = [
            "DrugDoseCard", "ProtocolCard", "TriageCard",
            "ECGAnalysisCard", "VitalSignsCard", "PatientFormCard",
            "TranslationCard", "WarningCard",
        ]
        for w in expected_widgets:
            assert w in data["genui_widgets"]


class TestClinicalDecisionService:
    """Test the ClinicalDecisionService drug query detection."""

    def test_drug_query_detection(self):
        from app.services.clinical_decision import ClinicalDecisionService
        from unittest.mock import MagicMock

        service = ClinicalDecisionService(
            medgemma=MagicMock(),
            rag=MagicMock(),
        )

        # Should detect drug query
        result = service._check_drug_query(
            "adrenalin dozu nedir 70 kg hasta",
            None,
        )
        assert result is not None
        assert "widgets" in result
        assert result["widgets"][0]["type"] == "DrugDoseCard"

    def test_non_drug_query_returns_none(self):
        from app.services.clinical_decision import ClinicalDecisionService
        from unittest.mock import MagicMock

        service = ClinicalDecisionService(
            medgemma=MagicMock(),
            rag=MagicMock(),
        )

        # Should not detect as drug query
        result = service._check_drug_query(
            "travma hastasinda ABCDE degerlendirmesi nasil yapilir",
            None,
        )
        assert result is None

    def test_drug_query_with_weight_extraction(self):
        from app.services.clinical_decision import ClinicalDecisionService
        from unittest.mock import MagicMock

        service = ClinicalDecisionService(
            medgemma=MagicMock(),
            rag=MagicMock(),
        )

        result = service._check_drug_query(
            "25 kg cocuk icin adrenalin dozu hesapla anaphylaxis",
            None,
        )
        assert result is not None
        # Should extract 25 kg and calculate accordingly
        widget_data = result["widgets"][0]["data"]
        assert "25" in widget_data.get("calculatedDose", "")

    def test_drug_query_with_patient_context(self):
        from app.services.clinical_decision import ClinicalDecisionService
        from unittest.mock import MagicMock

        service = ClinicalDecisionService(
            medgemma=MagicMock(),
            rag=MagicMock(),
        )

        result = service._check_drug_query(
            "adrenalin dozu hesapla",
            {"weight_kg": 30, "age_years": 10, "indication": "anaphylaxis"},
        )
        assert result is not None
        assert "0.30" in result["widgets"][0]["data"]["calculatedDose"] or \
               "0.3" in result["widgets"][0]["data"]["calculatedDose"]

    def test_format_patient_context(self):
        from app.services.clinical_decision import ClinicalDecisionService
        from unittest.mock import MagicMock

        service = ClinicalDecisionService(
            medgemma=MagicMock(),
            rag=MagicMock(),
        )

        context = service._format_patient_context({
            "age_years": 45,
            "weight_kg": 80,
            "gender": "Male",
            "chief_complaint": "Chest pain",
            "vitals": {"hr": 100, "bp": "90/60"},
            "allergies": ["Penicillin", "Sulfa"],
            "is_pregnant": False,
        })
        assert "Age: 45" in context
        assert "Weight (kg): 80" in context
        assert "Chest pain" in context
        assert "Penicillin, Sulfa" in context
        assert "Pregnant: No" in context
