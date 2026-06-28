import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../utils/formatters.dart';
import '../ai_annotation.dart';
import 'review_provider.dart';

class FlagCard extends StatelessWidget {
  final AiAnnotation annotation;
  const FlagCard({super.key, required this.annotation});

  @override
  Widget build(BuildContext context) {
    final review = context.read<ReviewProvider>();
    final isPending = annotation.reviewState == 'pending';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── header row ───────────────────────────────────────────────────
            Row(
              children: [
                _EntityBadge(entity: annotation.entity),
                if (annotation.mood?.isNotEmpty == true) ...[
                  const SizedBox(width: 8),
                  _Pill(
                    label: annotation.mood!,
                    color: Colors.black26,
                  ),
                ],
                const Spacer(),
                Text(
                  Fmt.ago(annotation.createdAt),
                  style:
                      const TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ],
            ),
            // ── summary ──────────────────────────────────────────────────────
            if (annotation.summary?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(
                annotation.summary!,
                style: const TextStyle(fontSize: 14, height: 1.45),
              ),
            ],
            // ── risk flags ───────────────────────────────────────────────────
            if (annotation.riskFlags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: annotation.riskFlags
                    .map((f) => _RiskBadge(label: f))
                    .toList(),
              ),
            ],
            // ── follow-up flag ────────────────────────────────────────────────
            if (annotation.followUp) ...[
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.flag_outlined,
                      size: 14, color: AppTheme.warning),
                  SizedBox(width: 4),
                  Text(
                    'Follow-up needed',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            // ── action row (pending) / state label (decided) ─────────────────
            if (isPending) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => review.dismiss(annotation.id),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Dismiss'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black54),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => review.confirm(annotation.id),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Confirm'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      backgroundColor: AppTheme.ok,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    annotation.reviewState == 'confirmed'
                        ? Icons.check_circle
                        : Icons.cancel_outlined,
                    size: 14,
                    color: annotation.reviewState == 'confirmed'
                        ? AppTheme.ok
                        : Colors.black38,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _capitalize(annotation.reviewState),
                    style: TextStyle(
                      fontSize: 12,
                      color: annotation.reviewState == 'confirmed'
                          ? AppTheme.ok
                          : Colors.black38,
                    ),
                  ),
                  if (annotation.reviewedAt != null) ...[
                    const Text(' · ',
                        style: TextStyle(color: Colors.black26)),
                    Text(
                      Fmt.ago(annotation.reviewedAt!),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black38),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── badge widgets ─────────────────────────────────────────────────────────────

class _EntityBadge extends StatelessWidget {
  final AiEntity entity;
  const _EntityBadge({required this.entity});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (entity) {
      AiEntity.careCall => ('Care call', AppTheme.primary),
      AiEntity.handoverNote => ('Handover', AppTheme.info),
      AiEntity.incident => ('Incident', AppTheme.warning),
    };
    return _Pill(label: label, color: color);
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String label;
  const _RiskBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.critical.withValues(alpha: 0.08),
        border:
            Border.all(color: AppTheme.critical.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.critical,
        ),
      ),
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
