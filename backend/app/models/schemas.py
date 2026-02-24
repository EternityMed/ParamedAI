"""Pydantic request/response models for all API endpoints."""
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


# ─── Chat ────────────────────────────────────────────────────────────────────

class ChatRequest(BaseModel):
    """Request body for /chat endpoint."""
    message: str = Field(..., description="User message text")
    conversation_id: Optional[str] = Field(None, description="Conversation ID for context")
    patient_context: Optional[Dict[str, Any]] = Field(None, description="Current patient data")
    genui_mode: bool = Field(True, description="Whether to return GenUI widget JSON")
    language: str = Field("tr", description="Response language code")


class GenUIWidget(BaseModel):
    """A single GenUI widget in the response."""
    type: str = Field(..., description="Widget type name")
    data: Dict[str, Any] = Field(default_factory=dict, description="Widget data payload")


class ChatResponse(BaseModel):
    """Response body for /chat endpoint."""
    text: str = Field("", description="Plain text response")
    widgets: List[GenUIWidget] = Field(default_factory=list, description="GenUI widget list")
    conversation_id: Optional[str] = Field(None, description="Conversation ID")
    rag_sources: List[str] = Field(default_factory=list, description="RAG source documents used")


# ─── Transcribe (STT) ───────────────────────────────────────────────────────

class TranscribeResponse(BaseModel):
    """Response body for /transcribe endpoint."""
    text: str = Field(..., description="Transcribed text")
    language: str = Field(..., description="Detected or specified language")
    confidence: float = Field(..., description="Confidence score 0-1")
    segments: List[Dict[str, Any]] = Field(default_factory=list, description="Timed segments")


# ─── Drug Calculator ────────────────────────────────────────────────────────

class DrugCalcRequest(BaseModel):
    """Request body for /drug/calculate endpoint."""
    drug_name: str = Field(..., description="Drug name (e.g., 'adrenalin', 'amiodaron')")
    indication: Optional[str] = Field(None, description="Clinical indication (e.g., 'anaphylaxis', 'cardiac_arrest')")
    weight_kg: float = Field(..., gt=0, description="Patient weight in kg")
    age_years: Optional[float] = Field(None, ge=0, description="Patient age in years")
    is_pediatric: bool = Field(False, description="Whether patient is pediatric")
    is_pregnant: bool = Field(False, description="Whether patient is pregnant")


class DrugCalcResponse(BaseModel):
    """Response body for /drug/calculate endpoint."""
    drug_name: str
    indication: str
    dose: str = Field(..., description="Dose description")
    calculated_dose: str = Field(..., description="Calculated dose for this patient")
    route: str = Field(..., description="Route of administration")
    concentration: Optional[str] = Field(None, description="Drug concentration")
    frequency: Optional[str] = Field(None, description="Dosing frequency")
    max_dose: Optional[str] = Field(None, description="Maximum dose")
    warning: Optional[str] = Field(None, description="Clinical warnings")
    pediatric_note: Optional[str] = Field(None, description="Pediatric-specific note")
    widget: GenUIWidget = Field(..., description="DrugDoseCard widget")


# ─── Triage ─────────────────────────────────────────────────────────────────

class TriageRequest(BaseModel):
    """Request body for /triage/classify endpoint."""
    patient_id: Optional[str] = Field(None, description="Patient identifier")
    can_walk: Optional[bool] = Field(None, description="Can the patient walk?")
    breathing: Optional[bool] = Field(None, description="Is the patient breathing?")
    respiratory_rate: Optional[int] = Field(None, ge=0, description="Respiratory rate per minute")
    perfusion_check: Optional[bool] = Field(None, description="Adequate perfusion?")
    capillary_refill: Optional[float] = Field(None, ge=0, description="Capillary refill time in seconds")
    radial_pulse: Optional[bool] = Field(None, description="Radial pulse present?")
    mental_status: Optional[str] = Field(None, description="Mental status description")
    follows_commands: Optional[bool] = Field(None, description="Can follow simple commands?")
    age_years: Optional[float] = Field(None, ge=0, description="Patient age in years")
    avpu: Optional[str] = Field(None, description="AVPU score (A/V/P/U)")
    gcs: Optional[int] = Field(None, ge=3, le=15, description="Glasgow Coma Scale")
    vitals: Optional[Dict[str, Any]] = Field(None, description="Additional vital signs")
    injuries: Optional[List[str]] = Field(None, description="List of injuries")


class TriageResponse(BaseModel):
    """Response body for /triage/classify endpoint."""
    patient_id: Optional[str]
    category: str = Field(..., description="Triage category: RED/YELLOW/GREEN/BLACK")
    label: str = Field(..., description="Category label")
    priority: int = Field(..., description="Priority number (1=highest)")
    action: str = Field(..., description="Recommended action")
    algorithm: str = Field("START", description="Triage algorithm used")
    widget: GenUIWidget = Field(..., description="TriageCard widget")



# ─── Image Analysis ─────────────────────────────────────────────────────────

class ImageAnalyzeResponse(BaseModel):
    """Response body for /analyze/image endpoint."""
    text: str = Field("", description="Analysis summary text")
    widgets: List[GenUIWidget] = Field(default_factory=list, description="Analysis widgets")
    image_type: Optional[str] = Field(None, description="Detected image type (ECG, wound, etc.)")


# ─── Health & Info ──────────────────────────────────────────────────────────

class HealthResponse(BaseModel):
    """Response body for /health endpoint."""
    status: str = Field("ok", description="Service status")
    model: str = Field(..., description="Loaded model name")
    quantized: bool = Field(..., description="Whether model is quantized")
    rag_documents: int = Field(0, description="Number of RAG documents")
    uptime_seconds: float = Field(0, description="Server uptime in seconds")


class ModelInfoResponse(BaseModel):
    """Response body for /model/info endpoint."""
    model_name: str
    quantized: bool
    device: str
    max_tokens: int
    rag_status: str
    rag_document_count: int
    whisper_model: str
    genui_widgets: List[str] = Field(
        default=[
            "DrugDoseCard",
            "ProtocolCard",
            "TriageCard",
            "ECGAnalysisCard",
            "VitalSignsCard",
            "PatientFormCard",
            "TranslationCard",
            "WarningCard",
        ]
    )
