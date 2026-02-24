"""Image analysis endpoint: /analyze/image."""
from fastapi import APIRouter, File, Form, Request, UploadFile, HTTPException

from app.models.schemas import GenUIWidget, ImageAnalyzeResponse

router = APIRouter()


@router.post("/analyze/image", response_model=ImageAnalyzeResponse)
async def analyze_image(
    request: Request,
    image: UploadFile = File(..., description="Medical image file (ECG, wound photo, X-ray, etc.)"),
    query: str = Form("Analyze this medical image and provide findings.", description="Analysis query"),
    image_type: str = Form(None, description="Image type hint: ecg, wound, xray, monitor"),
):
    """Analyze a medical image using MedGemma's vision capabilities.

    Supports ECG strips, wound photographs, X-rays, and vital signs monitors.
    Returns structured GenUI widgets with findings and recommendations.

    Args:
        image: Medical image file upload.
        query: Specific analysis question (default: general analysis).
        image_type: Optional hint about image type for better analysis.

    Returns:
        Analysis results with appropriate GenUI widgets.
    """
    # Validate image type
    allowed_types = [
        "image/jpeg", "image/jpg", "image/png",
        "image/gif", "image/bmp", "image/webp",
        "application/octet-stream",
    ]
    if image.content_type and image.content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported image format: {image.content_type}. Supported: JPEG, PNG, GIF, BMP, WebP",
        )

    # Read image data
    image_data = await image.read()
    if len(image_data) == 0:
        raise HTTPException(status_code=400, detail="Empty image file.")

    # Size limit (10 MB)
    if len(image_data) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Image too large. Maximum size: 10 MB.")

    # Build analysis prompt
    if image_type:
        type_hint = f"This is a {image_type} image. "
    else:
        type_hint = ""

    analysis_prompt = f"{type_hint}{query}"

    # Analyze with MedGemma
    medgemma = request.app.state.medgemma

    result = await medgemma.generate(
        user_message=analysis_prompt,
        image_data=image_data,
        genui_mode=True,
        prompt_type="image",
    )

    # Ensure there is always a safety warning widget
    widgets = [GenUIWidget(**w) for w in result.get("widgets", [])]
    has_warning = any(w.type == "WarningCard" for w in widgets)
    if not has_warning:
        widgets.append(
            GenUIWidget(
                type="WarningCard",
                data={
                    "title": "AI Analiz Uyarisi",
                    "message": "Bu AI tarafindan yapilmis bir on analizdir. Kesin tani icin uzman doktor degerlendirmesi gereklidir.",
                    "severity": "INFO",
                    "action": "Sonuclari hekim ile paylasin.",
                },
            )
        )

    return ImageAnalyzeResponse(
        text=result.get("text", ""),
        widgets=widgets,
        image_type=image_type,
    )
