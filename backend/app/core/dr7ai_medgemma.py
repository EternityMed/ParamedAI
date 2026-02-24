"""Dr7.ai MedGemma integration — OpenAI-compatible API with streaming and image support."""
import base64
from typing import AsyncIterator, Optional

import httpx

from app.config import settings
from app.core.prompt_builder import PromptBuilder


class Dr7AIMedGemmaEngine:
    """MedGemma inference via Dr7.ai API (OpenAI-compatible)."""

    BASE_URL = "https://dr7.ai/api/v1"

    def __init__(self):
        self.api_key = settings.DR7AI_API_KEY
        self.model = settings.DR7AI_MODEL
        self.prompt_builder = PromptBuilder()
        self._client: Optional[httpx.AsyncClient] = None

    async def load(self):
        """Initialize the async HTTP client and verify API access."""
        self._client = httpx.AsyncClient(
            base_url=self.BASE_URL,
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            timeout=httpx.Timeout(120.0, connect=10.0),
        )

        # Verify API key by listing models
        resp = await self._client.get("/models")
        resp.raise_for_status()
        models = resp.json()
        model_ids = [m["id"] for m in models.get("data", [])]

        if self.model not in model_ids:
            available = ", ".join(model_ids)
            raise ValueError(
                f"Model '{self.model}' not found on Dr7.ai. Available: {available}"
            )

        print(f"Dr7.ai initialized: model={self.model}")
        print(f"Available models: {', '.join(model_ids)}")

    def _build_messages(
        self,
        user_message: str,
        context: str = "",
        system_prompt: Optional[str] = None,
        image_data: Optional[bytes] = None,
    ) -> list[dict]:
        """Build chat messages array for the API request."""
        messages = []

        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})

        # Build user message content
        if context:
            text_content = (
                f"Relevant protocol information:\n{context}\n\n"
                f"User question: {user_message}"
            )
        else:
            text_content = user_message

        # If image_data is provided, use multimodal message format
        if image_data is not None:
            b64_image = base64.b64encode(image_data).decode("utf-8")
            messages.append({
                "role": "user",
                "content": [
                    {"type": "text", "text": text_content},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{b64_image}",
                        },
                    },
                ],
            })
        else:
            messages.append({"role": "user", "content": text_content})

        return messages

    async def generate(
        self,
        user_message: str,
        context: str = "",
        image_data: Optional[bytes] = None,
        system_prompt: Optional[str] = None,
        genui_mode: bool = True,
        prompt_type: str = "chat",
    ) -> dict:
        """Generate a non-streaming response from Dr7.ai.

        Args:
            user_message: The user's input message.
            context: Optional RAG-retrieved context.
            image_data: Optional image bytes for multimodal analysis.
            system_prompt: Optional override for the system prompt.
            genui_mode: Whether to parse response as GenUI JSON.
            prompt_type: Type of prompt ('chat', 'translation', 'triage', 'image').

        Returns:
            Dict with 'text' and 'widgets' keys.
        """
        if system_prompt is None:
            system_prompt = self.prompt_builder.build_system_prompt(
                genui_mode=genui_mode, prompt_type=prompt_type
            )

        messages = self._build_messages(
            user_message=user_message,
            context=context,
            system_prompt=system_prompt,
            image_data=image_data,
        )

        payload = {
            "model": self.model,
            "messages": messages,
            "max_tokens": settings.MAX_NEW_TOKENS,
            "temperature": 0.3,
            "top_p": 0.9,
            "stream": False,
        }

        resp = await self._client.post("/medical/chat/completions", json=payload)
        if resp.status_code != 200:
            error_body = resp.json() if resp.headers.get("content-type", "").startswith("application/json") else {}
            error_msg = error_body.get("error", {}).get("message", resp.text)
            raise RuntimeError(f"Dr7.ai API error ({resp.status_code}): {error_msg}")
        data = resp.json()

        response_text = data["choices"][0]["message"]["content"]

        if genui_mode:
            return self.prompt_builder.parse_genui_response(response_text)
        return {"text": response_text, "widgets": []}

    async def generate_stream(
        self,
        user_message: str,
        context: str = "",
        image_data: Optional[bytes] = None,
        system_prompt: Optional[str] = None,
        prompt_type: str = "chat",
    ) -> AsyncIterator[str]:
        """Stream tokens from Dr7.ai via SSE.

        Yields text chunks as they arrive from the API.
        """
        if system_prompt is None:
            system_prompt = self.prompt_builder.build_system_prompt(
                genui_mode=False, prompt_type=prompt_type
            )

        messages = self._build_messages(
            user_message=user_message,
            context=context,
            system_prompt=system_prompt,
            image_data=image_data,
        )

        payload = {
            "model": self.model,
            "messages": messages,
            "max_tokens": settings.MAX_NEW_TOKENS,
            "temperature": 0.3,
            "top_p": 0.9,
            "stream": True,
        }

        import json

        async with self._client.stream(
            "POST", "/medical/chat/completions", json=payload
        ) as resp:
            if resp.status_code != 200:
                body = await resp.aread()
                raise RuntimeError(f"Dr7.ai streaming error ({resp.status_code}): {body.decode()}")
            async for line in resp.aiter_lines():
                if not line.startswith("data: "):
                    continue
                data_str = line[6:]  # strip "data: " prefix
                if data_str.strip() == "[DONE]":
                    break
                try:
                    chunk = json.loads(data_str)
                    delta = chunk.get("choices", [{}])[0].get("delta", {})
                    content = delta.get("content", "")
                    if content:
                        yield content
                except (json.JSONDecodeError, IndexError, KeyError):
                    continue

    async def close(self):
        """Close the HTTP client."""
        if self._client:
            await self._client.aclose()
            self._client = None
