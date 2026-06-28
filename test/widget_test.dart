import 'package:flutter_test/flutter_test.dart';

import 'package:smart_care/features/ai/queue/annotation_queue.dart';
import 'package:smart_care/main.dart';

class _FakeQueue implements AnnotationQueueStore {
  @override
  Future<void> open() async {}
  @override
  Future<void> enqueue(QueuedAnnotation item) async {}
  @override
  Future<List<QueuedAnnotation>> pending({int maxRetries = 5}) async => [];
  @override
  Future<void> markSynced(int id) async {}
  @override
  Future<void> incrementRetry(int id) async {}
  @override
  Future<int> pendingCount() async => 0;
}

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(CarePackageApp(queue: _FakeQueue()));
    expect(find.byType(CarePackageApp), findsOneWidget);
  });
}
