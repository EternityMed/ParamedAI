#!/bin/bash
set -e
echo "=== Building RAG Database ==="

cd backend
python -c "
import asyncio
from app.core.rag_engine import RAGEngine

async def build():
    rag = RAGEngine(
        db_path='./app/data/embeddings/chroma_db',
        embedding_model='all-MiniLM-L6-v2'
    )
    await rag.initialize()
    print(f'RAG database built with {rag.collection.count()} documents.')

asyncio.run(build())
"

echo "=== RAG database ready ==="
