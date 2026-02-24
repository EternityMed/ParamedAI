"""Drug calculator endpoint: /drug/calculate.

CRITICAL: Drug doses are calculated DETERMINISTICALLY.
This endpoint NEVER uses the LLM for dose calculations.
"""
from typing import List

from fastapi import APIRouter

from app.models.schemas import DrugCalcRequest, DrugCalcResponse, GenUIWidget
from app.services.drug_calculator import DrugCalculator

router = APIRouter()
calculator = DrugCalculator()


@router.post("/drug/calculate", response_model=DrugCalcResponse)
async def calculate_drug_dose(body: DrugCalcRequest):
    """Calculate drug dose using deterministic evidence-based dosing.

    This endpoint uses hard-coded dosing from ERC/ILCOR/AHA guidelines.
    Drug doses are NEVER calculated by the LLM to prevent hallucination.

    Supports 15 emergency drugs with adult and pediatric dosing:
    adrenalin, amiodaron, midazolam, atropine, morphine, salbutamol,
    sodium_bicarbonate, calcium_gluconate, aspirin, nitroglycerin,
    magnesium_sulfate, ketamine, ondansetron, dexamethasone, furosemide.

    Args:
        body: Drug calculation request with drug name, weight, and indication.

    Returns:
        Calculated dose with DrugDoseCard widget.
    """
    result = calculator.calculate(
        drug_name=body.drug_name,
        weight_kg=body.weight_kg,
        indication=body.indication,
        is_pediatric=body.is_pediatric,
        age_years=body.age_years,
        is_pregnant=body.is_pregnant,
    )

    # Handle error case (drug not found, indication not found)
    if "error" in result:
        return DrugCalcResponse(
            drug_name=body.drug_name,
            indication=body.indication or "unknown",
            dose="N/A",
            calculated_dose=result["error"],
            route="N/A",
            warning=result["error"],
            widget=GenUIWidget(**result["widget"]),
        )

    return DrugCalcResponse(
        drug_name=result["drug_name"],
        indication=result["indication"],
        dose=result["dose"],
        calculated_dose=result["calculated_dose"],
        route=result["route"],
        concentration=result.get("concentration"),
        frequency=result.get("frequency"),
        max_dose=result.get("max_dose"),
        warning=result.get("warning"),
        pediatric_note=result.get("pediatric_note"),
        widget=GenUIWidget(**result["widget"]),
    )


@router.get("/drug/list")
async def list_drugs() -> dict:
    """List all available drugs and their indications."""
    drugs = {}
    for drug_name in calculator.get_available_drugs():
        indications = calculator.get_drug_indications(drug_name)
        drugs[drug_name] = indications
    return {"drugs": drugs, "count": len(drugs)}
