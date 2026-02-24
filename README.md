# ParaMed AI

AI-powered clinical decision support for 112 Emergency Medical Services (EMS) paramedics, built on MedGemma for the [MedGemma Impact Challenge 2026](https://www.kaggle.com/competitions/med-gemma-impact-challenge).

ParaMed AI is one of two systems in our submission. The companion project, **EMSGemmaApp** (dispatch center with SmartDispatch 4-agent pipeline), handles the call side. ParaMed AI handles the field side — giving paramedics offline-capable clinical decision support.

## Features

- **Clinical Decision Support** — AI-powered Q&A with emergency protocol guidance, drug dose calculations, and EKG analysis
- **MCI Triage** — START/JumpSTART deterministic triage algorithms with color-coded patient tracking
- **Voice Documentation** — Medical speech recognition (MedASR) with auto-filled structured patient forms
- **Multilingual Translation** — Medical translation for refugee populations (Arabic, Farsi, English, Turkish)
- **Offline-First** — MedGemma 4B (2.64 GB GGUF) runs on Android via llamadart with zero connectivity required
- **8 GenUI Medical Widgets** — DrugDoseCard, TriageCard, ProtocolCard, ECGAnalysisCard, VitalSignsCard, PatientFormCard, TranslationCard, WarningCard

## Architecture

ParaMed AI consists of a **Flutter mobile app** and a **FastAPI backend**. The app auto-switches between online (MedGemma 27B via backend) and offline (MedGemma 4B on-device) based on connectivity.

| Component | Technology |
|-----------|-----------|
| Mobile App | Flutter 3.27+, GenUI 0.6.1, Riverpod |
| Backend | Python 3.12, FastAPI |
| AI (online) | MedGemma 27B-IT via / Dr7.ai / Vertex AI / LM Studio |
| AI (offline) | MedGemma 4B-IT (Q4_K_M, 2.64 GB GGUF) via llamadart |
| Speech-to-Text | sherpa-onnx MedASR (offline/online) |
| RAG | ChromaDB + all-MiniLM-L6-v2 (online), keyword-based (offline) |
| Drug Calculator | Deterministic — 15 emergency drugs, weight-based, ERC/ILCOR/AHA caps |

## Project Structure

```
112gemma/
├── backend/                  # FastAPI backend server
│   ├── app/
│   │   ├── api/              # API route handlers
│   │   │   ├── chat.py       # Chat with GenUI widget output
│   │   │   ├── analyze.py    # Image analysis (EKG, wounds)
│   │   │   ├── transcribe.py # Audio-to-text (Whisper)
│   │   │   ├── triage.py     # START triage classification
│   │   │   ├── drug.py       # Deterministic drug calculator
│   │   │   └── patients.py   # Patient record management
│   │   ├── core/             # Inference engines
│   │   │   ├── deepinfra_engine.py
│   │   │   ├── dr7ai_medgemma.py
│   │   │   ├── vertex_medgemma.py
│   │   │   ├── lmstudio_engine.py
│   │   │   ├── medgemma.py   # Local HuggingFace engine
│   │   │   ├── rag_engine.py
│   │   │   ├── whisper_stt.py
│   │   │   └── prompt_builder.py
│   │   ├── data/             # Embeddings and protocol data
│   │   ├── config.py         # Environment-based settings
│   │   └── main.py           # FastAPI app entrypoint
│   └── requirements.txt
├── flutter_app/              # Flutter mobile app (ParaMed AI)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── config/           # App configuration
│   │   ├── core/             # Connectivity, inference, providers
│   │   ├── features/         # Chat, triage, documentation, setup
│   │   ├── shared/           # Shared models and utilities
│   │   └── widgets/          # 8 GenUI medical widget renderers
│   ├── assets/
│   │   ├── protocols/        # 13 ERC/ILCOR/AHA protocol JSONs
│   │   └── medasr/           # On-device speech recognition model
│   └── pubspec.yaml
├── data/protocols/           # Source protocol files (13 protocols)
├── scripts/                  # Setup and build scripts
├── .env.example              # Environment configuration template
└── README.md
```

## Prerequisites

- **Python 3.12+** with pip
- **Flutter 3.27+** with Dart SDK 3.6+
- **Android/iOS device or emulator** (for mobile app, local models require real device for testing)

## Setup

### 1. Clone and configure environment

```bash
cd ParamedAI
cp .env.example .env
```

Edit `.env` to set your inference mode and API keys:

```env
# Choose one: "dr7ai", "vertex", "lmstudio", "local", "auto"
INFERENCE_MODE=dr7ai

# Dr7.ai
DR7AI_API_KEY=your-api-key-here
DR7AI_MODEL=medgemma-27b-it

# Vertex AI (requires GCP project)
GCP_PROJECT_ID=your-gcp-project-id
GCP_REGION=europe-west4
GCP_SERVICE_ACCOUNT_KEY=path/to/service-account.json
VERTEX_MODEL=medgemma-1.5-27b-it

# LM Studio (local OpenAI-compatible server)
LMSTUDIO_BASE_URL=http://localhost:1234/v1
LMSTUDIO_MODEL=medgemma-27b-it

```

The `auto` mode tries engines in order: DeepInfra > Dr7.ai > Vertex AI > LM Studio > Local HuggingFace.

### 2. Backend

```bash
cd backend
python -m venv venv

# Linux/macOS
source venv/bin/activate
# Windows
venv\Scripts\activate

pip install -r requirements.txt
```

**Build the RAG database** (required for protocol retrieval):

```bash
python -c "
import asyncio
from app.core.rag_engine import RAGEngine

async def build():
    rag = RAGEngine(db_path='./app/data/embeddings/chroma_db', embedding_model='all-MiniLM-L6-v2')
    await rag.initialize()
    print(f'RAG database built with {rag.collection.count()} documents.')

asyncio.run(build())
"
```

**Start the backend:**

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8080
```

The backend will load the configured inference engine and RAG on startup. Check `http://localhost:8080/api/v1/health` to verify.

### 3. Flutter App

```bash
cd flutter_app
flutter pub get
flutter run
```

For Android device deployment:

```bash
flutter run -d <device-id>
```

The app will auto-detect the backend at `localhost:8080`. If the backend is unreachable, it falls back to on-device MedGemma 4B inference (requires the GGUF model file in the app's assets).

### Automated Setup (Linux/macOS)

```bash
./scripts/setup_local.sh
```

This creates the Python virtualenv, installs dependencies, sets up Flutter, and copies `.env.example` to `backend/.env`.

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/chat` | Chat with GenUI widget output |
| POST | `/api/v1/chat/stream` | SSE streaming chat |
| POST | `/api/v1/transcribe` | Audio to text (Whisper) |
| POST | `/api/v1/analyze/image` | EKG / wound image analysis |
| POST | `/api/v1/triage/classify` | START triage classification |
| POST | `/api/v1/drug/calculate` | Deterministic drug dose calculation |
| GET | `/api/v1/health` | Health check |
| GET | `/api/v1/model/info` | Active model and inference mode |

## Inference Modes

| Mode | Model | Requirements |
|------|-------|-------------|
| `deepinfra` | MedGemma 27B via DeepInfra API | API key |
| `dr7ai` | MedGemma 27B via Dr7.ai API | API key |
| `vertex` | MedGemma 27B via Vertex AI | GCP project + service account |
| `lmstudio` | MedGemma 27B via LM Studio | LM Studio running locally |
| `local` | MedGemma 4B via HuggingFace | CUDA GPU (~16 GB VRAM for 4-bit) |
| `auto` | Tries all above in order | Falls back to whatever is available |

