"""Triage endpoints: /triage/classify (deterministic) and /triage/ai-classify (AI-assisted)."""
import json
import re

from fastapi import APIRouter, Request
from pydantic import BaseModel, Field
from typing import Optional

from app.models.schemas import GenUIWidget, TriageRequest, TriageResponse
from app.services.triage_engine import TriageEngine

router = APIRouter()
triage_engine = TriageEngine()


class AiTriageRequest(BaseModel):
    """Request body for AI-assisted triage."""
    can_walk: bool = False
    has_breathing: bool = False
    has_pulse: bool = False
    follows_commands: bool = False
    notes: Optional[str] = None


class AiTriageResponse(BaseModel):
    """Response body for AI-assisted triage."""
    category: str
    reasoning: str


@router.post("/triage/ai-classify", response_model=AiTriageResponse)
async def ai_classify_triage(request: Request, body: AiTriageRequest):
    """AI-assisted START triage using MedGemma.

    Sends patient assessment to MedGemma without GenUI system prompt.
    Falls back to deterministic START if AI fails to return valid JSON.
    """
    medgemma = request.app.state.medgemma

    # Deterministic START as fallback
    start_category = _deterministic_start(
        can_walk=body.can_walk,
        has_breathing=body.has_breathing,
        has_pulse=body.has_pulse,
        follows_commands=body.follows_commands,
    )

    # Build the same prompt the Flutter local mode uses
    notes_line = f"\nAdditional notes: {body.notes}" if body.notes else ""
    prompt = (
        "You are an emergency medicine physician performing START field triage.\n"
        "Classify the patient into one category based on their assessment.\n\n"
        "Categories:\n"
        "- GREEN: Minor injuries, can walk (walking wounded)\n"
        "- YELLOW: Delayed, serious but stable\n"
        "- RED: Immediate, life-threatening, needs urgent care\n"
        "- BLACK: Deceased or expectant, no signs of life\n\n"
        'Return ONLY JSON: {"category":"COLOR","reasoning":"short reason"}\n\n'
        "Patient:\n"
        f"Can walk: {'Yes' if body.can_walk else 'No'}\n"
        f"Breathing: {'Yes' if body.has_breathing else 'No'}\n"
        f"Radial pulse: {'Yes' if body.has_pulse else 'No'}\n"
        f"Follows commands: {'Yes' if body.follows_commands else 'No'}"
        f"{notes_line}"
    )

    try:
        result = await medgemma.generate(
            user_message=prompt,
            genui_mode=False,
        )
        ai_text = result.get("text", "")

        # Parse JSON from AI response
        json_match = re.search(r'\{[^}]*"category"[^}]*\}', ai_text)
        if json_match:
            parsed = json.loads(json_match.group(0))
            category = (parsed.get("category") or start_category).upper()
            reasoning = parsed.get("reasoning", "")
            if category in ("RED", "YELLOW", "GREEN", "BLACK"):
                return AiTriageResponse(category=category, reasoning=reasoning)

        # AI didn't return valid category, fallback
        return AiTriageResponse(category=start_category, reasoning=ai_text or "START algorithm fallback")

    except Exception:
        return AiTriageResponse(
            category=start_category,
            reasoning="Classified by START algorithm (AI unavailable)",
        )


def _deterministic_start(
    can_walk: bool,
    has_breathing: bool,
    has_pulse: bool,
    follows_commands: bool,
) -> str:
    if can_walk:
        return "GREEN"
    if not has_breathing:
        return "BLACK"
    if not has_pulse or not follows_commands:
        return "RED"
    return "YELLOW"


@router.post("/triage/classify", response_model=TriageResponse)
async def classify_triage(body: TriageRequest):
    """Classify patient using START/JumpSTART triage algorithm.

    Uses deterministic START algorithm for adults and JumpSTART
    for pediatric patients (< 8 years). This endpoint NEVER uses
    LLM for classification.

    The algorithm follows these steps:
    1. Can walk? -> GREEN (Minor)
    2. Breathing? -> No: BLACK (Deceased)
    3. RR > 30? -> RED (Immediate)
    4. Perfusion? -> No pulse/cap refill > 2s: RED
    5. Mental status? -> Cannot follow commands: RED
    6. All else -> YELLOW (Delayed)

    Args:
        body: Triage assessment parameters.

    Returns:
        Triage classification with category, priority, and action.
    """
    # Build kwargs for the triage engine
    triage_kwargs = {
        "can_walk": body.can_walk,
        "breathing": body.breathing,
        "respiratory_rate": body.respiratory_rate,
        "perfusion_check": body.perfusion_check,
        "capillary_refill": body.capillary_refill,
        "radial_pulse": body.radial_pulse,
        "mental_status": body.mental_status,
        "follows_commands": body.follows_commands,
    }

    # Add JumpSTART-specific fields
    if body.avpu:
        triage_kwargs["avpu"] = body.avpu

    # Auto-select algorithm based on age
    result = triage_engine.classify(
        age_years=body.age_years,
        **triage_kwargs,
    )

    # Build triage widget
    widget_data = triage_engine.get_triage_widget(
        result=result,
        patient_id=body.patient_id,
        vitals=body.vitals,
        injuries=body.injuries,
        gcs=body.gcs,
    )

    return TriageResponse(
        patient_id=body.patient_id,
        category=result["category"],
        label=result["label"],
        priority=result["priority"],
        action=result["action"],
        algorithm=result.get("algorithm", "START"),
        widget=GenUIWidget(**widget_data),
    )
