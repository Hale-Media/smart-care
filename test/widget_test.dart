import 'package:flutter_test/flutter_test.dart';

import 'package:care_package/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CarePackageApp());
    expect(find.byType(CarePackageApp), findsOneWidget);
  });
}
