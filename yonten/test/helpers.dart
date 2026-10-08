import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yonten/app/app.dart';
import 'package:yonten/data/curriculum_providers.dart';
import 'package:yonten/data/local_store.dart';
import 'package:yonten/data/models/curriculum.dart';
import 'package:yonten/data/repositories/curriculum_repository.dart';
import 'package:yonten/data/repositories/local_user_data.dart';
import 'package:yonten/widgets/motion_scope.dart';

/// The bundled curriculum, read straight from disk.
List<Chapter> loadUnit1() =>
    parseCurriculum(File('assets/data/curriculum.json').readAsStringSync());

/// Pumps the whole app in local mode with reduced motion on (so loops are
/// stopped and pumpAndSettle can settle). With [demo], the store starts in
/// the spec's demo state (ཀ ཁ ག done, ང active).
Future<ProviderContainer> pumpYonten(
  WidgetTester tester, {
  KeyValueStore? store,
  bool demo = false,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = store ?? MemoryStore();
  if (demo) {
    await LocalUserData(s).debugLoadDemo(lessonsInOrder(loadUnit1()), const []);
  }
  final c = ProviderContainer(overrides: [
    backendProvider.overrideWithValue(Backend(store: s)),
  ]);
  addTearDown(c.dispose);
  c.read(reducedMotionOverrideProvider.notifier).toggle();
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: const YontenApp(status: 'test'),
  ));
  await tester.pumpAndSettle();
  return c;
}
