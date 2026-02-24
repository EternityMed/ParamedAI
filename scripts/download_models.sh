#!/bin/bash
set -e
echo "=== Downloading Models ==="

echo "1. Downloading MedGemma 1.5 4B-IT..."
python -c "
from transformers import AutoTokenizer, AutoModelForCausalLM
print('Downloading tokenizer...')
AutoTokenizer.from_pretrained('google/medgemma-1.5-4b-it')
print('Downloading model...')
AutoModelForCausalLM.from_pretrained('google/medgemma-1.5-4b-it')
print('MedGemma 4B downloaded successfully.')
"

echo "2. Downloading Whisper Small..."
python -c "
import whisper
whisper.load_model('small')
print('Whisper Small downloaded successfully.')
"

echo "3. Downloading embedding model..."
python -c "
from sentence_transformers import SentenceTransformer
SentenceTransformer('all-MiniLM-L6-v2')
print('Embedding model downloaded successfully.')
"

echo "=== All models downloaded ==="
