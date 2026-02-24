import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import 'triage_controller.dart';

/// Large, glove-friendly triage assignment buttons for rapid field use.
class QuickTriageButtons extends ConsumerWidget {
  const QuickTriageButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Triage',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ParamedTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'START Triage - Tap to quickly classify',
          style: TextStyle(
            color: ParamedTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _TriageButton(
                label: 'RED',
                subtitle: 'Immediate',
                color: ParamedTheme.triageRed,
                textColor: Colors.white,
                icon: Icons.emergency,
                onTap: () => ref
                    .read(triageControllerProvider.notifier)
                    .quickTriage('RED'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TriageButton(
                label: 'YELLOW',
                subtitle: 'Delayed',
                color: ParamedTheme.triageYellow,
                textColor: Colors.black,
                icon: Icons.schedule,
                onTap: () => ref
                    .read(triageControllerProvider.notifier)
                    .quickTriage('YELLOW'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TriageButton(
                label: 'GREEN',
                subtitle: 'Minor',
                color: ParamedTheme.triageGreen,
                textColor: Colors.white,
                icon: Icons.directions_walk,
                onTap: () => ref
                    .read(triageControllerProvider.notifier)
                    .quickTriage('GREEN'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TriageButton(
                label: 'BLACK',
                subtitle: 'Expectant',
                color: ParamedTheme.triageBlack,
                textColor: Colors.white,
                icon: Icons.do_not_disturb_on,
                onTap: () => ref
                    .read(triageControllerProvider.notifier)
                    .quickTriage('BLACK'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TriageButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color color;
  final Color textColor;
  final IconData icon;
  final VoidCallback onTap;

  const _TriageButton({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.textColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 110,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 26),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
