import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/theme/theme.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/cafeteria_menu/data/meal_vote_service.dart';
import 'package:hongik_ingan/features/cafeteria_menu/domain/cafeteria_menu.dart';
import 'package:hongik_ingan/features/cafeteria_menu/presentation/widgets/cafeteria_menu_section.dart';

const _items = [
  ['제육볶음', '백미밥', '미역국', '계란말이', '콩나물무침', '배추김치', '요구르트'],
  ['등심돈까스', '백미밥', '우동국물', '양배추샐러드', '단무지', '배추김치', '요구르트'],
];

class _PreviewVotes extends MealVoteService {
  @override
  Future<List<MealVote>> fetch(String date, {bool force = false}) async => [
    MealVote(
      id: 'preview-1',
      items: _items[0],
      likes: 12,
      dislikes: 3,
      choice: 1,
    ),
    MealVote(id: 'preview-2', items: _items[1], likes: 8, dislikes: 2),
  ];
}

void main() {
  // Opt-in capture only: ordinary test runs do not write screenshots.
  const capture = bool.fromEnvironment('CAPTURE_VOTE_PREVIEW');
  testWidgets('capture implemented lunch voting widgets', (tester) async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
    }
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final service = _PreviewVotes();
    addTearDown(service.dispose);
    final date = DateTime(2026, 10, 15);
    for (final (name, width, height) in [
      ('mobile', 390.0, 620.0),
      ('desktop', 900.0, 360.0),
      ('mobile-dark', 390.0, 620.0),
    ]) {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      final key = GlobalKey();
      final previewTheme = name.endsWith('-dark') ? darkThemeData : themeData;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mealVoteAccountProvider.overrideWithValue('A123456'),
            mealVoteServiceProvider.overrideWithValue(service),
            campusClockProvider.overrideWithValue(() => date),
          ],
          child: MaterialApp(
            theme: previewTheme,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: RepaintBoundary(
                  key: key,
                  child: Container(
                    color: previewTheme.scaffoldBackgroundColor,
                    padding: const EdgeInsets.all(16),
                    child: CafeteriaMenuSection(
                      cafeteria: CafeteriaMenu(
                        name: '제2기숙사',
                        priceInfo: '',
                        meals: [
                          for (final items in _items)
                            MealMenu(
                              type: MealType.lunch,
                              time: '11:30~14:00',
                              items: items,
                            ),
                        ],
                      ),
                      voteDate: date,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File('artifacts/diagnostics/meal-vote-$name.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }, skip: !capture);
}
