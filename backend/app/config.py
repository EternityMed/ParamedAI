"""Environment-based configuration."""
import os
from pathlib import Path
from pydantic_settings import BaseSettings

# Find .env at project root (two levels up from this file)
_PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
_ENV_FILE = _PROJECT_ROOT / ".env"


class Settings(BaseSettings):
    # Mode: "deepinfra", "dr7ai", "vertex" (Vertex AI online), "local" (HuggingFace offline), "auto"
    INFERENCE_MODE: str = "auto"

    # LM Studio settings (local OpenAI-compatible API)
    LMSTUDIO_BASE_URL: str = "http://localhost:1234/v1"
    LMSTUDIO_MODEL: str = "medgemma-27b-it"

    # DeepInfra settings (preferred online mode)
    DEEPINFRA_API_KEY: str = ""
    DEEPINFRA_MODEL: str = "google/gemma-3-27b-it"

    # Dr7.ai settings
    DR7AI_API_KEY: str = ""
    DR7AI_MODEL: str = "medgemma-27b-it"

    # Vertex AI settings
    GCP_PROJECT_ID: str = ""
    GCP_REGION: str = "europe-west4"
    GCP_SERVICE_ACCOUNT_KEY: str = ""  # Path to service account JSON file
    VERTEX_MODEL: str = "medgemma-1.5-27b-it"  # Model name on Vertex AI
    VERTEX_ENDPOINT_ID: str = ""  # Endpoint ID (e.g. "mg-endpoint-xxx")

    # Local HuggingFace model settings (offline / edge)
    MEDGEMMA_MODEL: str = "google/medgemma-1.5-4b-it"
    QUANTIZE_MODEL: bool = True
    DEVICE: str = "cuda"
    MAX_NEW_TOKENS: int = 2048

    # STT
    WHISPER_MODEL: str = "openai/whisper-small"

    # RAG
    CHROMA_DB_PATH: str = "./app/data/embeddings/chroma_db"
    EMBEDDING_MODEL: str = "all-MiniLM-L6-v2"
    RAG_TOP_K: int = 5

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8080

    class Config:
        env_file = str(_ENV_FILE)


settings = Settings()
