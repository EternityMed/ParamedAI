"""Whisper multilingual speech-to-text."""
import os
import tempfile


class WhisperSTT:
    """Wrapper around OpenAI Whisper for multilingual speech-to-text transcription."""

    def __init__(self, model_name: str = "small"):
        self.model_name = model_name
        self.model = None

    async def load(self):
        """Load the Whisper model."""
        import whisper
        print(f"Loading Whisper model: {self.model_name}...")
        self.model = whisper.load_model(self.model_name)
        print(f"Whisper model loaded: {self.model_name}")

    async def transcribe(self, audio_data: bytes, language: str = None) -> dict:
        """Transcribe audio data to text.

        Args:
            audio_data: Raw audio bytes (WAV, MP3, etc.).
            language: Optional language code (e.g., 'tr', 'en', 'ar').
                     If None, Whisper will auto-detect.

        Returns:
            Dict with 'text', 'language', and 'confidence' keys.
        """
        if self.model is None:
            raise RuntimeError("Whisper model not loaded. Call load() first.")

        # Write audio to temp file (Whisper requires file path)
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            f.write(audio_data)
            tmp_path = f.name

        try:
            options = {}
            if language:
                options["language"] = language

            result = self.model.transcribe(tmp_path, **options)

            # Extract segments for confidence estimation
            segments = result.get("segments", [])
            if segments:
                avg_confidence = sum(
                    seg.get("avg_logprob", -0.5) for seg in segments
                ) / len(segments)
                # Convert log prob to rough confidence score (0-1)
                confidence = min(1.0, max(0.0, 1.0 + avg_confidence))
            else:
                confidence = 0.95

            return {
                "text": result["text"].strip(),
                "language": result.get("language", language or "unknown"),
                "segments": [
                    {
                        "start": seg["start"],
                        "end": seg["end"],
                        "text": seg["text"],
                    }
                    for seg in segments
                ],
                "confidence": round(confidence, 3),
            }
        finally:
            os.unlink(tmp_path)
