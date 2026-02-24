"""ParaMed AI Backend - FastAPI Application.

AI-powered assistant for 112 EMS paramedics, built on MedGemma.
Supports dual mode: Vertex AI (online) and local HuggingFace (offline).
"""
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.api.router import api_router
from app.core.rag_engine import RAGEngine


async def _load_medgemma_engine():
    """Load the appropriate MedGemma engine based on INFERENCE_MODE."""
    mode = settings.INFERENCE_MODE

    if mode == "lmstudio":
        from app.core.lmstudio_engine import LMStudioEngine
        engine = LMStudioEngine()
        await engine.load()
        return engine, "lmstudio"

    elif mode == "deepinfra":
        from app.core.deepinfra_engine import DeepInfraEngine
        engine = DeepInfraEngine()
        await engine.load()
        return engine, "deepinfra"

    elif mode == "dr7ai":
        from app.core.dr7ai_medgemma import Dr7AIMedGemmaEngine
        engine = Dr7AIMedGemmaEngine()
        await engine.load()
        return engine, "dr7ai"

    elif mode == "vertex":
        from app.core.vertex_medgemma import VertexMedGemmaEngine
        engine = VertexMedGemmaEngine()
        await engine.load()
        return engine, "vertex"

    elif mode == "local":
        from app.core.medgemma import MedGemmaEngine
        engine = MedGemmaEngine(
            model_name=settings.MEDGEMMA_MODEL,
            quantize=settings.QUANTIZE_MODEL,
            device=settings.DEVICE,
        )
        await engine.load()
        return engine, "local"

    else:  # "auto" — try DeepInfra first, then Dr7.ai, Vertex, fallback to local
        if settings.DEEPINFRA_API_KEY:
            try:
                from app.core.deepinfra_engine import DeepInfraEngine
                engine = DeepInfraEngine()
                await engine.load()
                print("Auto mode: Using DeepInfra API (online)")
                return engine, "deepinfra"
            except Exception as e:
                print(f"DeepInfra failed ({e}), trying Dr7.ai...")

        if settings.DR7AI_API_KEY:
            try:
                from app.core.dr7ai_medgemma import Dr7AIMedGemmaEngine
                engine = Dr7AIMedGemmaEngine()
                await engine.load()
                print("Auto mode: Using Dr7.ai API (online)")
                return engine, "dr7ai"
            except Exception as e:
                print(f"Dr7.ai failed ({e}), trying Vertex AI...")

        if settings.GCP_PROJECT_ID:
            try:
                from app.core.vertex_medgemma import VertexMedGemmaEngine
                engine = VertexMedGemmaEngine()
                await engine.load()
                print("Auto mode: Using Vertex AI (online)")
                return engine, "vertex"
            except Exception as e:
                print(f"Vertex AI failed ({e}), falling back to local model...")

        from app.core.medgemma import MedGemmaEngine
        engine = MedGemmaEngine(
            model_name=settings.MEDGEMMA_MODEL,
            quantize=settings.QUANTIZE_MODEL,
            device=settings.DEVICE,
        )
        await engine.load()
        print("Auto mode: Using local HuggingFace model (offline)")
        return engine, "local"


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan: load models on startup, cleanup on shutdown."""
    app.state.start_time = time.time()

    # Load MedGemma (Vertex AI or local)
    engine, mode = await _load_medgemma_engine()
    app.state.medgemma = engine
    app.state.inference_mode = mode

    # Initialize RAG engine
    app.state.rag = RAGEngine(
        db_path=settings.CHROMA_DB_PATH,
        embedding_model=settings.EMBEDDING_MODEL,
    )
    await app.state.rag.initialize()

    if mode == "lmstudio":
        model_label = settings.LMSTUDIO_MODEL
    elif mode == "deepinfra":
        model_label = settings.DEEPINFRA_MODEL
    elif mode == "dr7ai":
        model_label = settings.DR7AI_MODEL
    elif mode == "vertex":
        model_label = settings.VERTEX_MODEL
    else:
        model_label = settings.MEDGEMMA_MODEL
    print(
        f"ParaMed AI Backend ready | "
        f"Mode: {mode} | "
        f"Model: {model_label}"
    )

    yield

    # Cleanup
    del app.state.medgemma
    del app.state.rag


app = FastAPI(
    title="ParaMed AI",
    description="AI assistant for 112 EMS paramedics powered by MedGemma",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api/v1")
