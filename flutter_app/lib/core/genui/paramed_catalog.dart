import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../../config/theme.dart';
import '../../widgets/drug_dose_card.dart';
import '../../widgets/triage_card.dart';
import '../../widgets/protocol_card.dart';
import '../../widgets/ecg_analysis_card.dart';
import '../../widgets/vital_signs_card.dart';
import '../../widgets/patient_form_card.dart';

import '../../widgets/warning_card.dart';

/// Safely build a widget, catching any errors and showing debug info.
Widget _safeBuilder(String name, CatalogItemContext context, Widget Function(Map<String, dynamic>) builder) {
  try {
    final data = context.data;
    if (data is Map<String, dynamic>) {
      return builder(data);
    }
    // Try converting if it's a different Map type
    if (data is Map) {
      return builder(Map<String, dynamic>.from(data));
    }
    return _errorWidget(name, 'Data type: ${data.runtimeType}');
  } catch (e, st) {
    return _errorWidget(name, '$e\n$st');
  }
}

Widget _errorWidget(String widgetName, String error) {
  return Card(
    color: ParamedTheme.card,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('[$widgetName Error]', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text(error, style: const TextStyle(color: Colors.white70, fontSize: 10), maxLines: 5, overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}

/// ParaMed AI custom widget catalog for GenUI.
/// Contains all 8 medical UI widgets that MedGemma can produce.
class ParamedCatalog {
  ParamedCatalog._();

  /// Returns the full Catalog with all medical widgets.
  static Catalog get catalog => Catalog(items, catalogId: 'com.paramed.medical');

  /// Returns all catalog items for registration with GenUI.
  static List<CatalogItem> get items => [
        _drugDoseCard,
        _triageCard,
        _protocolCard,
        _ecgAnalysisCard,
        _vitalSignsCard,
        _patientFormCard,

        _warningCard,
      ];

  // -- Drug Dose Card --
  static final CatalogItem _drugDoseCard = CatalogItem(
    name: 'DrugDoseCard',
    dataSchema: S.object(
      properties: {
        'drugName': S.string(description: 'Name of the drug'),
        'dose': S.string(description: 'Calculated dose'),
        'calculatedDose': S.string(description: 'Dose with units'),
        'route': S.string(description: 'Administration route (IV, IM, SC, PO, etc.)'),
        'concentration': S.string(description: 'Drug concentration info'),
        'frequency': S.string(description: 'Dosing frequency'),
        'warning': S.string(description: 'Safety warning'),
        'maxDose': S.string(description: 'Maximum allowed dose'),
      },
      required: ['drugName', 'dose', 'route'],
    ),
    widgetBuilder: (context) => _safeBuilder('DrugDoseCard', context, (data) => DrugDoseCardWidget(data: data)),
  );

  // -- Triage Card --
  static final CatalogItem _triageCard = CatalogItem(
    name: 'TriageCard',
    dataSchema: S.object(
      properties: {
        'patientId': S.string(description: 'Patient identifier'),
        'category': S.string(description: 'Triage category: RED, YELLOW, GREEN, BLACK'),
        'vitals': S.object(properties: {
          'hr': S.integer(),
          'rr': S.integer(),
          'spo2': S.integer(),
          'gcs': S.integer(),
        }),
        'injuries': S.list(items: S.string()),
        'action': S.string(description: 'Recommended next action'),
        'gcs': S.integer(description: 'Glasgow Coma Scale score'),
      },
      required: ['patientId', 'category'],
    ),
    widgetBuilder: (context) => _safeBuilder('TriageCard', context, (data) => TriageCardWidget(data: data)),
  );

  // -- Protocol Card --
  static final CatalogItem _protocolCard = CatalogItem(
    name: 'ProtocolCard',
    dataSchema: S.object(
      properties: {
        'protocolName': S.string(description: 'Name of the protocol'),
        'steps': S.list(items: S.string(), description: 'Ordered protocol steps'),
        'currentStep': S.integer(description: 'Current step index'),
        'urgency': S.string(description: 'Urgency: RED, YELLOW, GREEN'),
        'notes': S.string(description: 'Additional notes'),
      },
      required: ['protocolName', 'steps'],
    ),
    widgetBuilder: (context) => _safeBuilder('ProtocolCard', context, (data) => ProtocolCardWidget(data: data)),
  );

  // -- ECG Analysis Card --
  static final CatalogItem _ecgAnalysisCard = CatalogItem(
    name: 'ECGAnalysisCard',
    dataSchema: S.object(
      properties: {
        'rhythm': S.string(description: 'Detected rhythm type'),
        'rate': S.integer(description: 'Heart rate in bpm'),
        'interpretation': S.string(description: 'Clinical interpretation'),
        'stChanges': S.string(description: 'ST segment changes'),
        'urgentAction': S.string(description: 'Immediate action if needed'),
        'differentialDiagnosis': S.list(items: S.string()),
      },
      required: ['rhythm', 'rate', 'interpretation'],
    ),
    widgetBuilder: (context) => _safeBuilder('ECGAnalysisCard', context, (data) => ECGAnalysisCardWidget(data: data)),
  );

  // -- Vital Signs Card --
  static final CatalogItem _vitalSignsCard = CatalogItem(
    name: 'VitalSignsCard',
    dataSchema: S.object(
      properties: {
        'bp': S.string(description: 'Blood pressure'),
        'hr': S.string(description: 'Heart rate'),
        'rr': S.string(description: 'Respiratory rate'),
        'spo2': S.string(description: 'Oxygen saturation'),
        'temp': S.string(description: 'Temperature'),
        'gcs': S.string(description: 'Glasgow Coma Scale'),
        'pain': S.string(description: 'Pain score 0-10'),
        'trending': S.string(description: 'UP, DOWN, STABLE'),
      },
    ),
    widgetBuilder: (context) => _safeBuilder('VitalSignsCard', context, (data) => VitalSignsCardWidget(data: data)),
  );

  // -- Patient Form Card --
  static final CatalogItem _patientFormCard = CatalogItem(
    name: 'PatientFormCard',
    dataSchema: S.object(
      properties: {
        'age': S.integer(),
        'gender': S.string(description: 'Erkek / Kadin'),
        'chiefComplaint': S.string(description: 'Primary complaint'),
        'history': S.string(description: 'Medical history summary'),
        'vitals': S.object(properties: {}),
        'injuries': S.list(items: S.string()),
        'interventions': S.list(items: S.string()),
        'allergies': S.list(items: S.string()),
      },
      required: ['chiefComplaint'],
    ),
    widgetBuilder: (context) => _safeBuilder('PatientFormCard', context, (data) => PatientFormCardWidget(data: data)),
  );


  // -- Warning Card --
  static final CatalogItem _warningCard = CatalogItem(
    name: 'WarningCard',
    dataSchema: S.object(
      properties: {
        'title': S.string(),
        'message': S.string(),
        'severity': S.string(description: 'CRITICAL, WARNING, INFO'),
        'action': S.string(description: 'Recommended action'),
      },
      required: ['title', 'message', 'severity'],
    ),
    widgetBuilder: (context) => _safeBuilder('WarningCard', context, (data) => WarningCardWidget(data: data)),
  );
}
