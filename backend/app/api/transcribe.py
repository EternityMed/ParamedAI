"""Transcribe endpoint: /transcribe."""
from fastapi import APIRouter, File, Form, Request, UploadFile, HTTPException

from app.core.whisper_stt import WhisperSTT
from app.models.schemas import TranscribeResponse

router = APIRouter()

# Module-level Whisper instance (lazy loaded)
_whisper_stt: WhisperSTT = None


async def _get_whisper(request: Request) -> WhisperSTT:
    """Get or initialize the Whisper STT instance."""
    global _whisper_stt
    if _whisper_stt is None:
        _whisper_stt = WhisperSTT(model_name="small")
        await _whisper_stt.load()
    return _whisper_stt


@router.post("/transcribe", response_model=TranscribeResponse)
async def transcribe(
    request: Request,
    audio: UploadFile = File(..., description="Audio file (WAV, MP3, etc.)"),
    language: str = Form(None, description="Language code (e.g., 'tr', 'en'). Leave empty for auto-detect."),
):
    """Transcribe audio to text using Whisper.

    Supports multilingual transcription with Turkish, English, Arabic,
    German, French, Russian, and many other languages.

    Args:
        audio: Audio file upload.
        language: Optional language code for better accuracy.

    Returns:
        Transcribed text with language detection and confidence.
    """
    # Validate file type
    allowed_types = [
        "audio/wav", "audio/wave", "audio/x-wav",
        "audio/mpeg", "audio/mp3",
        "audio/ogg", "audio/flac",
        "audio/webm", "audio/mp4",
        "application/octet-stream",  # fallback for unknown types
    ]
    if audio.content_type and audio.content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported audio format: {audio.content_type}. Supported: WAV, MP3, OGG, FLAC, WebM",
        )

    # Read audio data
    audio_data = await audio.read()
    if len(audio_data) == 0:
        raise HTTPException(status_code=400, detail="Empty audio file.")

    # Transcribe
    whisper = await _get_whisper(request)
    result = await whisper.transcribe(audio_data=audio_data, language=language)

    return TranscribeResponse(
        text=result["text"],
        language=result["language"],
        confidence=result["confidence"],
        segments=result.get("segments", []),
    )
