import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../widgets/patient_form_card.dart';

/// Auto-filled patient form from voice documentation.
class PatientFormView extends StatelessWidget {
  final Map<String, dynamic> formData;

  const PatientFormView({super.key, required this.formData});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.assignment, color: ParamedTheme.safeGreen, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Generated Patient Form',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ParamedTheme.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.share, size: 20),
                color: ParamedTheme.textSecondary,
                tooltip: 'Share form',
                onPressed: () {
                  // Share functionality
                },
              ),
              IconButton(
                icon: const Icon(Icons.print, size: 20),
                color: ParamedTheme.textSecondary,
                tooltip: 'Print',
                onPressed: () {
                  // Print functionality
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Patient form card
          PatientFormCardWidget(data: formData),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Edit form
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ParamedTheme.textPrimary,
                    side: const BorderSide(color: ParamedTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Save form
                  },
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParamedTheme.safeGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
