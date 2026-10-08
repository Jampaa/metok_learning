import 'package:flutter_test/flutter_test.dart';

import 'package:yonten/main.dart';

void main() {
  testWidgets('shell renders with a bootstrap status', (tester) async {
    await tester.pumpWidget(const YontenApp(status: 'Local mode'));
    expect(find.text('Yonten'), findsOneWidget);
    expect(find.text('Local mode'), findsOneWidget);
  });
}
