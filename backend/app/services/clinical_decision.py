"""Clinical Decision Support service.

Orchestrates RAG context retrieval, MedGemma inference, and
deterministic drug calculation to provide comprehensive clinical
decision support to paramedics.
"""
from typing import Any, Dict, List, Optional

from app.core.rag_engine import RAGEngine
from app.services.drug_calculator import DrugCalculator


class ClinicalDecisionService:
    """Orchestrates RAG + MedGemma + Drug Calculator for clinical decision support."""

    def __init__(self, medgemma, rag: RAGEngine):
        self.medgemma = medgemma
        self.rag = rag
        self.drug_calculator = DrugCalculator()

    async def process_query(
        self,
        message: str,
        patient_context: Optional[Dict[str, Any]] = None,
        genui_mode: bool = True,
    ) -> dict:
        """Process a clinical query through the full pipeline.

        Pipeline:
        1. Check if query is a drug dose question -> use deterministic calculator
        2. Retrieve relevant protocols from RAG
        3. Augment prompt with RAG context and patient data
        4. Generate response with MedGemma
        5. Return structured GenUI response

        Args:
            message: The paramedic's question or clinical scenario.
            patient_context: Optional patient data (age, weight, vitals, etc.).
            genui_mode: Whether to return GenUI widget format.

        Returns:
            Dict with 'text', 'widgets', and 'rag_sources' keys.
        """
        # Step 1: Check for drug dose queries and handle deterministically
        drug_result = self._check_drug_query(message, patient_context)
        if drug_result is not None:
            return drug_result

        # Step 2: Retrieve relevant protocol context via RAG
        rag_context = await self.rag.retrieve(query=message)
        rag_sources = []
        if rag_context:
            # Extract source titles from context
            import re
            titles = re.findall(r"\[([^\]]+)\]", rag_context)
            rag_sources = titles[:5]

        # Step 3: Build augmented prompt with patient context
        augmented_message = message
        if patient_context:
            context_str = self._format_patient_context(patient_context)
            augmented_message = f"Patient Information:\n{context_str}\n\nQuestion: {message}"

        # Step 4: Generate response with MedGemma
        response = await self.medgemma.generate(
            user_message=augmented_message,
            context=rag_context,
            genui_mode=genui_mode,
        )

        # Step 5: Add RAG sources to response
        response["rag_sources"] = rag_sources

        return response

    async def process_stream(
        self,
        message: str,
        patient_context: Optional[Dict[str, Any]] = None,
    ):
        """Stream a clinical query response.

        Args:
            message: The paramedic's question.
            patient_context: Optional patient data.

        Yields:
            String tokens as they are generated.
        """
        # Retrieve RAG context
        rag_context = await self.rag.retrieve(query=message)

        # Build augmented message
        augmented_message = message
        if patient_context:
            context_str = self._format_patient_context(patient_context)
            augmented_message = f"Patient Information:\n{context_str}\n\nQuestion: {message}"

        # Stream from MedGemma
        async for token in self.medgemma.generate_stream(
            user_message=augmented_message,
            context=rag_context,
        ):
            yield token

    def _check_drug_query(self, message: str, patient_context: Optional[Dict[str, Any]]) -> Optional[dict]:
        """Check if the message is a drug dose query and calculate deterministically.

        Returns None if not a drug query, otherwise returns the calculated result.
        """
        msg_lower = message.lower()

        # Check if any known drug is mentioned
        available_drugs = self.drug_calculator.get_available_drugs()
        matched_drug = None
        for drug in available_drugs:
            # Check both the key and common variations
            drug_variants = [drug, drug.replace("_", " "), drug.replace("_", "")]
            for variant in drug_variants:
                if variant in msg_lower:
                    matched_drug = drug
                    break
            if matched_drug:
                break

        if matched_drug is None:
            return None

        # Check if this is actually asking about dosing
        dose_keywords = [
            "doz", "dose", "mg", "dozaj", "hesapla", "calculate",
            "kac", "how much", "ne kadar", "uygula", "ver",
        ]
        is_dose_query = any(kw in msg_lower for kw in dose_keywords)
        if not is_dose_query:
            return None

        # Extract patient parameters
        weight_kg = 70.0  # default adult weight
        age_years = None
        is_pediatric = False
        is_pregnant = False
        indication = None

        if patient_context:
            weight_kg = patient_context.get("weight_kg", weight_kg)
            age_years = patient_context.get("age_years", age_years)
            is_pediatric = patient_context.get("is_pediatric", False)
            is_pregnant = patient_context.get("is_pregnant", False)
            indication = patient_context.get("indication")

        # Try to extract weight from message
        import re
        weight_match = re.search(r"(\d+(?:\.\d+)?)\s*(?:kg|kilo)", msg_lower)
        if weight_match:
            weight_kg = float(weight_match.group(1))

        age_match = re.search(r"(\d+(?:\.\d+)?)\s*(?:yas|year|yo|y\.o\.)", msg_lower)
        if age_match:
            age_years = float(age_match.group(1))

        # Detect pediatric keywords
        pediatric_keywords = ["cocuk", "child", "pediatr", "bebek", "infant", "neonatal"]
        if any(kw in msg_lower for kw in pediatric_keywords):
            is_pediatric = True
            if weight_kg == 70.0:
                weight_kg = 20.0  # Default pediatric weight if not specified

        # Detect pregnancy keywords
        pregnancy_keywords = ["gebe", "hamile", "pregnant", "gebelik"]
        if any(kw in msg_lower for kw in pregnancy_keywords):
            is_pregnant = True

        # Try to detect indication from message
        if indication is None:
            indications = self.drug_calculator.get_drug_indications(matched_drug)
            for ind in indications:
                ind_variants = [ind, ind.replace("_", " ")]
                for variant in ind_variants:
                    if variant in msg_lower:
                        indication = ind
                        break
                if indication:
                    break

        # Calculate dose
        result = self.drug_calculator.calculate(
            drug_name=matched_drug,
            weight_kg=weight_kg,
            indication=indication,
            is_pediatric=is_pediatric,
            age_years=age_years,
            is_pregnant=is_pregnant,
        )

        # Format as standard response
        return {
            "text": f"{result.get('drug_name', matched_drug)} - {result.get('indication', 'general')}: {result.get('calculated_dose', '')}",
            "widgets": [result["widget"]],
            "rag_sources": [],
        }

    def _format_patient_context(self, patient_context: Dict[str, Any]) -> str:
        """Format patient context dict into a readable string for prompt augmentation."""
        parts = []
        field_labels = {
            "age_years": "Age",
            "weight_kg": "Weight (kg)",
            "gender": "Gender",
            "chief_complaint": "Chief Complaint",
            "vitals": "Vital Signs",
            "allergies": "Allergies",
            "medications": "Medications",
            "history": "Medical History",
            "injuries": "Injuries",
            "gcs": "GCS",
            "is_pregnant": "Pregnant",
            "is_pediatric": "Pediatric",
        }

        for key, label in field_labels.items():
            value = patient_context.get(key)
            if value is not None:
                if isinstance(value, dict):
                    vitals_str = ", ".join(f"{k}: {v}" for k, v in value.items())
                    parts.append(f"- {label}: {vitals_str}")
                elif isinstance(value, list):
                    parts.append(f"- {label}: {', '.join(str(v) for v in value)}")
                elif isinstance(value, bool):
                    parts.append(f"- {label}: {'Yes' if value else 'No'}")
                else:
                    parts.append(f"- {label}: {value}")

        return "\n".join(parts) if parts else "No patient context provided."
