"""Vertex AI MedGemma integration via Endpoint predict API."""
import os
from typing import AsyncIterator

from app.config import settings
from app.core.prompt_builder import PromptBuilder


class VertexMedGemmaEngine:
    """MedGemma inference via Google Cloud Vertex AI Endpoint predict API."""

    def __init__(self):
        self.project_id = settings.GCP_PROJECT_ID
        self.region = settings.GCP_REGION
        self.model_name = settings.VERTEX_MODEL
        self.endpoint_id = settings.VERTEX_ENDPOINT_ID
        self.prompt_builder = PromptBuilder()
        self._endpoint = None

    async def load(self):
        """Initialize Vertex AI client and endpoint."""
        if settings.GCP_SERVICE_ACCOUNT_KEY:
            os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = settings.GCP_SERVICE_ACCOUNT_KEY

        from google.cloud import aiplatform

        aiplatform.init(project=self.project_id, location=self.region)

        endpoint_name = (
            f"projects/{self.project_id}/locations/{self.region}"
            f"/endpoints/{self.endpoint_id}"
        )
        self._endpoint = aiplatform.Endpoint(endpoint_name=endpoint_name)

        print(f"Vertex AI initialized: project={self.project_id}, region={self.region}")
        print(f"Model: {self.model_name}")
        print(f"Endpoint: {self.endpoint_id}")

    def _build_instances(
        self,
        user_message: str,
        context: str = "",
        system_prompt: str = None,
    ) -> list[dict]:
        """Build chat completion instances for endpoint.predict()."""
        messages = []

        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})

        if context:
            augmented_message = (
                f"Relevant protocol information:\n{context}\n\n"
                f"User question: {user_message}"
            )
        else:
            augmented_message = user_message

        messages.append({"role": "user", "content": augmented_message})

        return [{
            "@requestFormat": "chatCompletions",
            "messages": messages,
            "max_tokens": settings.MAX_NEW_TOKENS,
            "temperature": 0.3,
            "top_p": 0.9,
        }]

    async def generate(
        self,
        user_message: str,
        context: str = "",
        image_data: bytes = None,
        system_prompt: str = None,
        genui_mode: bool = True,
        prompt_type: str = "chat",
    ) -> dict:
        """Generate response via Vertex AI Endpoint predict API.

        Args:
            user_message: The user's input message.
            context: Optional RAG-retrieved context.
            image_data: Optional image bytes (not supported for text endpoint).
            system_prompt: Optional override for the system prompt.
            genui_mode: Whether to parse response as GenUI JSON.
            prompt_type: Type of prompt ('chat', 'translation', 'triage', 'image').

        Returns:
            Dict with 'text' and 'widgets' keys.
        """
        import asyncio

        if system_prompt is None:
            system_prompt = self.prompt_builder.build_system_prompt(
                genui_mode=genui_mode, prompt_type=prompt_type
            )

        instances = self._build_instances(
            user_message=user_message,
            context=context,
            system_prompt=system_prompt,
        )

        # endpoint.predict() is synchronous — run in executor
        loop = asyncio.get_event_loop()
        response = await loop.run_in_executor(
            None, lambda: self._endpoint.predict(instances=instances)
        )

        response_text = response.predictions["choices"][0]["message"]["content"]

        if genui_mode:
            return self.prompt_builder.parse_genui_response(response_text)
        return {"text": response_text, "widgets": []}

    async def generate_stream(
        self,
        user_message: str,
        context: str = "",
        **kwargs,
    ) -> AsyncIterator[str]:
        """Stream tokens from Vertex AI.

        Note: Endpoint predict API doesn't natively stream, so we yield
        the full response as a single chunk.
        """
        result = await self.generate(
            user_message=user_message,
            context=context,
            genui_mode=False,
        )
        yield result["text"]
