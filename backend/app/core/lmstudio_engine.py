"""LM Studio engine — OpenAI-compatible local API for MedGemma testing."""
import base64
import json
from typing import AsyncIterator, Optional

import httpx

from app.config import settings
from app.core.prompt_builder import PromptBuilder


class LMStudioEngine:
    """Inference via LM Studio's OpenAI-compatible local API."""

    def __init__(self):
        self.base_url = settings.LMSTUDIO_BASE_URL
        self.model = settings.LMSTUDIO_MODEL
        self.prompt_builder = PromptBuilder()
        self._client: Optional[httpx.AsyncClient] = None

    async def load(self):
        """Initialize the async HTTP client and verify LM Studio is running."""
        self._client = httpx.AsyncClient(
            base_url=self.base_url,
            headers={"Content-Type": "application/json"},
            timeout=httpx.Timeout(300.0, connect=10.0),
        )

        # Verify LM Studio is reachable
        resp = await self._client.post(
            "/chat/completions",
            json={
                "model": self.model,
                "messages": [{"role": "user", "content": "ping"}],
                "max_tokens": 5,
            },
        )
        resp.raise_for_status()
        print(f"LM Studio initialized: model={self.model} at {self.base_url}")

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

        if context:
            text_content = (
                f"Relevant protocol information:\n{context}\n\n"
                f"User question: {user_message}"
            )
        else:
            text_content = user_message

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
        """Generate a non-streaming response from LM Studio."""
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

        resp = await self._client.post("/chat/completions", json=payload)
        if resp.status_code != 200:
            raise RuntimeError(f"LM Studio API error ({resp.status_code}): {resp.text}")
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
        """Stream tokens from LM Studio via SSE."""
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

        async with self._client.stream(
            "POST", "/chat/completions", json=payload
        ) as resp:
            if resp.status_code != 200:
                body = await resp.aread()
                raise RuntimeError(f"LM Studio streaming error ({resp.status_code}): {body.decode()}")
            async for line in resp.aiter_lines():
                if not line.startswith("data: "):
                    continue
                data_str = line[6:]
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
