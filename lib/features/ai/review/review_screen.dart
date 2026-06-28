import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import 'flag_card.dart';
import 'review_provider.dart';

/// Embeddable senior-review widget.  Wrap in a [Scaffold] if used standalone.
/// Requires [ReviewProvider] to be in the widget tree.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ReviewProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final review = context.watch<ReviewProvider>();

    return Column(
      children: [
        // ── filter bar ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
          child: Row(
            children: [
              for (final f in ['pending', 'confirmed', 'dismissed'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_capitalize(f)),
                    selected: review.filter == f,
                    onSelected: (_) => review.load(filter: f),
                  ),
                ),
              const Spacer(),
              if (review.queuedCount > 0)
                Tooltip(
                  message:
                      '${review.queuedCount} annotation(s) queued — '
                      'will sync when server is reachable',
                  child: Chip(
                    avatar: const Icon(Icons.cloud_queue_outlined, size: 14),
                    label: Text('${review.queuedCount}'),
                    backgroundColor:
                        AppTheme.warning.withValues(alpha: 0.12),
                    side: BorderSide(
                        color: AppTheme.warning.withValues(alpha: 0.3)),
                  ),
                ),
              review.loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => review.load(),
                      tooltip: 'Refresh',
                    ),
            ],
          ),
        ),
        // ── list ─────────────────────────────────────────────────────────────
        Expanded(
          child: review.loading && review.items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : review.items.isEmpty
                  ? const _Empty()
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: review.items.length,
                      itemBuilder: (_, i) =>
                          FlagCard(annotation: review.items[i]),
                    ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 52,
            color: Colors.black.withValues(alpha: 0.13),
          ),
          const SizedBox(height: 12),
          const Text(
            'No items to review',
            style: TextStyle(color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
