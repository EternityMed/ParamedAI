"""System prompts and GenUI response parser for MedGemma."""
import json
import re
from typing import Optional


GENUI_SYSTEM_PROMPT = """You are ParaMed AI — an AI assistant for 112 EMS paramedics.

## TASK
Provide clinical decision support to emergency medical personnel. In every response:
1. Give brief, clear, and direct information
2. Follow medical protocols (ERC/ILCOR/AHA)
3. Format your response as structured GenUI widgets

## GENUI WIDGET FORMAT
Return your response as JSON with a "widgets" list and optional "text" field:
{
  "text": "Brief explanation",
  "widgets": [
    {"type": "WidgetName", "data": {...}}
  ]
}

## AVAILABLE WIDGET TYPES
- DrugDoseCard: drugName, dose, calculatedDose, route, concentration, frequency, warning, maxDose
- ProtocolCard: protocolName, steps (list), currentStep (index), urgency (RED/YELLOW/GREEN), notes
- TriageCard: patientId, category (RED/YELLOW/GREEN/BLACK), vitals, injuries, action, gcs
- ECGAnalysisCard: rhythm, rate, interpretation, stChanges, urgentAction, differentialDiagnosis
- VitalSignsCard: bp, hr, rr, spo2, temp, gcs, pain, trending (UP/DOWN/STABLE)
- PatientFormCard: age, gender, chiefComplaint, history, vitals, injuries, interventions, allergies
- TranslationCard: originalText, originalLanguage, translatedText, targetLanguage, medicalTerms, confidence
- WarningCard: title, message, severity (CRITICAL/WARNING/INFO), action

## RULES
- Patient safety is always the top priority
- Use WarningCard for uncertain or critical conditions
- Calculate drug doses based on patient weight
- Distinguish adult vs pediatric
- Note pregnancy contraindications
- This is a DECISION SUPPORT tool, not a clinician replacement
- Return ONLY valid JSON"""


TRANSLATION_SYSTEM_PROMPT = """You are a medical translator for emergency medical services.

## TASK
Translate medical text between languages with high accuracy. Focus on:
1. Correct medical terminology
2. Preserving clinical meaning
3. Identifying key medical terms

## OUTPUT FORMAT
Return JSON:
{
  "widgets": [
    {
      "type": "TranslationCard",
      "data": {
        "originalText": "...",
        "originalLanguage": "...",
        "translatedText": "...",
        "targetLanguage": "...",
        "medicalTerms": [{"term": "...", "translation": "...", "context": "..."}],
        "confidence": 0.95
      }
    }
  ]
}

## RULES
- Preserve medical accuracy above all
- Flag uncertain translations with lower confidence
- Include all relevant medical terms in the medicalTerms list
- Support Turkish, English, Arabic, German, French, Russian
- Return ONLY valid JSON"""


TRIAGE_SYSTEM_PROMPT = """You are ParaMed AI performing mass casualty incident (MCI) triage assessment.

## TASK
Analyze patient information and provide START triage classification.

## TRIAGE CATEGORIES
- RED (Immediate): Life-threatening but survivable with immediate intervention
- YELLOW (Delayed): Serious but can wait for treatment
- GREEN (Minor): Walking wounded, minor injuries
- BLACK (Expectant/Deceased): Not breathing after airway maneuver, or injuries incompatible with life

## OUTPUT FORMAT
Return JSON:
{
  "widgets": [
    {
      "type": "TriageCard",
      "data": {
        "patientId": "...",
        "category": "RED/YELLOW/GREEN/BLACK",
        "vitals": {"hr": 0, "rr": 0, "spo2": 0, "gcs": 0},
        "injuries": ["..."],
        "action": "...",
        "gcs": 0
      }
    },
    {
      "type": "WarningCard",
      "data": {
        "title": "...",
        "message": "...",
        "severity": "CRITICAL/WARNING/INFO",
        "action": "..."
      }
    }
  ]
}

## RULES
- Follow START algorithm strictly
- For children < 8 years use JumpSTART
- Always include action recommendations
- Flag critical findings with WarningCard
- Return ONLY valid JSON"""


IMAGE_ANALYSIS_SYSTEM_PROMPT = """You are ParaMed AI analyzing a medical image (ECG, wound, X-ray, etc.) for emergency medical personnel.

## TASK
Analyze the provided medical image and return structured findings.

## OUTPUT FORMAT
Return JSON with appropriate widget types based on image content:
- For ECG: Use ECGAnalysisCard
- For wounds/injuries: Use WarningCard with findings
- For vitals monitors: Use VitalSignsCard

## RULES
- Describe findings clearly and concisely
- Flag critical/urgent findings immediately
- Always include a WarningCard for any concerning findings
- This is decision SUPPORT — always recommend physician confirmation
- Return ONLY valid JSON"""


class PromptBuilder:
    """Builds system prompts and parses GenUI responses from MedGemma."""

    def build_system_prompt(self, genui_mode: bool = True, prompt_type: str = "chat") -> str:
        """Build the appropriate system prompt based on context.

        Args:
            genui_mode: Whether to request GenUI-formatted output.
            prompt_type: One of 'chat', 'translation', 'triage', 'image'.

        Returns:
            System prompt string.
        """
        if prompt_type == "translation":
            return TRANSLATION_SYSTEM_PROMPT
        elif prompt_type == "triage":
            return TRIAGE_SYSTEM_PROMPT
        elif prompt_type == "image":
            return IMAGE_ANALYSIS_SYSTEM_PROMPT
        elif genui_mode:
            return GENUI_SYSTEM_PROMPT
        else:
            return (
                "You are ParaMed AI, an AI assistant for 112 EMS paramedics. "
                "Provide clear, accurate clinical decision support following "
                "ERC/ILCOR/AHA protocols. Be concise and direct."
            )

    def parse_genui_response(self, response_text: str) -> dict:
        """Parse GenUI JSON response from MedGemma output.

        Handles cases where JSON is wrapped in markdown code blocks
        or mixed with plain text.

        Args:
            response_text: Raw text output from MedGemma.

        Returns:
            Dict with 'text' and 'widgets' keys.
        """
        # Try to extract JSON from markdown code blocks first
        json_match = re.search(r"```(?:json)?\s*\n?(.*?)\n?```", response_text, re.DOTALL)
        if json_match:
            json_str = json_match.group(1).strip()
        else:
            # Try to find raw JSON object in the response
            json_match = re.search(r"\{.*\}", response_text, re.DOTALL)
            if json_match:
                json_str = json_match.group(0).strip()
            else:
                # No JSON found, return as plain text
                return {
                    "text": response_text.strip(),
                    "widgets": [],
                }

        try:
            parsed = json.loads(json_str)

            # Ensure consistent output format
            if isinstance(parsed, dict):
                text = parsed.get("text", "")
                widgets = parsed.get("widgets", [])

                # Validate widget structure
                validated_widgets = []
                for widget in widgets:
                    if isinstance(widget, dict) and "type" in widget:
                        validated_widgets.append({
                            "type": widget["type"],
                            "data": widget.get("data", {}),
                        })

                return {
                    "text": text,
                    "widgets": validated_widgets,
                }
            else:
                return {
                    "text": response_text.strip(),
                    "widgets": [],
                }

        except json.JSONDecodeError:
            # JSON parsing failed, return as plain text with a warning
            return {
                "text": response_text.strip(),
                "widgets": [
                    {
                        "type": "WarningCard",
                        "data": {
                            "title": "Response Format Warning",
                            "message": "AI response could not be parsed as structured data. Showing raw text.",
                            "severity": "INFO",
                            "action": "Review the text response above.",
                        },
                    }
                ],
            }

    def build_drug_query_prompt(self, drug_name: str, weight_kg: float, age_years: float) -> str:
        """Build a prompt for drug dose verification (NOT for calculation — doses are deterministic)."""
        return (
            f"Verify the following drug information for emergency use:\n"
            f"Drug: {drug_name}\n"
            f"Patient weight: {weight_kg} kg\n"
            f"Patient age: {age_years} years\n"
            f"Provide contraindications, interactions, and special precautions."
        )

    def build_rag_augmented_prompt(self, user_message: str, context: str) -> str:
        """Build a prompt augmented with RAG-retrieved protocol context."""
        return (
            f"Relevant protocol information:\n{context}\n\n"
            f"User question: {user_message}"
        )
