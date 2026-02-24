"""API route aggregation."""
from fastapi import APIRouter

from app.api import chat, transcribe, analyze, triage, drug, patients

api_router = APIRouter()

api_router.include_router(chat.router, tags=["Chat"])
api_router.include_router(transcribe.router, tags=["Transcribe"])
api_router.include_router(analyze.router, tags=["Analyze"])
api_router.include_router(triage.router, tags=["Triage"])
api_router.include_router(drug.router, tags=["Drug Calculator"])
api_router.include_router(patients.router, tags=["Patients"])
