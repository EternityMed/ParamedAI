"""Deterministic drug dose calculator for emergency medicine.

CRITICAL: Drug doses are NEVER calculated by LLM. This module uses
hard-coded, evidence-based dosing from ERC/ILCOR/AHA guidelines.
"""
from typing import Any, Dict, List, Optional


# ─── Emergency Drug Database ────────────────────────────────────────────────
# Each drug has indication-specific dosing for adult and pediatric patients.

EMERGENCY_DRUGS: Dict[str, Dict[str, Any]] = {
    "adrenalin": {
        "generic_name": "Epinephrine (Adrenaline)",
        "indications": {
            "anaphylaxis": {
                "adult": {
                    "dose": "0.5 mg IM",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 0.5,
                    "route": "IM (anterolateral thigh)",
                    "concentration": "1:1000 (1 mg/mL)",
                    "frequency": "Every 5 minutes if no improvement",
                    "max_dose": "No max (repeat every 5 min as needed)",
                    "volume": "0.5 mL of 1:1000",
                    "warning": "IM only in prehospital. IV only by experienced physicians.",
                },
                "pediatric": {
                    "dose": "0.01 mg/kg IM",
                    "dose_per_kg": 0.01,
                    "route": "IM (anterolateral thigh)",
                    "concentration": "1:1000 (1 mg/mL)",
                    "frequency": "Every 5 minutes if no improvement",
                    "max_dose": "0.5 mg per dose",
                    "max_dose_mg": 0.5,
                    "warning": "Max 0.3 mg for <6 years, 0.5 mg for >6 years. IM only.",
                },
            },
            "cardiac_arrest": {
                "adult": {
                    "dose": "1 mg IV/IO",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 1.0,
                    "route": "IV/IO",
                    "concentration": "1:10,000 (0.1 mg/mL)",
                    "frequency": "Every 3-5 minutes",
                    "max_dose": "No max during resuscitation",
                    "volume": "10 mL of 1:10,000",
                    "warning": "Shockable rhythm: give after 3rd shock. Non-shockable: give immediately.",
                },
                "pediatric": {
                    "dose": "0.01 mg/kg IV/IO",
                    "dose_per_kg": 0.01,
                    "route": "IV/IO",
                    "concentration": "1:10,000 (0.1 mg/mL)",
                    "frequency": "Every 3-5 minutes",
                    "max_dose": "1 mg per dose",
                    "max_dose_mg": 1.0,
                    "warning": "0.1 mL/kg of 1:10,000 solution. Use 1:10,000 for IV, never 1:1000 IV in children.",
                },
            },
        },
    },
    "amiodaron": {
        "generic_name": "Amiodarone",
        "indications": {
            "vf_vt": {
                "adult": {
                    "dose": "300 mg IV bolus (first dose), 150 mg IV (second dose)",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 300,
                    "route": "IV/IO bolus",
                    "concentration": "50 mg/mL",
                    "frequency": "First dose after 3rd shock, second dose after 5th shock",
                    "max_dose": "450 mg total during arrest",
                    "volume": "6 mL (300 mg) diluted in 20 mL D5W",
                    "warning": "Give after 3rd defibrillation. Can cause hypotension.",
                },
                "pediatric": {
                    "dose": "5 mg/kg IV/IO",
                    "dose_per_kg": 5.0,
                    "route": "IV/IO",
                    "concentration": "50 mg/mL",
                    "frequency": "After 3rd shock, can repeat twice to max 15 mg/kg",
                    "max_dose": "300 mg per dose",
                    "max_dose_mg": 300,
                    "warning": "Max 15 mg/kg total. Dilute in D5W.",
                },
            },
        },
    },
    "midazolam": {
        "generic_name": "Midazolam",
        "indications": {
            "seizure": {
                "adult": {
                    "dose": "10 mg IM/buccal or 5 mg IV",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 10,
                    "route": "IM/Buccal (preferred prehospital) or IV",
                    "concentration": "5 mg/mL",
                    "frequency": "Can repeat ONCE after 10 minutes",
                    "max_dose": "20 mg total",
                    "volume": "2 mL IM or 1 mL IV",
                    "warning": "Monitor respiratory depression. Have bag-valve-mask ready.",
                },
                "pediatric": {
                    "dose": "0.3 mg/kg buccal or 0.1 mg/kg IV",
                    "dose_per_kg": 0.3,
                    "route": "Buccal (preferred) or IV",
                    "concentration": "5 mg/mL",
                    "frequency": "Can repeat ONCE after 10 minutes",
                    "max_dose": "10 mg per dose",
                    "max_dose_mg": 10,
                    "warning": "Buccal route preferred in prehospital. Monitor airway closely.",
                },
            },
        },
    },
    "atropine": {
        "generic_name": "Atropine Sulfate",
        "indications": {
            "bradycardia": {
                "adult": {
                    "dose": "0.5 mg IV",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 0.5,
                    "route": "IV",
                    "concentration": "0.5 mg/mL or 1 mg/mL",
                    "frequency": "Every 3-5 minutes",
                    "max_dose": "3 mg total",
                    "volume": "1 mL of 0.5 mg/mL",
                    "warning": "Do not give less than 0.5 mg (may cause paradoxical bradycardia).",
                },
                "pediatric": {
                    "dose": "0.02 mg/kg IV",
                    "dose_per_kg": 0.02,
                    "route": "IV/IO",
                    "concentration": "0.5 mg/mL",
                    "frequency": "May repeat once",
                    "max_dose": "0.5 mg per dose (child), 1 mg (adolescent)",
                    "max_dose_mg": 0.5,
                    "warning": "Minimum dose 0.1 mg. May cause paradoxical bradycardia if underdosed.",
                },
            },
        },
    },
    "morphine": {
        "generic_name": "Morphine Sulfate",
        "indications": {
            "pain": {
                "adult": {
                    "dose": "2-5 mg IV titrated",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 5,
                    "route": "IV (slow push over 5 min)",
                    "concentration": "10 mg/mL",
                    "frequency": "Every 5-15 minutes, titrate to pain relief",
                    "max_dose": "20 mg total prehospital",
                    "volume": "0.5 mL (5 mg) diluted",
                    "warning": "Monitor RR and SpO2. Have naloxone ready. Contraindicated in hypotension (SBP<90).",
                },
                "pediatric": {
                    "dose": "0.1 mg/kg IV",
                    "dose_per_kg": 0.1,
                    "route": "IV (slow push)",
                    "concentration": "10 mg/mL (dilute to 1 mg/mL for peds)",
                    "frequency": "Every 5-15 minutes",
                    "max_dose": "5 mg per dose",
                    "max_dose_mg": 5,
                    "warning": "Dilute to 1 mg/mL. Monitor respiratory depression closely. Have naloxone ready.",
                },
            },
        },
    },
    "salbutamol": {
        "generic_name": "Salbutamol (Albuterol)",
        "indications": {
            "asthma": {
                "adult": {
                    "dose": "5 mg nebulized",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 5,
                    "route": "Nebulized (with O2 6-8 L/min)",
                    "concentration": "5 mg/2.5 mL nebule",
                    "frequency": "Every 20 minutes, or continuous if severe",
                    "max_dose": "No max in acute severe asthma",
                    "volume": "2.5 mL nebule",
                    "warning": "Can cause tachycardia, tremor. Back-to-back nebs for severe asthma.",
                },
                "pediatric": {
                    "dose": "2.5 mg nebulized (<5y) or 5 mg nebulized (>5y)",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 2.5,
                    "route": "Nebulized",
                    "concentration": "2.5 mg/2.5 mL or 5 mg/2.5 mL nebule",
                    "frequency": "Every 20 minutes",
                    "max_dose": "No max in acute severe",
                    "warning": "Use 2.5 mg for <5 years, 5 mg for >5 years. Monitor HR.",
                },
            },
        },
    },
    "sodium_bicarbonate": {
        "generic_name": "Sodium Bicarbonate",
        "indications": {
            "acidosis": {
                "adult": {
                    "dose": "50 mEq (50 mL of 8.4%) IV",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 50,
                    "route": "IV slow push",
                    "concentration": "8.4% (1 mEq/mL)",
                    "frequency": "Repeat based on ABG/clinical status",
                    "max_dose": "Guided by ABG",
                    "volume": "50 mL of 8.4%",
                    "warning": "Do not mix with calcium. Ensure adequate ventilation first.",
                },
                "pediatric": {
                    "dose": "1 mEq/kg IV",
                    "dose_per_kg": 1.0,
                    "route": "IV slow push",
                    "concentration": "4.2% for neonates (0.5 mEq/mL), 8.4% for children",
                    "frequency": "Repeat based on clinical status",
                    "max_dose": "50 mEq per dose",
                    "max_dose_mg": 50,
                    "warning": "Use 4.2% solution for neonates. Do not mix with calcium.",
                },
            },
            "crush_syndrome": {
                "adult": {
                    "dose": "50 mEq in first liter NS",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 50,
                    "route": "IV (mixed in NS)",
                    "concentration": "8.4% (1 mEq/mL)",
                    "frequency": "With each liter of fluid until urine pH > 6.5",
                    "max_dose": "Guided by urine pH",
                    "volume": "50 mL added to 1L NS",
                    "warning": "Start BEFORE extrication. Target urine pH > 6.5. Monitor for alkalosis.",
                },
                "pediatric": {
                    "dose": "1 mEq/kg in NS",
                    "dose_per_kg": 1.0,
                    "route": "IV (mixed in NS)",
                    "concentration": "4.2% or 8.4%",
                    "frequency": "With fluid resuscitation",
                    "max_dose": "50 mEq per dose",
                    "max_dose_mg": 50,
                    "warning": "Start before extrication. Use 4.2% for young children.",
                },
            },
        },
    },
    "calcium_gluconate": {
        "generic_name": "Calcium Gluconate 10%",
        "indications": {
            "hyperkalemia": {
                "adult": {
                    "dose": "10 mL of 10% IV over 10 min",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 1000,
                    "route": "IV slow push (over 10 minutes)",
                    "concentration": "10% (100 mg/mL)",
                    "frequency": "May repeat in 5-10 minutes if ECG changes persist",
                    "max_dose": "30 mL (3g) total",
                    "volume": "10 mL",
                    "warning": "Cardioprotective, does NOT lower potassium. Monitor ECG. Do not mix with bicarbonate.",
                },
                "pediatric": {
                    "dose": "0.5 mL/kg of 10% IV over 10 min",
                    "dose_per_kg": 50,
                    "route": "IV slow push (over 10 minutes)",
                    "concentration": "10% (100 mg/mL)",
                    "frequency": "May repeat once",
                    "max_dose": "10 mL (1g) per dose",
                    "max_dose_mg": 1000,
                    "warning": "Give slowly. Monitor for bradycardia. Do not mix with bicarbonate.",
                },
            },
            "crush_syndrome": {
                "adult": {
                    "dose": "10 mL of 10% IV over 10 min",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 1000,
                    "route": "IV slow push",
                    "concentration": "10% (100 mg/mL)",
                    "frequency": "Repeat if peaked T waves on ECG",
                    "max_dose": "30 mL (3g)",
                    "volume": "10 mL",
                    "warning": "Give BEFORE extrication for cardioprotection. Monitor ECG for peaked T waves.",
                },
                "pediatric": {
                    "dose": "0.5 mL/kg of 10% IV",
                    "dose_per_kg": 50,
                    "route": "IV slow push",
                    "concentration": "10%",
                    "frequency": "Repeat if ECG changes",
                    "max_dose": "10 mL per dose",
                    "max_dose_mg": 1000,
                    "warning": "Give before extrication. Monitor ECG.",
                },
            },
        },
    },
    "aspirin": {
        "generic_name": "Acetylsalicylic Acid (Aspirin)",
        "indications": {
            "acs": {
                "adult": {
                    "dose": "300 mg PO (chew)",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 300,
                    "route": "PO (chew and swallow)",
                    "concentration": "300 mg tablet",
                    "frequency": "Single dose",
                    "max_dose": "300 mg",
                    "volume": "1 tablet",
                    "warning": "Chew for faster absorption. Contraindicated if aspirin allergy or active GI bleeding.",
                },
                "pediatric": {
                    "dose": "Not typically used in pediatric ACS prehospital",
                    "dose_per_kg": None,
                    "route": "N/A",
                    "concentration": "N/A",
                    "frequency": "N/A",
                    "max_dose": "N/A",
                    "warning": "NOT recommended for pediatric patients (Reye syndrome risk). Consult medical control.",
                },
            },
        },
    },
    "nitroglycerin": {
        "generic_name": "Nitroglycerin (GTN)",
        "indications": {
            "chest_pain": {
                "adult": {
                    "dose": "0.4 mg SL",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 0.4,
                    "route": "Sublingual spray or tablet",
                    "concentration": "0.4 mg/dose spray",
                    "frequency": "Every 5 minutes, up to 3 doses",
                    "max_dose": "1.2 mg (3 doses)",
                    "volume": "1 spray or 1 tablet",
                    "warning": "Contraindicated if SBP < 90, RV infarct, or phosphodiesterase inhibitors (sildenafil) in last 24-48h.",
                },
                "pediatric": {
                    "dose": "Not typically used in pediatric prehospital",
                    "dose_per_kg": None,
                    "route": "N/A",
                    "concentration": "N/A",
                    "frequency": "N/A",
                    "max_dose": "N/A",
                    "warning": "NOT routinely used in pediatric prehospital. Consult medical control.",
                },
            },
        },
    },
    "magnesium_sulfate": {
        "generic_name": "Magnesium Sulfate",
        "indications": {
            "eclampsia": {
                "adult": {
                    "dose": "4 g IV loading over 15-20 min, then 1 g/hour infusion",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 4000,
                    "route": "IV infusion",
                    "concentration": "50% (500 mg/mL) diluted in 100 mL NS",
                    "frequency": "Loading dose, then continuous infusion",
                    "max_dose": "Loading: 4g. Maintenance: 1g/hr",
                    "volume": "8 mL of 50% in 100 mL NS",
                    "warning": "Monitor RR (stop if <12), DTR, urine output. Antidote: Calcium gluconate 1g IV.",
                },
                "pediatric": {
                    "dose": "25-50 mg/kg IV over 20 min",
                    "dose_per_kg": 50,
                    "route": "IV infusion",
                    "concentration": "50% diluted",
                    "frequency": "Single dose, may repeat once",
                    "max_dose": "2 g per dose",
                    "max_dose_mg": 2000,
                    "warning": "Monitor respiratory rate and reflexes.",
                },
            },
            "torsades": {
                "adult": {
                    "dose": "2 g IV over 10 min",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 2000,
                    "route": "IV",
                    "concentration": "50% (500 mg/mL) diluted",
                    "frequency": "Single dose, may repeat once",
                    "max_dose": "4 g total",
                    "volume": "4 mL of 50% in 100 mL NS",
                    "warning": "For Torsades de Pointes specifically. Monitor BP during infusion.",
                },
                "pediatric": {
                    "dose": "25-50 mg/kg IV over 10-20 min",
                    "dose_per_kg": 50,
                    "route": "IV",
                    "concentration": "50% diluted",
                    "frequency": "Single dose",
                    "max_dose": "2 g per dose",
                    "max_dose_mg": 2000,
                    "warning": "Monitor for hypotension and respiratory depression.",
                },
            },
        },
    },
    "ketamine": {
        "generic_name": "Ketamine",
        "indications": {
            "sedation": {
                "adult": {
                    "dose": "1-2 mg/kg IV or 4 mg/kg IM",
                    "dose_per_kg": 1.5,
                    "route": "IV (slow push) or IM",
                    "concentration": "50 mg/mL or 100 mg/mL",
                    "frequency": "May repeat 0.5-1 mg/kg IV every 10-15 min",
                    "max_dose": "4.5 mg/kg total IV",
                    "warning": "Dissociative agent. Maintain airway reflexes. May cause emergence reactions. Avoid in head injury with raised ICP.",
                },
                "pediatric": {
                    "dose": "1-2 mg/kg IV or 3-4 mg/kg IM",
                    "dose_per_kg": 1.5,
                    "route": "IV or IM",
                    "concentration": "50 mg/mL",
                    "frequency": "May repeat 0.5 mg/kg every 10 min",
                    "max_dose": "Based on weight",
                    "warning": "Excellent safety profile in children. Have suction ready.",
                },
            },
        },
    },
    "ondansetron": {
        "generic_name": "Ondansetron (Zofran)",
        "indications": {
            "nausea": {
                "adult": {
                    "dose": "4 mg IV or 4 mg ODT (oral dissolving tablet)",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 4,
                    "route": "IV (slow push over 2 min) or ODT",
                    "concentration": "2 mg/mL",
                    "frequency": "Every 4-6 hours",
                    "max_dose": "16 mg/day",
                    "volume": "2 mL IV",
                    "warning": "May prolong QT interval. Use caution with other QT-prolonging drugs.",
                },
                "pediatric": {
                    "dose": "0.1 mg/kg IV (max 4 mg) or 4 mg ODT (>4y)",
                    "dose_per_kg": 0.1,
                    "route": "IV or ODT",
                    "concentration": "2 mg/mL",
                    "frequency": "Every 4-6 hours",
                    "max_dose": "4 mg per dose",
                    "max_dose_mg": 4,
                    "warning": "Not recommended under 6 months. Check QTc if available.",
                },
            },
        },
    },
    "dexamethasone": {
        "generic_name": "Dexamethasone",
        "indications": {
            "croup": {
                "adult": {
                    "dose": "N/A (croup is pediatric)",
                    "dose_per_kg": None,
                    "route": "N/A",
                    "concentration": "N/A",
                    "frequency": "N/A",
                    "max_dose": "N/A",
                    "warning": "Croup is a pediatric condition. See pediatric dosing.",
                },
                "pediatric": {
                    "dose": "0.6 mg/kg PO/IM",
                    "dose_per_kg": 0.6,
                    "route": "PO (preferred) or IM",
                    "concentration": "4 mg/mL",
                    "frequency": "Single dose",
                    "max_dose": "16 mg",
                    "max_dose_mg": 16,
                    "warning": "Single dose is usually sufficient. Works within 1-2 hours.",
                },
            },
            "inflammation": {
                "adult": {
                    "dose": "4-8 mg IV/IM",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 8,
                    "route": "IV or IM",
                    "concentration": "4 mg/mL",
                    "frequency": "Every 6-12 hours",
                    "max_dose": "24 mg/day",
                    "volume": "2 mL (8 mg)",
                    "warning": "Not first-line in anaphylaxis (use adrenaline). Adjunct therapy only.",
                },
                "pediatric": {
                    "dose": "0.15-0.6 mg/kg IV/IM/PO",
                    "dose_per_kg": 0.3,
                    "route": "IV/IM/PO",
                    "concentration": "4 mg/mL",
                    "frequency": "Every 6-12 hours",
                    "max_dose": "16 mg per dose",
                    "max_dose_mg": 16,
                    "warning": "Adjunct therapy. Not a substitute for adrenaline in anaphylaxis.",
                },
            },
        },
    },
    "furosemide": {
        "generic_name": "Furosemide (Lasix)",
        "indications": {
            "pulmonary_edema": {
                "adult": {
                    "dose": "40-80 mg IV",
                    "dose_per_kg": None,
                    "fixed_dose_mg": 40,
                    "route": "IV (slow push over 2 min)",
                    "concentration": "10 mg/mL",
                    "frequency": "May repeat in 1-2 hours",
                    "max_dose": "200 mg single dose",
                    "volume": "4 mL (40 mg)",
                    "warning": "Monitor BP (may cause hypotension). Monitor potassium. Ensure urinary catheter for large doses.",
                },
                "pediatric": {
                    "dose": "1 mg/kg IV",
                    "dose_per_kg": 1.0,
                    "route": "IV (slow push)",
                    "concentration": "10 mg/mL",
                    "frequency": "Every 6-8 hours",
                    "max_dose": "6 mg/kg/day",
                    "warning": "Monitor electrolytes and BP. May cause ototoxicity at high doses.",
                },
            },
        },
    },
}


class DrugCalculator:
    """Deterministic drug dose calculator for emergency medicine.

    All calculations are based on hard-coded evidence-based dosing.
    NEVER uses LLM for dose calculation.
    """

    @staticmethod
    def get_available_drugs() -> List[str]:
        """Return list of available drug names."""
        return list(EMERGENCY_DRUGS.keys())

    @staticmethod
    def get_drug_indications(drug_name: str) -> List[str]:
        """Return list of indications for a drug."""
        drug = EMERGENCY_DRUGS.get(drug_name.lower())
        if drug is None:
            return []
        return list(drug["indications"].keys())

    @staticmethod
    def calculate(
        drug_name: str,
        weight_kg: float,
        indication: str = None,
        is_pediatric: bool = False,
        age_years: float = None,
        is_pregnant: bool = False,
    ) -> dict:
        """Calculate drug dose based on patient parameters.

        Args:
            drug_name: Drug name (lowercase).
            weight_kg: Patient weight in kg.
            indication: Clinical indication.
            is_pediatric: Whether patient is pediatric.
            age_years: Patient age in years (auto-detects pediatric if < 18).
            is_pregnant: Whether patient is pregnant.

        Returns:
            Dict with dose calculation results and GenUI widget data.
        """
        drug_key = drug_name.lower().replace(" ", "_").replace("-", "_")
        drug = EMERGENCY_DRUGS.get(drug_key)

        if drug is None:
            return {
                "error": f"Drug '{drug_name}' not found in database.",
                "available_drugs": list(EMERGENCY_DRUGS.keys()),
                "widget": {
                    "type": "WarningCard",
                    "data": {
                        "title": "Ilac Bulunamadi",
                        "message": f"'{drug_name}' veritabaninda bulunamadi. Mevcut ilaclar: {', '.join(EMERGENCY_DRUGS.keys())}",
                        "severity": "WARNING",
                        "action": "Ilac adini kontrol edin.",
                    },
                },
            }

        # Auto-detect pediatric from age
        if age_years is not None and age_years < 18:
            is_pediatric = True

        # Special handling for salbutamol pediatric dose by age
        if drug_key == "salbutamol" and is_pediatric and age_years is not None and age_years > 5:
            # Use 5mg for children > 5 years
            pass  # handled in calculation below

        # Determine indication
        indications = drug["indications"]
        if indication:
            indication_key = indication.lower().replace(" ", "_").replace("-", "_")
        else:
            # Use first available indication as default
            indication_key = list(indications.keys())[0]

        if indication_key not in indications:
            return {
                "error": f"Indication '{indication}' not found for {drug_name}.",
                "available_indications": list(indications.keys()),
                "widget": {
                    "type": "WarningCard",
                    "data": {
                        "title": "Endikasyon Bulunamadi",
                        "message": f"'{indication}' endikasyonu '{drug_name}' icin bulunamadi. Mevcut endikasyonlar: {', '.join(indications.keys())}",
                        "severity": "WARNING",
                        "action": "Endikasyonu kontrol edin.",
                    },
                },
            }

        dosing_group = "pediatric" if is_pediatric else "adult"
        dosing = indications[indication_key][dosing_group]

        # Calculate dose
        calculated_dose = _calculate_dose(dosing, weight_kg, drug_key, is_pediatric, age_years)

        # Pregnancy warnings
        pregnancy_warning = ""
        if is_pregnant:
            pregnancy_warning = _get_pregnancy_warning(drug_key)

        # Build warning string
        warning_parts = [dosing.get("warning", "")]
        if pregnancy_warning:
            warning_parts.append(f"GEBELIK: {pregnancy_warning}")
        full_warning = " ".join(filter(None, warning_parts))

        # Build result
        result = {
            "drug_name": drug["generic_name"],
            "indication": indication_key,
            "dose": dosing["dose"],
            "calculated_dose": calculated_dose,
            "route": dosing["route"],
            "concentration": dosing.get("concentration"),
            "frequency": dosing.get("frequency"),
            "max_dose": dosing.get("max_dose"),
            "warning": full_warning,
            "pediatric_note": f"Pediatrik doz ({weight_kg} kg)" if is_pediatric else None,
            "widget": {
                "type": "DrugDoseCard",
                "data": {
                    "drugName": drug["generic_name"],
                    "dose": dosing["dose"],
                    "calculatedDose": calculated_dose,
                    "route": dosing["route"],
                    "concentration": dosing.get("concentration", ""),
                    "frequency": dosing.get("frequency", ""),
                    "warning": full_warning,
                    "maxDose": dosing.get("max_dose", ""),
                },
            },
        }

        return result


def _calculate_dose(dosing: dict, weight_kg: float, drug_key: str, is_pediatric: bool, age_years: float = None) -> str:
    """Calculate the actual dose for a patient.

    Uses deterministic calculation: dose_per_kg * weight, capped at max_dose.
    Falls back to fixed_dose if dose_per_kg is not specified.
    """
    dose_per_kg = dosing.get("dose_per_kg")
    fixed_dose = dosing.get("fixed_dose_mg")
    max_dose_mg = dosing.get("max_dose_mg")

    # Special case: salbutamol pediatric dosing by age
    if drug_key == "salbutamol" and is_pediatric:
        if age_years is not None and age_years > 5:
            return "5 mg nebulize (>5 yas)"
        else:
            return "2.5 mg nebulize (<5 yas)"

    if dose_per_kg is not None:
        raw_dose = dose_per_kg * weight_kg
        unit = "mg"

        # Cap at max dose
        if max_dose_mg is not None and raw_dose > max_dose_mg:
            return f"{max_dose_mg} {unit} (max doz, hesaplanan: {raw_dose:.2f} {unit} [{dose_per_kg} {unit}/kg x {weight_kg} kg])"

        return f"{raw_dose:.2f} {unit} ({dose_per_kg} {unit}/kg x {weight_kg} kg)"

    elif fixed_dose is not None:
        unit = "mg"
        # Some fixed doses are in mEq
        if drug_key == "sodium_bicarbonate":
            unit = "mEq"
        return f"{fixed_dose} {unit} (sabit doz)"

    else:
        return dosing.get("dose", "Doz bilgisi mevcut degil")


def _get_pregnancy_warning(drug_key: str) -> str:
    """Get pregnancy-specific warnings for a drug."""
    pregnancy_warnings = {
        "adrenalin": "Gebelikte kullanilabilir (hayat kurtarici). Uterin kan akisini azaltabilir.",
        "amiodaron": "Gebelikte kontrendike (fetal tiroid disfonksiyonu). Yalnizca hayat tehdit edici aritmi icin.",
        "midazolam": "Gebelikte dikkatli kullanin. Ilk trimesterde teratojenik risk.",
        "atropine": "Gebelikte kullanilabilir. Fetal tasikardiyi izleyin.",
        "morphine": "Dikkatli kullanin. Yenidoganda solunum depresyonu riski. Doguma yakin donemde kacinmaya calisin.",
        "salbutamol": "Gebelikte guvenli. Tokoliz icin de kullanilir.",
        "sodium_bicarbonate": "Gebelikte gerektiginde kullanilabilir.",
        "calcium_gluconate": "Gebelikte guvenli. Eklampsi tedavisinde Mg toksisitesi antidotu.",
        "aspirin": "Gebelikte dikkat: 3. trimesterde kontrendike (duktus arteriosus erken kapanmasi).",
        "nitroglycerin": "Gebelikte dikkat: Hipotansiyon fetal perfuzyonu bozabilir.",
        "magnesium_sulfate": "Eklampsi tedavisinde ilk secenektir. Fetal kalp hizini izleyin.",
        "ketamine": "Gebelikte nispeten guvenli. Uterin tonusu artirir.",
        "ondansetron": "Gebelikte guvenli (ilk trimester sonrasi). Hiperemezis gravidarumda kullanilir.",
        "dexamethasone": "Fetal akcigar matUrasyonu icin kullanilabilir. Uzun sureli kullanim sakincali.",
        "furosemide": "Gebelikte dikkatli kullanin. Plasental perfuzyonu azaltabilir.",
    }
    return pregnancy_warnings.get(drug_key, "Gebelikte guvenlik bilgisi sinirlidir. Dikkatli kullanin.")
