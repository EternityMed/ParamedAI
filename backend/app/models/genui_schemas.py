"""GenUI A2UI message format schemas for Flutter genui package compatibility.

These schemas define the exact JSON structure that the Flutter genui package
expects for rendering custom widgets. Each widget type maps to a Flutter
widget registered in the GenUI widget catalog.
"""
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


# ─── Individual Widget Data Schemas ─────────────────────────────────────────

class DrugDoseCardData(BaseModel):
    """Data schema for DrugDoseCard widget."""
    drugName: str = Field(..., description="Name of the drug")
    dose: str = Field(..., description="Standard dose description")
    calculatedDose: str = Field("", description="Weight-based calculated dose")
    route: str = Field(..., description="Route of administration (IV, IM, PO, etc.)")
    concentration: Optional[str] = Field(None, description="Drug concentration")
    frequency: Optional[str] = Field(None, description="Dosing frequency")
    warning: Optional[str] = Field(None, description="Important warnings")
    maxDose: Optional[str] = Field(None, description="Maximum dose")


class ProtocolCardData(BaseModel):
    """Data schema for ProtocolCard widget."""
    protocolName: str = Field(..., description="Protocol name")
    steps: List[str] = Field(default_factory=list, description="Protocol steps")
    currentStep: int = Field(0, description="Current step index (0-based)")
    urgency: str = Field("YELLOW", description="Urgency level: RED/YELLOW/GREEN")
    notes: Optional[str] = Field(None, description="Additional notes")


class TriageCardData(BaseModel):
    """Data schema for TriageCard widget."""
    patientId: Optional[str] = Field(None, description="Patient identifier")
    category: str = Field(..., description="Triage category: RED/YELLOW/GREEN/BLACK")
    vitals: Optional[Dict[str, Any]] = Field(None, description="Vital signs")
    injuries: Optional[List[str]] = Field(None, description="List of injuries")
    action: str = Field(..., description="Recommended action")
    gcs: Optional[int] = Field(None, description="Glasgow Coma Scale score")


class ECGAnalysisCardData(BaseModel):
    """Data schema for ECGAnalysisCard widget."""
    rhythm: str = Field(..., description="Detected rhythm")
    rate: Optional[int] = Field(None, description="Heart rate")
    interpretation: str = Field(..., description="Clinical interpretation")
    stChanges: Optional[str] = Field(None, description="ST segment changes")
    urgentAction: Optional[str] = Field(None, description="Urgent action required")
    differentialDiagnosis: Optional[List[str]] = Field(None, description="Differential diagnoses")


class VitalSignsCardData(BaseModel):
    """Data schema for VitalSignsCard widget."""
    bp: Optional[str] = Field(None, description="Blood pressure (e.g., '120/80')")
    hr: Optional[int] = Field(None, description="Heart rate")
    rr: Optional[int] = Field(None, description="Respiratory rate")
    spo2: Optional[int] = Field(None, description="Oxygen saturation %")
    temp: Optional[float] = Field(None, description="Temperature in Celsius")
    gcs: Optional[int] = Field(None, description="Glasgow Coma Scale")
    pain: Optional[int] = Field(None, description="Pain score 0-10")
    trending: Optional[str] = Field(None, description="Trend direction: UP/DOWN/STABLE")


class PatientFormCardData(BaseModel):
    """Data schema for PatientFormCard widget."""
    age: Optional[int] = Field(None, description="Patient age")
    gender: Optional[str] = Field(None, description="Patient gender")
    chiefComplaint: Optional[str] = Field(None, description="Chief complaint")
    history: Optional[str] = Field(None, description="Medical history")
    vitals: Optional[Dict[str, Any]] = Field(None, description="Vital signs")
    injuries: Optional[List[str]] = Field(None, description="Injuries")
    interventions: Optional[List[str]] = Field(None, description="Interventions performed")
    allergies: Optional[List[str]] = Field(None, description="Known allergies")



class WarningCardData(BaseModel):
    """Data schema for WarningCard widget."""
    title: str = Field(..., description="Warning title")
    message: str = Field(..., description="Warning message")
    severity: str = Field("WARNING", description="Severity: CRITICAL/WARNING/INFO")
    action: Optional[str] = Field(None, description="Recommended action")


# ─── GenUI Message Format ───────────────────────────────────────────────────

class GenUIWidget(BaseModel):
    """A single widget in a GenUI response."""
    type: str = Field(..., description="Widget type identifier")
    data: Dict[str, Any] = Field(default_factory=dict, description="Widget data")


class GenUIMessage(BaseModel):
    """Complete GenUI message format for A2UI (AI-to-UI) communication.

    This is the top-level format that the Flutter genui package expects.
    """
    text: str = Field("", description="Optional plain text message")
    widgets: List[GenUIWidget] = Field(default_factory=list, description="List of UI widgets")


class GenUIStreamChunk(BaseModel):
    """A single chunk in a streaming GenUI response (SSE format)."""
    type: str = Field("token", description="Chunk type: 'token', 'widget', 'done', 'error'")
    content: Optional[str] = Field(None, description="Token text content")
    widget: Optional[GenUIWidget] = Field(None, description="Complete widget (for 'widget' type)")
    error: Optional[str] = Field(None, description="Error message (for 'error' type)")


# ─── Widget Type Registry ───────────────────────────────────────────────────

WIDGET_TYPE_MAP = {
    "DrugDoseCard": DrugDoseCardData,
    "ProtocolCard": ProtocolCardData,
    "TriageCard": TriageCardData,
    "ECGAnalysisCard": ECGAnalysisCardData,
    "VitalSignsCard": VitalSignsCardData,
    "PatientFormCard": PatientFormCardData,

    "WarningCard": WarningCardData,
}


def validate_widget(widget_type: str, data: Dict[str, Any]) -> bool:
    """Validate widget data against its schema.

    Args:
        widget_type: The widget type name.
        data: The widget data dict.

    Returns:
        True if valid, False if widget type unknown or data invalid.
    """
    schema_class = WIDGET_TYPE_MAP.get(widget_type)
    if schema_class is None:
        return False
    try:
        schema_class(**data)
        return True
    except Exception:
        return False
