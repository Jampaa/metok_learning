import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yonten/main.dart';
import 'package:yonten/widgets/toy_button.dart';
import 'package:yonten/widgets/toy_surface.dart';

void main() {
  testWidgets('gallery renders with a bootstrap status', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: YontenApp(status: 'Local mode')),
    );
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Local mode'), findsOneWidget);
  });

  testWidgets('ToyButton keeps its height when pressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: ToyButton(
          semanticLabel: 'Go',
          label: 'Go',
          onPressed: () => taps++,
        ),
      ),
    ));
    final before = tester.getSize(find.byType(ToySurface));
    final face = find.descendant(
      of: find.byType(ToySurface),
      matching: find.text('Go'),
    );
    final faceTopBefore = tester.getTopLeft(face).dy;

    final gesture = await tester.startGesture(tester.getCenter(face));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ToySurface)), before);
    expect(tester.getTopLeft(face).dy, faceTopBefore + 2);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.getTopLeft(face).dy, faceTopBefore);
  });

  testWidgets('disabled ToyButton ignores taps', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(
        child: ToyButton(semanticLabel: 'Claim', label: 'Claim', onPressed: null),
      ),
    ));
    await tester.tap(find.text('Claim'));
    await tester.pumpAndSettle();
    expect(find.text('Claim'), findsOneWidget);
  });
}
