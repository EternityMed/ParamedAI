"""MedGemma model loading and inference."""
import base64
import threading

import torch
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    BitsAndBytesConfig,
    TextIteratorStreamer,
)

from app.config import settings
from app.core.prompt_builder import PromptBuilder


class MedGemmaEngine:
    """Handles MedGemma model loading, inference, and streaming."""

    def __init__(self, model_name: str, quantize: bool = True, device: str = "cuda"):
        self.model_name = model_name
        self.quantize = quantize
        self.device = device
        self.model = None
        self.tokenizer = None
        self.prompt_builder = PromptBuilder()

    async def load(self):
        """Load the MedGemma model and tokenizer."""
        print(f"Loading {self.model_name}...")
        self.tokenizer = AutoTokenizer.from_pretrained(self.model_name)

        if self.quantize:
            bnb_config = BitsAndBytesConfig(
                load_in_4bit=True,
                bnb_4bit_compute_dtype=torch.bfloat16,
                bnb_4bit_quant_type="nf4",
            )
            self.model = AutoModelForCausalLM.from_pretrained(
                self.model_name,
                quantization_config=bnb_config,
                device_map="auto",
                torch_dtype=torch.bfloat16,
            )
        else:
            self.model = AutoModelForCausalLM.from_pretrained(
                self.model_name,
                device_map="auto",
                torch_dtype=torch.bfloat16,
            )

        print(f"Model loaded: {self.model_name}")

    async def generate(
        self,
        user_message: str,
        context: str = "",
        image_data: bytes = None,
        system_prompt: str = None,
        genui_mode: bool = True,
        prompt_type: str = "chat",
    ) -> dict:
        """Generate a response from MedGemma.

        Args:
            user_message: The user's input message.
            context: Optional RAG-retrieved context to augment the prompt.
            image_data: Optional image bytes for vision analysis.
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

        if context:
            augmented_message = (
                f"Relevant protocol information:\n{context}\n\n"
                f"User question: {user_message}"
            )
        else:
            augmented_message = user_message

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": augmented_message},
        ]

        # Handle multimodal input (image + text)
        if image_data:
            b64 = base64.b64encode(image_data).decode()
            messages[1]["content"] = [
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
                {"type": "text", "text": augmented_message},
            ]

        input_ids = self.tokenizer.apply_chat_template(
            messages, return_tensors="pt", add_generation_prompt=True
        ).to(self.model.device)

        with torch.no_grad():
            outputs = self.model.generate(
                input_ids,
                max_new_tokens=settings.MAX_NEW_TOKENS,
                temperature=0.3,
                top_p=0.9,
                do_sample=True,
            )

        response_text = self.tokenizer.decode(
            outputs[0][input_ids.shape[-1]:], skip_special_tokens=True
        )

        if genui_mode:
            return self.prompt_builder.parse_genui_response(response_text)
        return {"text": response_text, "widgets": []}

    async def generate_stream(self, user_message: str, context: str = "", **kwargs):
        """Stream tokens from MedGemma using TextIteratorStreamer.

        Args:
            user_message: The user's input message.
            context: Optional RAG-retrieved context.

        Yields:
            String tokens as they are generated.
        """
        system_prompt = self.prompt_builder.build_system_prompt(genui_mode=True)

        if context:
            augmented_message = (
                f"Relevant protocol information:\n{context}\n\n"
                f"User question: {user_message}"
            )
        else:
            augmented_message = user_message

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": augmented_message},
        ]

        input_ids = self.tokenizer.apply_chat_template(
            messages, return_tensors="pt", add_generation_prompt=True
        ).to(self.model.device)

        streamer = TextIteratorStreamer(self.tokenizer, skip_special_tokens=True)

        thread = threading.Thread(
            target=self.model.generate,
            kwargs={
                "input_ids": input_ids,
                "max_new_tokens": settings.MAX_NEW_TOKENS,
                "temperature": 0.3,
                "streamer": streamer,
            },
        )
        thread.start()

        for token in streamer:
            yield token

        thread.join()
