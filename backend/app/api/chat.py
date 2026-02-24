"""Chat endpoints: /chat, /chat/stream, /health, /model/info."""
import json
import time
import uuid

from fastapi import APIRouter, Request
from fastapi.responses import StreamingResponse

from app.config import settings
from app.models.schemas import (
    ChatRequest,
    ChatResponse,
    GenUIWidget,
    HealthResponse,
    ModelInfoResponse,
)
from app.services.clinical_decision import ClinicalDecisionService

router = APIRouter()


@router.post("/chat", response_model=ChatResponse)
async def chat(request: Request, body: ChatRequest):
    """Main chat endpoint with GenUI widget output.

    Uses RAG-augmented MedGemma for clinical decision support.
    Drug dose queries are handled deterministically (never by LLM).
    """
    medgemma = request.app.state.medgemma
    rag = request.app.state.rag
    service = ClinicalDecisionService(medgemma=medgemma, rag=rag)

    result = await service.process_query(
        message=body.message,
        patient_context=body.patient_context,
        genui_mode=body.genui_mode,
    )

    conversation_id = body.conversation_id or str(uuid.uuid4())

    return ChatResponse(
        text=result.get("text", ""),
        widgets=[GenUIWidget(**w) for w in result.get("widgets", [])],
        conversation_id=conversation_id,
        rag_sources=result.get("rag_sources", []),
    )


@router.post("/chat/stream")
async def chat_stream(request: Request, body: ChatRequest):
    """SSE streaming chat endpoint.

    Streams tokens as Server-Sent Events for real-time UI updates.
    """
    medgemma = request.app.state.medgemma
    rag = request.app.state.rag
    service = ClinicalDecisionService(medgemma=medgemma, rag=rag)

    async def event_generator():
        try:
            async for token in service.process_stream(
                message=body.message,
                patient_context=body.patient_context,
            ):
                data = json.dumps({"type": "token", "content": token})
                yield f"data: {data}\n\n"

            # Send done event
            yield f"data: {json.dumps({'type': 'done'})}\n\n"
        except Exception as e:
            error_data = json.dumps({"type": "error", "content": str(e)})
            yield f"data: {error_data}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@router.get("/health", response_model=HealthResponse)
async def health_check(request: Request):
    """Health check endpoint."""
    start_time = getattr(request.app.state, "start_time", time.time())
    uptime = time.time() - start_time
    mode = getattr(request.app.state, "inference_mode", "unknown")

    rag = getattr(request.app.state, "rag", None)
    rag_count = 0
    if rag:
        stats = rag.get_collection_stats()
        rag_count = stats.get("count", 0)

    if mode == "lmstudio":
        model_name = settings.LMSTUDIO_MODEL
    elif mode == "deepinfra":
        model_name = settings.DEEPINFRA_MODEL
    elif mode == "dr7ai":
        model_name = settings.DR7AI_MODEL
    elif mode == "vertex":
        model_name = settings.VERTEX_MODEL
    else:
        model_name = settings.MEDGEMMA_MODEL

    return HealthResponse(
        status="ok",
        model=model_name,
        quantized=settings.QUANTIZE_MODEL if mode == "local" else False,
        rag_documents=rag_count,
        uptime_seconds=round(uptime, 2),
    )


@router.get("/model/info", response_model=ModelInfoResponse)
async def model_info(request: Request):
    """Return model and service configuration info."""
    mode = getattr(request.app.state, "inference_mode", "unknown")
    if mode == "lmstudio":
        model_name = settings.LMSTUDIO_MODEL
    elif mode == "deepinfra":
        model_name = settings.DEEPINFRA_MODEL
    elif mode == "dr7ai":
        model_name = settings.DR7AI_MODEL
    elif mode == "vertex":
        model_name = settings.VERTEX_MODEL
    else:
        model_name = settings.MEDGEMMA_MODEL

    return ModelInfoResponse(
        model_name=model_name,
        quantized=settings.QUANTIZE_MODEL if mode == "local" else False,
        device=settings.DEVICE if mode == "local" else ("deepinfra" if mode == "deepinfra" else ("dr7ai" if mode == "dr7ai" else "cloud")),
        max_tokens=settings.MAX_NEW_TOKENS,
        rag_status="active",
        rag_document_count=0,
        whisper_model=settings.WHISPER_MODEL,
    )
