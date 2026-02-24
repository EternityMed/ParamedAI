"""Tests for deterministic drug dose calculator."""
import pytest
from app.services.drug_calculator import DrugCalculator


class TestDrugCalculator:
    """Drug calculator must be 100% deterministic — never rely on LLM."""

    def test_adrenaline_adult_anaphylaxis(self):
        result = DrugCalculator.calculate(
            drug_name="adrenalin",
            weight_kg=70,
            indication="anaphylaxis",
        )
        assert "error" not in result
        assert result["drug_name"] == "Epinephrine (Adrenaline)"
        assert "0.5" in result["calculated_dose"]
        assert "IM" in result["route"]

    def test_adrenaline_pediatric_anaphylaxis(self):
        result = DrugCalculator.calculate(
            drug_name="adrenalin",
            weight_kg=25,
            indication="anaphylaxis",
            age_years=8,
        )
        assert "error" not in result
        assert "IM" in result["route"]
        # 0.01 mg/kg * 25 = 0.25 mg (under 0.5 max)
        assert "0.25" in result["calculated_dose"]

    def test_adrenaline_pediatric_max_dose(self):
        """Pediatric anaphylaxis max dose should cap at 0.5mg."""
        result = DrugCalculator.calculate(
            drug_name="adrenalin",
            weight_kg=60,
            indication="anaphylaxis",
            age_years=15,
            is_pediatric=True,
        )
        assert "error" not in result
        # 0.01 * 60 = 0.6 but max is 0.5
        assert "0.5" in result["calculated_dose"]

    def test_adrenaline_cardiac_arrest(self):
        result = DrugCalculator.calculate(
            drug_name="adrenalin",
            weight_kg=80,
            indication="cardiac_arrest",
        )
        assert "error" not in result
        assert "1" in result["calculated_dose"]
        assert "IV" in result["route"]

    def test_amiodarone_vf(self):
        result = DrugCalculator.calculate(
            drug_name="amiodaron",
            weight_kg=70,
            indication="vf_vt",
        )
        assert "error" not in result
        assert "300" in result["calculated_dose"]

    def test_midazolam_pediatric_seizure(self):
        result = DrugCalculator.calculate(
            drug_name="midazolam",
            weight_kg=20,
            indication="seizure",
            age_years=6,
        )
        assert "error" not in result
        # Should have a calculated dose
        assert result["calculated_dose"] is not None

    def test_unknown_drug(self):
        result = DrugCalculator.calculate(
            drug_name="nonexistent_drug",
            weight_kg=70,
            indication="test",
        )
        assert "error" in result

    def test_auto_pediatric_detection(self):
        """Age < 18 should auto-detect as pediatric."""
        result = DrugCalculator.calculate(
            drug_name="adrenalin",
            weight_kg=30,
            indication="anaphylaxis",
            age_years=10,
        )
        assert "error" not in result
        assert result["pediatric_note"] is not None
        assert "Pediatrik" in result["pediatric_note"]

    def test_deterministic_same_input_same_output(self):
        """Same inputs must always produce identical outputs."""
        results = [
            DrugCalculator.calculate(
                drug_name="adrenalin",
                weight_kg=70,
                indication="anaphylaxis",
            )
            for _ in range(10)
        ]
        assert all(r == results[0] for r in results)

    def test_widget_returned(self):
        """Every successful calculation should return a DrugDoseCard widget."""
        result = DrugCalculator.calculate(
            drug_name="adrenalin",
            weight_kg=70,
            indication="anaphylaxis",
        )
        assert "widget" in result
        assert result["widget"]["type"] == "DrugDoseCard"
        assert "drugName" in result["widget"]["data"]

    def test_unknown_indication(self):
        """Unknown indication should return error with available indications."""
        result = DrugCalculator.calculate(
            drug_name="adrenalin",
            weight_kg=70,
            indication="headache",
        )
        assert "error" in result
        assert "available_indications" in result
