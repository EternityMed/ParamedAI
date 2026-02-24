"""Patient documentation endpoint: /patients/document."""
from fastapi import APIRouter, Request
from pydantic import BaseModel, Field

router = APIRouter()


class DocumentRequest(BaseModel):
    """Request body for AI medical documentation generation."""
    transcription: str = Field(..., description="Voice transcription text")


class DocumentResponse(BaseModel):
    """Response body with AI-generated medical documentation."""
    documentation: str = Field(..., description="Structured medical documentation")


@router.post("/patients/document", response_model=DocumentResponse)
async def generate_documentation(request: Request, body: DocumentRequest):
    """Generate structured medical documentation from voice transcription using MedGemma.

    Takes raw transcribed text and produces a structured prehospital care report.
    """
    medgemma = request.app.state.medgemma

    prompt = (
        "You are an emergency medicine physician. Convert the following voice transcription "
        "into a structured prehospital medical documentation.\n\n"
        "Include these sections if information is available:\n"
        "- Chief Complaint\n"
        "- History of Present Illness (HPI)\n"
        "- Vital Signs\n"
        "- Physical Examination\n"
        "- Assessment\n"
        "- Interventions / Plan\n\n"
        "If information for a section is not mentioned, skip that section.\n"
        "Be concise and use medical terminology.\n\n"
        f"Voice transcription:\n{body.transcription}"
    )

    try:
        result = await medgemma.generate(
            user_message=prompt,
            genui_mode=False,
        )
        return DocumentResponse(documentation=result.get("text", ""))
    except Exception as e:
        return DocumentResponse(
            documentation=f"Error generating documentation: {str(e)}"
        )
