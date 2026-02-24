"""START (Simple Triage and Rapid Treatment) triage algorithm.

Implements both adult START and pediatric JumpSTART triage systems
for mass casualty incident (MCI) classification.
"""
from typing import Any, Dict, List, Optional


class TriageEngine:
    """Deterministic triage classification using START and JumpSTART algorithms."""

    @staticmethod
    def classify_start(
        can_walk: bool = None,
        breathing: bool = None,
        respiratory_rate: int = None,
        perfusion_check: bool = None,
        capillary_refill: float = None,
        radial_pulse: bool = None,
        mental_status: str = None,
        follows_commands: bool = None,
    ) -> dict:
        """Classify patient using adult START triage algorithm.

        Args:
            can_walk: Can the patient walk?
            breathing: Is the patient breathing?
            respiratory_rate: Respiratory rate per minute.
            perfusion_check: Adequate perfusion?
            capillary_refill: Capillary refill time in seconds.
            radial_pulse: Radial pulse present?
            mental_status: Mental status description.
            follows_commands: Can follow simple commands?

        Returns:
            Dict with category, label, priority, and action.
        """
        # Step 1: GREEN - Walking wounded
        if can_walk:
            return {
                "category": "GREEN",
                "label": "Minor / Ambulatory",
                "priority": 3,
                "action": "Delayed treatment area",
                "algorithm": "START",
                "step": "Walking wounded",
            }

        # Step 2: BLACK - Not breathing even after airway opened
        if breathing is False:
            return {
                "category": "BLACK",
                "label": "Deceased / Expectant",
                "priority": 4,
                "action": "Morgue area",
                "algorithm": "START",
                "step": "Not breathing after airway maneuver",
            }

        # Step 3: RED - Respiratory rate > 30
        if respiratory_rate is not None and respiratory_rate > 30:
            return {
                "category": "RED",
                "label": "Immediate",
                "priority": 1,
                "action": "Immediate treatment area",
                "algorithm": "START",
                "step": "Respiratory rate > 30/min",
            }

        # Step 4: RED - No radial pulse / cap refill > 2s
        if radial_pulse is False or (capillary_refill is not None and capillary_refill > 2.0):
            return {
                "category": "RED",
                "label": "Immediate",
                "priority": 1,
                "action": "Immediate treatment area - control bleeding",
                "algorithm": "START",
                "step": "Inadequate perfusion",
            }

        # Step 5: RED - Doesn't follow commands
        if follows_commands is False:
            return {
                "category": "RED",
                "label": "Immediate",
                "priority": 1,
                "action": "Immediate treatment area",
                "algorithm": "START",
                "step": "Cannot follow commands",
            }

        # YELLOW: Everything else (breathing, adequate perfusion, follows commands but can't walk)
        return {
            "category": "YELLOW",
            "label": "Delayed",
            "priority": 2,
            "action": "Delayed treatment area",
            "algorithm": "START",
            "step": "Breathing, adequate perfusion, follows commands, cannot walk",
        }

    @staticmethod
    def classify_jumpstart(
        age_years: float,
        can_walk: bool = None,
        breathing: bool = None,
        respiratory_rate: int = None,
        radial_pulse: bool = None,
        avpu: str = "A",
        capillary_refill: float = None,
        follows_commands: bool = None,
        **kwargs,
    ) -> dict:
        """Classify pediatric patient using JumpSTART triage algorithm.

        JumpSTART is designed for children < 8 years. Key differences from START:
        - RR thresholds: < 15 or > 45 = RED
        - Not breathing: give 5 rescue breaths, then reassess
        - Uses AVPU scale instead of 'follows commands'

        Args:
            age_years: Patient age in years.
            can_walk: Can the patient walk?
            breathing: Is the patient breathing?
            respiratory_rate: Respiratory rate per minute.
            radial_pulse: Radial pulse present?
            avpu: AVPU score (A=Alert, V=Voice, P=Pain, U=Unresponsive).
            capillary_refill: Capillary refill time in seconds.
            follows_commands: Can follow simple commands? (alternative to AVPU)

        Returns:
            Dict with category, label, priority, and action.
        """
        # Step 1: GREEN - Walking wounded
        if can_walk:
            return {
                "category": "GREEN",
                "label": "Minor",
                "priority": 3,
                "action": "Minor treatment area",
                "algorithm": "JumpSTART",
                "step": "Walking wounded",
            }

        # Step 2: Not breathing - give 5 rescue breaths for children
        if breathing is False:
            return {
                "category": "RED",
                "label": "Immediate",
                "priority": 1,
                "action": "Give 5 rescue breaths, reassess. If still not breathing -> BLACK",
                "algorithm": "JumpSTART",
                "step": "Not breathing - attempt rescue breaths",
            }

        # Step 3: Abnormal respiratory rate (pediatric thresholds)
        if respiratory_rate is not None and (respiratory_rate < 15 or respiratory_rate > 45):
            return {
                "category": "RED",
                "label": "Immediate",
                "priority": 1,
                "action": "Immediate treatment",
                "algorithm": "JumpSTART",
                "step": f"Abnormal RR ({respiratory_rate}/min) - normal range 15-45 for pediatric",
            }

        # Step 4: No radial pulse / inadequate perfusion
        if radial_pulse is False or (capillary_refill is not None and capillary_refill > 2.0):
            return {
                "category": "RED",
                "label": "Immediate",
                "priority": 1,
                "action": "Immediate - control bleeding",
                "algorithm": "JumpSTART",
                "step": "Inadequate perfusion",
            }

        # Step 5: Mental status - AVPU (P or U = RED)
        if avpu and avpu.upper() in ("P", "U"):
            return {
                "category": "RED",
                "label": "Immediate",
                "priority": 1,
                "action": "Immediate treatment",
                "algorithm": "JumpSTART",
                "step": f"Altered mental status (AVPU: {avpu.upper()})",
            }

        # Also check follows_commands as alternative
        if follows_commands is False:
            return {
                "category": "RED",
                "label": "Immediate",
                "priority": 1,
                "action": "Immediate treatment",
                "algorithm": "JumpSTART",
                "step": "Cannot follow commands",
            }

        # YELLOW: Everything else
        return {
            "category": "YELLOW",
            "label": "Delayed",
            "priority": 2,
            "action": "Delayed treatment area",
            "algorithm": "JumpSTART",
            "step": "Breathing, adequate perfusion, appropriate mental status, cannot walk",
        }

    @classmethod
    def classify(
        cls,
        age_years: float = None,
        **kwargs,
    ) -> dict:
        """Auto-select START or JumpSTART based on patient age.

        Args:
            age_years: Patient age in years. If < 8, uses JumpSTART.
            **kwargs: Triage assessment parameters.

        Returns:
            Dict with triage classification result.
        """
        if age_years is not None and age_years < 8:
            return cls.classify_jumpstart(age_years=age_years, **kwargs)
        return cls.classify_start(**kwargs)

    @staticmethod
    def get_triage_widget(result: dict, patient_id: str = None, vitals: dict = None, injuries: list = None, gcs: int = None) -> dict:
        """Build a TriageCard GenUI widget from classification result.

        Args:
            result: Classification result from classify/classify_start/classify_jumpstart.
            patient_id: Optional patient identifier.
            vitals: Optional vital signs dict.
            injuries: Optional list of injuries.
            gcs: Optional GCS score.

        Returns:
            GenUI TriageCard widget dict.
        """
        return {
            "type": "TriageCard",
            "data": {
                "patientId": patient_id or "Unknown",
                "category": result["category"],
                "vitals": vitals or {},
                "injuries": injuries or [],
                "action": result["action"],
                "gcs": gcs,
            },
        }
