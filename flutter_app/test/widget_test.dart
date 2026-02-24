import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:paramed_ai/widgets/drug_dose_card.dart';
import 'package:paramed_ai/widgets/triage_card.dart';
import 'package:paramed_ai/widgets/warning_card.dart';
import 'package:paramed_ai/widgets/protocol_card.dart';
import 'package:paramed_ai/widgets/vital_signs_card.dart';
import 'package:paramed_ai/config/theme.dart';

/// Helper to wrap widget in MaterialApp for testing.
Widget testableWidget(Widget child) {
  return MaterialApp(
    theme: ParamedTheme.lightTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: child,
      ),
    ),
  );
}

// ─── DrugDoseCard Tests ─────────────────────────────────────────────────

void main() {
  group('DrugDoseCardWidget', () {
    testWidgets('renders drug name and dose', (tester) async {
      await tester.pumpWidget(testableWidget(
        DrugDoseCardWidget(data: const {
          'drugName': 'Epinephrine (Adrenaline)',
          'dose': '0.5 mg',
          'calculatedDose': '0.50 mg (sabit doz)',
          'route': 'IM',
          'concentration': '1:1000 (1 mg/mL)',
          'frequency': 'Every 5 minutes',
          'warning': 'IM only in prehospital.',
        }),
      ));

      expect(find.text('Epinephrine (Adrenaline)'), findsOneWidget);
      expect(find.textContaining('IM'), findsWidgets);
      expect(find.byIcon(Icons.medication), findsOneWidget);
    });

    testWidgets('shows warning when provided', (tester) async {
      await tester.pumpWidget(testableWidget(
        DrugDoseCardWidget(data: const {
          'drugName': 'Test Drug',
          'dose': '10 mg',
          'route': 'IV',
          'warning': 'Monitor respiratory depression.',
        }),
      ));

      expect(find.text('Monitor respiratory depression.'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    });

    testWidgets('shows max dose indicator', (tester) async {
      await tester.pumpWidget(testableWidget(
        DrugDoseCardWidget(data: const {
          'drugName': 'Adrenaline',
          'dose': '0.01 mg/kg',
          'route': 'IM',
          'maxDose': '0.5',
        }),
      ));

      expect(find.textContaining('Maksimum doz'), findsOneWidget);
      expect(find.byIcon(Icons.speed), findsOneWidget);
    });

    testWidgets('handles camelCase and snake_case keys', (tester) async {
      await tester.pumpWidget(testableWidget(
        DrugDoseCardWidget(data: const {
          'drug_name': 'Morphine',
          'dose': '5 mg',
          'route': 'IV',
        }),
      ));

      expect(find.text('Morphine'), findsOneWidget);
    });

    testWidgets('shows default name when missing', (tester) async {
      await tester.pumpWidget(testableWidget(
        DrugDoseCardWidget(data: const {
          'dose': '5 mg',
          'route': 'IV',
        }),
      ));

      expect(find.textContaining('Bilinmeyen'), findsOneWidget);
    });

    testWidgets('displays concentration info', (tester) async {
      await tester.pumpWidget(testableWidget(
        DrugDoseCardWidget(data: const {
          'drugName': 'Amiodarone',
          'dose': '300 mg',
          'route': 'IV',
          'concentration': '50 mg/mL',
        }),
      ));

      expect(find.textContaining('Konsantrasyon'), findsOneWidget);
      expect(find.textContaining('50 mg/mL'), findsOneWidget);
    });

    testWidgets('displays indication', (tester) async {
      await tester.pumpWidget(testableWidget(
        DrugDoseCardWidget(data: const {
          'drugName': 'Adrenaline',
          'dose': '0.5 mg',
          'route': 'IM',
          'indication': 'anaphylaxis',
        }),
      ));

      expect(find.textContaining('Endikasyon'), findsOneWidget);
    });

    testWidgets('handles list of warnings', (tester) async {
      await tester.pumpWidget(testableWidget(
        DrugDoseCardWidget(data: const {
          'drugName': 'Test Drug',
          'dose': '10 mg',
          'route': 'IV',
          'warnings': ['Warning 1', 'Warning 2'],
        }),
      ));

      expect(find.text('Warning 1'), findsOneWidget);
      expect(find.text('Warning 2'), findsOneWidget);
    });
  });

  // ─── TriageCard Tests ─────────────────────────────────────────────────

  group('TriageCardWidget', () {
    testWidgets('renders GREEN triage category', (tester) async {
      await tester.pumpWidget(testableWidget(
        TriageCardWidget(data: const {
          'patientId': 'PT-001',
          'category': 'GREEN',
          'action': 'Delayed treatment area',
        }),
      ));

      expect(find.textContaining('PT-001'), findsOneWidget);
      expect(find.textContaining('Delayed treatment area'), findsOneWidget);
    });

    testWidgets('renders RED triage with vitals', (tester) async {
      await tester.pumpWidget(testableWidget(
        TriageCardWidget(data: const {
          'patientId': 'PT-002',
          'category': 'RED',
          'vitals': {'hr': 120, 'spo2': 88, 'bp': '80/50'},
          'action': 'Immediate treatment area',
        }),
      ));

      expect(find.textContaining('PT-002'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('88'), findsOneWidget);
    });

    testWidgets('renders YELLOW triage', (tester) async {
      await tester.pumpWidget(testableWidget(
        TriageCardWidget(data: const {
          'patientId': 'PT-003',
          'category': 'YELLOW',
          'action': 'Delayed treatment area',
        }),
      ));

      expect(find.textContaining('PT-003'), findsOneWidget);
    });

    testWidgets('renders BLACK triage', (tester) async {
      await tester.pumpWidget(testableWidget(
        TriageCardWidget(data: const {
          'patientId': 'PT-004',
          'category': 'BLACK',
          'action': 'Morgue area',
        }),
      ));

      expect(find.textContaining('PT-004'), findsOneWidget);
    });

    testWidgets('shows GCS score', (tester) async {
      await tester.pumpWidget(testableWidget(
        TriageCardWidget(data: const {
          'patientId': 'PT-005',
          'category': 'RED',
          'gcs': 7,
          'action': 'Immediate',
        }),
      ));

      expect(find.textContaining('GCS'), findsOneWidget);
      expect(find.textContaining('7'), findsOneWidget);
    });

    testWidgets('shows injuries list', (tester) async {
      await tester.pumpWidget(testableWidget(
        TriageCardWidget(data: const {
          'patientId': 'PT-006',
          'category': 'YELLOW',
          'injuries': ['Left femur fracture', 'Abrasions'],
          'action': 'Delayed',
        }),
      ));

      expect(find.textContaining('Yaralanmalar'), findsOneWidget);
      expect(find.textContaining('Left femur fracture'), findsOneWidget);
    });

    testWidgets('handles Turkish category labels', (tester) async {
      await tester.pumpWidget(testableWidget(
        TriageCardWidget(data: const {
          'patientId': 'PT-007',
          'category': 'RED',
          'categoryLabel': 'Kırmızı',
          'action': 'Acil müdahale alanı',
        }),
      ));

      expect(find.textContaining('KIRMIZI'), findsOneWidget);
    });

    testWidgets('handles snake_case keys', (tester) async {
      await tester.pumpWidget(testableWidget(
        TriageCardWidget(data: const {
          'patient_id': 'PT-008',
          'category': 'GREEN',
          'recommended_action': 'Gecikmeli tedavi',
        }),
      ));

      expect(find.textContaining('PT-008'), findsOneWidget);
    });
  });

  // ─── WarningCard Tests ─────────────────────────────────────────────────

  group('WarningCardWidget', () {
    testWidgets('renders INFO severity', (tester) async {
      await tester.pumpWidget(testableWidget(
        WarningCardWidget(data: const {
          'severity': 'INFO',
          'title': 'Bilgi',
          'message': 'Hasta stabil durumda.',
        }),
      ));

      expect(find.text('Bilgi'), findsOneWidget);
      expect(find.text('Hasta stabil durumda.'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('renders WARNING severity', (tester) async {
      await tester.pumpWidget(testableWidget(
        WarningCardWidget(data: const {
          'severity': 'WARNING',
          'title': 'Dikkat',
          'message': 'Tansiyon düşük.',
        }),
      ));

      expect(find.text('Dikkat'), findsOneWidget);
      expect(find.text('Tansiyon düşük.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders CRITICAL severity with pulse animation', (tester) async {
      await tester.pumpWidget(testableWidget(
        WarningCardWidget(data: const {
          'severity': 'CRITICAL',
          'title': 'Kardiyak Arrest',
          'message': 'Hasta nabızsız. CPR başlatın.',
          'action': 'Hemen CPR başlatın, defibrilatör hazırlayın.',
        }),
      ));

      expect(find.text('Kardiyak Arrest'), findsOneWidget);
      expect(find.textContaining('CPR'), findsWidgets);
      expect(find.text('KRİTİK UYARI'), findsOneWidget);
    });

    testWidgets('shows recommended action', (tester) async {
      await tester.pumpWidget(testableWidget(
        WarningCardWidget(data: const {
          'severity': 'WARNING',
          'title': 'Alerji',
          'message': 'Hasta penisilin alerjisi bildirdi.',
          'action': 'Alternatif antibiyotik seçin.',
        }),
      ));

      expect(find.text('Alternatif antibiyotik seçin.'), findsOneWidget);
    });

    testWidgets('defaults to INFO when severity missing', (tester) async {
      await tester.pumpWidget(testableWidget(
        WarningCardWidget(data: const {
          'title': 'Test',
          'message': 'Test message',
        }),
      ));

      // INFO icon
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });

  // ─── ProtocolCard Tests ─────────────────────────────────────────────────

  group('ProtocolCardWidget', () {
    testWidgets('renders protocol with steps', (tester) async {
      await tester.pumpWidget(testableWidget(
        ProtocolCardWidget(data: const {
          'protocolName': 'Kardiyak Arrest Protokolü',
          'urgency': 'CRITICAL',
          'steps': [
            'KPR 30:2 başlatın',
            'Defibrilatör takın',
            'Ritim değerlendirin',
          ],
          'source': 'ERC 2021',
        }),
      ));

      expect(find.text('Kardiyak Arrest Protokolü'), findsOneWidget);
      expect(find.text('KPR 30:2 başlatın'), findsOneWidget);
      expect(find.text('Defibrilatör takın'), findsOneWidget);
      expect(find.text('Ritim değerlendirin'), findsOneWidget);
      expect(find.text('ERC 2021'), findsOneWidget);
    });

    testWidgets('highlights current step', (tester) async {
      await tester.pumpWidget(testableWidget(
        ProtocolCardWidget(data: const {
          'protocolName': 'Test Protocol',
          'urgency': 'HIGH',
          'steps': ['Step 1', 'Step 2', 'Step 3'],
          'currentStep': 1,
        }),
      ));

      expect(find.text('Step 2'), findsOneWidget);
      // Current step indicator arrow
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
    });

    testWidgets('shows notes', (tester) async {
      await tester.pumpWidget(testableWidget(
        ProtocolCardWidget(data: const {
          'protocolName': 'Test Protocol',
          'steps': ['Step 1'],
          'notes': '4H ve 4T nedenlerini araştırın',
        }),
      ));

      expect(find.textContaining('4H ve 4T'), findsOneWidget);
    });

    testWidgets('handles Map-format steps', (tester) async {
      await tester.pumpWidget(testableWidget(
        ProtocolCardWidget(data: const {
          'protocolName': 'Advanced Protocol',
          'steps': [
            {'step_number': 1, 'description': 'First step', 'is_current': true},
            {'step_number': 2, 'description': 'Second step', 'is_current': false},
          ],
        }),
      ));

      expect(find.text('First step'), findsOneWidget);
      expect(find.text('Second step'), findsOneWidget);
    });

    testWidgets('handles snake_case keys', (tester) async {
      await tester.pumpWidget(testableWidget(
        ProtocolCardWidget(data: const {
          'protocol_name': 'Snake Case Protocol',
          'steps': ['Step 1'],
        }),
      ));

      expect(find.text('Snake Case Protocol'), findsOneWidget);
    });
  });

  // ─── VitalSignsCard Tests ─────────────────────────────────────────────────

  group('VitalSignsCardWidget', () {
    testWidgets('renders vital signs grid', (tester) async {
      await tester.pumpWidget(testableWidget(
        VitalSignsCardWidget(data: const {
          'hr': 88,
          'spo2': 97,
          'bp': '120/80',
          'rr': 16,
          'temperature': 36.8,
        }),
      ));

      expect(find.text('Vital Bulgular'), findsOneWidget);
      expect(find.text('88'), findsOneWidget);
      expect(find.text('97'), findsOneWidget);
      expect(find.text('120/80'), findsOneWidget);
      expect(find.text('16'), findsOneWidget);
    });

    testWidgets('shows empty state when no vitals', (tester) async {
      await tester.pumpWidget(testableWidget(
        VitalSignsCardWidget(data: const {}),
      ));

      expect(find.textContaining('henüz girilmedi'), findsOneWidget);
    });

    testWidgets('shows GCS score', (tester) async {
      await tester.pumpWidget(testableWidget(
        VitalSignsCardWidget(data: const {
          'gcs': 12,
        }),
      ));

      expect(find.text('12'), findsOneWidget);
      expect(find.byIcon(Icons.psychology), findsOneWidget);
    });

    testWidgets('handles nested vital format', (tester) async {
      await tester.pumpWidget(testableWidget(
        VitalSignsCardWidget(data: const {
          'blood_pressure': {'systolic': 130, 'diastolic': 85},
          'heart_rate': {'value': 92, 'trend': 'UP'},
        }),
      ));

      expect(find.text('130/85'), findsOneWidget);
      expect(find.text('92'), findsOneWidget);
    });

    testWidgets('shows pain score bar', (tester) async {
      await tester.pumpWidget(testableWidget(
        VitalSignsCardWidget(data: const {
          'hr': 100,
          'pain_score': 7,
        }),
      ));

      expect(find.textContaining('7/10'), findsOneWidget);
      expect(find.textContaining('Ağrı Skoru'), findsOneWidget);
    });

    testWidgets('shows timestamp', (tester) async {
      await tester.pumpWidget(testableWidget(
        VitalSignsCardWidget(data: const {
          'hr': 72,
          'timestamp': '14:30',
        }),
      ));

      expect(find.text('14:30'), findsOneWidget);
    });
  });

  // ─── Theme Tests ─────────────────────────────────────────────────────────

  group('ParamedTheme', () {
    test('triageColor returns correct colors', () {
      expect(ParamedTheme.triageColor('RED'), ParamedTheme.triageRed);
      expect(ParamedTheme.triageColor('YELLOW'), ParamedTheme.triageYellow);
      expect(ParamedTheme.triageColor('GREEN'), ParamedTheme.triageGreen);
      expect(ParamedTheme.triageColor('BLACK'), ParamedTheme.triageBlack);
    });

    test('triageColor handles Turkish labels', () {
      expect(ParamedTheme.triageColor('KIRMIZI'), ParamedTheme.triageRed);
      expect(ParamedTheme.triageColor('SARI'), ParamedTheme.triageYellow);
      expect(ParamedTheme.triageColor('YESIL'), ParamedTheme.triageGreen);
      expect(ParamedTheme.triageColor('SIYAH'), ParamedTheme.triageBlack);
    });

    test('triageColor handles semantic labels', () {
      expect(ParamedTheme.triageColor('IMMEDIATE'), ParamedTheme.triageRed);
      expect(ParamedTheme.triageColor('DELAYED'), ParamedTheme.triageYellow);
      expect(ParamedTheme.triageColor('MINOR'), ParamedTheme.triageGreen);
      expect(ParamedTheme.triageColor('EXPECTANT'), ParamedTheme.triageBlack);
    });

    test('triageColor is case-insensitive', () {
      expect(ParamedTheme.triageColor('red'), ParamedTheme.triageRed);
      expect(ParamedTheme.triageColor('Green'), ParamedTheme.triageGreen);
    });

    test('lightTheme returns valid ThemeData', () {
      final theme = ParamedTheme.lightTheme;
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, ParamedTheme.medicalBlue);
      expect(theme.colorScheme.error, ParamedTheme.emergencyRed);
    });
  });
}
