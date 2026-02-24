"""RAG engine using ChromaDB for emergency medical protocol retrieval."""
import json
import os
from typing import List, Optional

import chromadb
from chromadb.config import Settings as ChromaSettings
from sentence_transformers import SentenceTransformer

from app.config import settings


class RAGEngine:
    """ChromaDB-based RAG engine for emergency medical protocols.

    Loads protocol JSON documents, creates embeddings, and retrieves
    relevant context for MedGemma prompt augmentation.
    """

    PROTOCOLS_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "protocols")

    def __init__(self, db_path: str, embedding_model: str = "all-MiniLM-L6-v2"):
        self.db_path = db_path
        self.embedding_model_name = embedding_model
        self.embedding_model: Optional[SentenceTransformer] = None
        self.client: Optional[chromadb.PersistentClient] = None
        self.collection = None

    async def initialize(self):
        """Initialize the embedding model and ChromaDB collection."""
        print(f"Initializing RAG engine with {self.embedding_model_name}...")

        # Load sentence transformer for embeddings
        self.embedding_model = SentenceTransformer(self.embedding_model_name)

        # Initialize ChromaDB persistent client
        os.makedirs(self.db_path, exist_ok=True)
        self.client = chromadb.PersistentClient(
            path=self.db_path,
            settings=ChromaSettings(anonymized_telemetry=False),
        )

        # Get or create the protocols collection
        self.collection = self.client.get_or_create_collection(
            name="ems_protocols",
            metadata={"hnsw:space": "cosine"},
        )

        # Load protocols if collection is empty
        if self.collection.count() == 0:
            await self._load_protocols()

        print(f"RAG engine ready. Collection has {self.collection.count()} documents.")

    async def _load_protocols(self):
        """Load protocol JSON files from the data directory into ChromaDB."""
        protocols_dir = os.path.normpath(self.PROTOCOLS_DIR)

        if not os.path.exists(protocols_dir):
            print(f"Protocols directory not found at {protocols_dir}. Loading built-in protocols.")
            await self._load_builtin_protocols()
            return

        documents = []
        metadatas = []
        ids = []

        for filename in os.listdir(protocols_dir):
            if not filename.endswith(".json"):
                continue

            filepath = os.path.join(protocols_dir, filename)
            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    protocol_data = json.load(f)

                # Handle both single protocol and list of protocols
                if isinstance(protocol_data, list):
                    protocols = protocol_data
                else:
                    protocols = [protocol_data]

                for i, protocol in enumerate(protocols):
                    doc_id = f"{filename}_{i}"
                    title = protocol.get("title", protocol.get("name", filename))
                    content = protocol.get("content", protocol.get("text", json.dumps(protocol)))
                    category = protocol.get("category", "general")

                    # Create a rich text representation for embedding
                    doc_text = f"{title}\n{content}"

                    documents.append(doc_text)
                    metadatas.append({
                        "source": filename,
                        "title": title,
                        "category": category,
                    })
                    ids.append(doc_id)

            except (json.JSONDecodeError, IOError) as e:
                print(f"Error loading protocol {filename}: {e}")
                continue

        if documents:
            # Generate embeddings and add to collection
            embeddings = self.embedding_model.encode(documents).tolist()
            self.collection.add(
                documents=documents,
                embeddings=embeddings,
                metadatas=metadatas,
                ids=ids,
            )
            print(f"Loaded {len(documents)} protocol documents into ChromaDB.")

    async def _load_builtin_protocols(self):
        """Load built-in emergency medical protocols when no JSON files exist."""
        builtin_protocols = [
            {
                "id": "cardiac_arrest_adult",
                "title": "Adult Cardiac Arrest (ALS Algorithm)",
                "category": "cardiac",
                "content": (
                    "Adult Cardiac Arrest ALS Algorithm (ERC 2021):\n"
                    "1. Confirm cardiac arrest: Unresponsive, not breathing normally, no pulse\n"
                    "2. Start CPR 30:2, attach defibrillator\n"
                    "3. Assess rhythm:\n"
                    "   - Shockable (VF/pVT): Defibrillate 150-200J biphasic -> CPR 2 min\n"
                    "   - Non-shockable (PEA/Asystole): CPR 2 min\n"
                    "4. After 3rd shock: Adrenaline 1mg IV + Amiodarone 300mg IV\n"
                    "5. Adrenaline 1mg IV every 3-5 min (non-shockable: give immediately)\n"
                    "6. After 5th shock: Amiodarone 150mg IV\n"
                    "7. Consider reversible causes (4H/4T):\n"
                    "   - Hypoxia, Hypovolemia, Hypo/Hyperkalemia, Hypothermia\n"
                    "   - Tension pneumothorax, Tamponade, Toxins, Thrombosis"
                ),
            },
            {
                "id": "anaphylaxis",
                "title": "Anaphylaxis Management Protocol",
                "category": "allergy",
                "content": (
                    "Anaphylaxis Management (ERC/ILCOR):\n"
                    "1. Remove allergen if possible\n"
                    "2. Call for help\n"
                    "3. Adrenaline IM (anterolateral thigh):\n"
                    "   - Adult: 0.5mg (0.5mL of 1:1000)\n"
                    "   - Child 6-12y: 0.3mg\n"
                    "   - Child <6y: 0.15mg\n"
                    "   - Repeat every 5 min if no improvement\n"
                    "4. Position: Supine with legs elevated (if breathing OK), sitting up if dyspnoeic\n"
                    "5. High-flow O2 15L/min\n"
                    "6. IV fluid bolus: 500-1000mL crystalloid (adult), 20mL/kg (child)\n"
                    "7. If bronchospasm: Salbutamol 5mg nebulized\n"
                    "8. Hydrocortisone IV: Adult 200mg, Child 100mg\n"
                    "9. Monitor: ECG, SpO2, BP every 5 min"
                ),
            },
            {
                "id": "stemi",
                "title": "STEMI / Acute Coronary Syndrome Protocol",
                "category": "cardiac",
                "content": (
                    "STEMI / ACS Prehospital Protocol:\n"
                    "1. 12-lead ECG within 10 min of contact\n"
                    "2. Aspirin 300mg PO (chew)\n"
                    "3. GTN 0.4mg SL (if SBP > 90, no phosphodiesterase inhibitors)\n"
                    "4. Morphine 2-5mg IV titrated for pain (with antiemetic)\n"
                    "5. O2 only if SpO2 < 94%\n"
                    "6. Obtain IV access\n"
                    "7. Activate cath lab (door-to-balloon < 90 min)\n"
                    "8. Continuous monitoring: ECG, SpO2, BP\n"
                    "9. Be prepared for cardiac arrest (VF most common)\n"
                    "STEMI criteria: ST elevation >= 1mm in 2+ contiguous leads\n"
                    "   or new LBBB with symptoms"
                ),
            },
            {
                "id": "trauma_primary_survey",
                "title": "Trauma Primary Survey (ABCDE)",
                "category": "trauma",
                "content": (
                    "Trauma Primary Survey (ATLS/PHTLS):\n"
                    "A - Airway with C-spine protection:\n"
                    "   - Jaw thrust (not head tilt), suction, OPA/NPA\n"
                    "   - Maintain inline stabilization\n"
                    "B - Breathing:\n"
                    "   - Expose chest, look/listen/feel\n"
                    "   - Tension pneumothorax: needle decompression 2nd ICS MCL\n"
                    "   - Open pneumothorax: 3-sided occlusive dressing\n"
                    "   - Flail chest: positive pressure ventilation\n"
                    "C - Circulation:\n"
                    "   - Control external hemorrhage (direct pressure, tourniquet)\n"
                    "   - 2x large bore IV, crystalloid 250mL boluses\n"
                    "   - Target SBP 80-90 (permissive hypotension in penetrating trauma)\n"
                    "   - Pelvic binder if suspected pelvic fracture\n"
                    "D - Disability:\n"
                    "   - GCS, pupils, blood glucose\n"
                    "   - AVPU: Alert, Voice, Pain, Unresponsive\n"
                    "E - Exposure/Environment:\n"
                    "   - Full exposure, log roll\n"
                    "   - Prevent hypothermia"
                ),
            },
            {
                "id": "pediatric_resuscitation",
                "title": "Pediatric Basic and Advanced Life Support",
                "category": "pediatric",
                "content": (
                    "Pediatric Resuscitation (ERC 2021):\n"
                    "BLS: 5 rescue breaths -> 15:2 CPR\n"
                    "Compression depth: 1/3 of chest AP diameter\n"
                    "Rate: 100-120/min\n"
                    "Drug doses (weight-based):\n"
                    "   - Adrenaline: 10 mcg/kg (0.1mL/kg of 1:10,000) IV/IO, every 3-5 min\n"
                    "   - Amiodarone: 5 mg/kg IV/IO (after 3rd shock)\n"
                    "   - Glucose: 2 mL/kg of 10% dextrose\n"
                    "   - Normal saline: 10 mL/kg bolus (repeat to max 40 mL/kg)\n"
                    "Defibrillation: 4 J/kg\n"
                    "Weight estimation: (age + 4) x 2 kg\n"
                    "ETT size: (age/4) + 4 uncuffed, (age/4) + 3.5 cuffed\n"
                    "Common arrest causes in children: Hypoxia (most common), Hypovolemia"
                ),
            },
            {
                "id": "seizure_management",
                "title": "Seizure / Status Epilepticus Protocol",
                "category": "neurology",
                "content": (
                    "Seizure / Status Epilepticus Protocol:\n"
                    "1. Protect patient, ensure airway, O2, check glucose\n"
                    "2. Time the seizure\n"
                    "3. If seizure > 5 min (status epilepticus):\n"
                    "   First line: Midazolam\n"
                    "   - Adult: 10mg IM/buccal or 5mg IV\n"
                    "   - Child: 0.3mg/kg buccal (max 10mg) or 0.1mg/kg IV\n"
                    "   Alternative: Diazepam 10mg IV adult, 0.3mg/kg IV child\n"
                    "4. If seizure continues after 10 min: repeat benzodiazepine ONCE\n"
                    "5. If refractory (>20 min): Phenytoin 20mg/kg IV or Levetiracetam 40mg/kg IV\n"
                    "6. Post-seizure: Recovery position, monitor, check glucose\n"
                    "7. Transport to hospital"
                ),
            },
            {
                "id": "crush_syndrome",
                "title": "Crush Injury / Crush Syndrome Protocol",
                "category": "trauma",
                "content": (
                    "Crush Injury / Crush Syndrome Protocol (Disaster Medicine):\n"
                    "CRITICAL: Start treatment BEFORE extrication!\n"
                    "1. Pre-extrication (while still trapped):\n"
                    "   - IV access: Normal saline 1-1.5 L/hour\n"
                    "   - Sodium bicarbonate: 50 mEq in first liter\n"
                    "   - Calcium gluconate 10%: 10 mL IV (cardioprotection)\n"
                    "   - Do NOT apply tourniquet unless active arterial bleeding\n"
                    "2. During extrication:\n"
                    "   - Continue aggressive IV fluids\n"
                    "   - Monitor ECG continuously (hyperkalemia risk)\n"
                    "   - Peaked T waves = give calcium gluconate immediately\n"
                    "3. Post-extrication:\n"
                    "   - Continue NS 500 mL/hour\n"
                    "   - Monitor urine output (target > 200 mL/hour)\n"
                    "   - If dark/cola-colored urine: increase fluids + bicarbonate\n"
                    "   - Watch for compartment syndrome\n"
                    "4. Complications: Hyperkalemia, rhabdomyolysis, renal failure, DIC\n"
                    "EARTHQUAKE SPECIFIC: Expect multiple crush patients. Pre-stage IV fluids."
                ),
            },
            {
                "id": "start_triage",
                "title": "START Triage Algorithm for Mass Casualty Incidents",
                "category": "triage",
                "content": (
                    "START (Simple Triage and Rapid Treatment):\n"
                    "Step 1: Can the patient walk?\n"
                    "   YES -> GREEN (Minor)\n"
                    "   NO -> Continue\n"
                    "Step 2: Is the patient breathing?\n"
                    "   NO -> Open airway -> Still not breathing -> BLACK (Deceased)\n"
                    "   YES -> Continue\n"
                    "Step 3: Respiratory rate?\n"
                    "   > 30/min -> RED (Immediate)\n"
                    "   < 30/min -> Continue\n"
                    "Step 4: Perfusion (radial pulse or cap refill)?\n"
                    "   No radial pulse OR cap refill > 2 sec -> RED (Immediate)\n"
                    "   Radial pulse present AND cap refill < 2 sec -> Continue\n"
                    "Step 5: Mental status?\n"
                    "   Cannot follow simple commands -> RED (Immediate)\n"
                    "   Follows commands -> YELLOW (Delayed)\n\n"
                    "JumpSTART (Pediatric < 8 years):\n"
                    "   Same flow but: RR < 15 or > 45 = RED\n"
                    "   Not breathing: give 5 rescue breaths, then reassess\n"
                    "   Use AVPU instead of 'follows commands'"
                ),
            },
            {
                "id": "asthma_acute",
                "title": "Acute Asthma / Bronchospasm Protocol",
                "category": "respiratory",
                "content": (
                    "Acute Asthma Prehospital Protocol:\n"
                    "Mild-Moderate:\n"
                    "   - Salbutamol 5mg nebulized (can repeat every 20 min)\n"
                    "   - O2 to target SpO2 94-98%\n"
                    "Severe (can't complete sentences, RR>25, HR>110):\n"
                    "   - Salbutamol 5mg nebulized back-to-back\n"
                    "   - Ipratropium 0.5mg nebulized\n"
                    "   - Prednisolone 40-50mg PO or Hydrocortisone 100mg IV\n"
                    "   - O2 high flow\n"
                    "Life-threatening (SpO2<92, silent chest, cyanosis, altered consciousness):\n"
                    "   - All of above PLUS\n"
                    "   - Magnesium sulfate 1.2-2g IV over 20 min\n"
                    "   - Consider adrenaline 0.5mg IM\n"
                    "   - Prepare for intubation\n"
                    "   - Ketamine 0.5-1 mg/kg IV for bronchodilation\n"
                    "Pediatric: Salbutamol 2.5mg neb (<5y), 5mg neb (>5y)"
                ),
            },
            {
                "id": "eclampsia",
                "title": "Pre-eclampsia / Eclampsia Protocol",
                "category": "obstetric",
                "content": (
                    "Pre-eclampsia / Eclampsia Prehospital Protocol:\n"
                    "Signs: BP > 140/90, headache, visual disturbances, epigastric pain, edema\n"
                    "Eclampsia = pre-eclampsia + seizures\n\n"
                    "Management:\n"
                    "1. ABCs, left lateral position\n"
                    "2. Magnesium Sulfate (drug of choice for eclamptic seizures):\n"
                    "   - Loading: 4g IV over 15-20 min\n"
                    "   - Maintenance: 1g/hour IV infusion\n"
                    "   - Monitor: Deep tendon reflexes, RR (stop if RR<12), urine output\n"
                    "   - Antidote: Calcium gluconate 1g IV if Mg toxicity\n"
                    "3. Antihypertensives if SBP > 160 or DBP > 110:\n"
                    "   - Labetalol 20mg IV or Hydralazine 5mg IV\n"
                    "4. O2 high flow\n"
                    "5. IV access, monitor fetal heart rate\n"
                    "6. Rapid transport to hospital with obstetric capability\n"
                    "7. Definitive treatment = delivery"
                ),
            },
        ]

        documents = []
        metadatas = []
        ids = []

        for protocol in builtin_protocols:
            doc_text = f"{protocol['title']}\n{protocol['content']}"
            documents.append(doc_text)
            metadatas.append({
                "source": "builtin",
                "title": protocol["title"],
                "category": protocol["category"],
            })
            ids.append(protocol["id"])

        if documents:
            embeddings = self.embedding_model.encode(documents).tolist()
            self.collection.add(
                documents=documents,
                embeddings=embeddings,
                metadatas=metadatas,
                ids=ids,
            )
            print(f"Loaded {len(documents)} built-in protocol documents.")

    async def retrieve(self, query: str, top_k: int = None, category: str = None) -> str:
        """Retrieve relevant protocol context for a query.

        Args:
            query: The user's question or clinical scenario.
            top_k: Number of documents to retrieve (defaults to settings.RAG_TOP_K).
            category: Optional category filter (cardiac, trauma, etc.).

        Returns:
            Concatenated relevant protocol text.
        """
        if self.collection is None or self.collection.count() == 0:
            return ""

        if top_k is None:
            top_k = settings.RAG_TOP_K

        # Generate query embedding
        query_embedding = self.embedding_model.encode([query]).tolist()

        # Build where filter if category specified
        where_filter = None
        if category:
            where_filter = {"category": category}

        results = self.collection.query(
            query_embeddings=query_embedding,
            n_results=min(top_k, self.collection.count()),
            where=where_filter,
        )

        if not results or not results["documents"] or not results["documents"][0]:
            return ""

        # Concatenate relevant documents with source attribution
        context_parts = []
        for i, doc in enumerate(results["documents"][0]):
            metadata = results["metadatas"][0][i] if results["metadatas"] else {}
            title = metadata.get("title", f"Protocol {i+1}")
            distance = results["distances"][0][i] if results["distances"] else 0
            relevance = max(0, 1 - distance)  # Convert distance to similarity

            if relevance > 0.3:  # Only include reasonably relevant results
                context_parts.append(f"[{title}] (relevance: {relevance:.2f})\n{doc}")

        return "\n\n---\n\n".join(context_parts)

    async def add_protocol(self, protocol_id: str, title: str, content: str, category: str = "general"):
        """Add a new protocol document to the collection.

        Args:
            protocol_id: Unique identifier for the protocol.
            title: Protocol title.
            content: Protocol content text.
            category: Protocol category.
        """
        doc_text = f"{title}\n{content}"
        embedding = self.embedding_model.encode([doc_text]).tolist()

        self.collection.add(
            documents=[doc_text],
            embeddings=embedding,
            metadatas=[{"source": "manual", "title": title, "category": category}],
            ids=[protocol_id],
        )

    def get_collection_stats(self) -> dict:
        """Get statistics about the protocol collection."""
        if self.collection is None:
            return {"count": 0, "status": "not_initialized"}
        return {
            "count": self.collection.count(),
            "status": "ready",
        }
