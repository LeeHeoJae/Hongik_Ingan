import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/navigation/modal_navigation.dart';

void main() {
  late GlobalKey<NavigatorState> key;
  late ModalNavigation navigation;
  late ModalRouteInformationProvider history;
  late List<int> moves;
  late List<MethodCall> reports;

  setUp(() {
    key = GlobalKey<NavigatorState>();
    moves = [];
    reports = [];
    history = ModalRouteInformationProvider(
      initialRouteInformation: RouteInformation(uri: Uri.parse('/')),
      go: moves.add,
    );
    navigation = ModalNavigation(
      navigatorKey: key,
      home: const Scaffold(body: TextField()),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.navigation, (call) async {
          reports.add(call);
          return null;
        });
  });

  tearDown(() {
    navigation.dispose();
    history.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.navigation, null);
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerDelegate: navigation,
        routeInformationProvider: history,
        routeInformationParser: const ModalRouteInformationParser(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, {bool sheet = false}) async {
    final context = key.currentContext!;
    if (sheet) {
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => const SizedBox(height: 200, child: Text('Sheet')),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(title: Text('Dialog')),
      );
    }
    await tester.pumpAndSettle();
  }

  for (final sheet in [false, true]) {
    testWidgets(
      'browser back closes ${sheet ? 'sheet' : 'dialog'} and keeps home',
      (tester) async {
        await mount(tester);
        await tester.enterText(find.byType(TextField), 'preserved');
        final home = navigation.currentConfiguration;
        await open(tester, sheet: sheet);
        expect(
          reports
              .where((call) => call.method == 'routeInformationUpdated')
              .last
              .arguments['replace'],
          isFalse,
        );
        await history.didPushRouteInformation(home);
        await tester.pumpAndSettle();
        expect(find.text(sheet ? 'Sheet' : 'Dialog'), findsNothing);
        expect(find.text('preserved'), findsOneWidget);
        expect(moves, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('browser back dismisses only the top of nested dialogs', (
    tester,
  ) async {
    await mount(tester);
    await open(tester);
    final first = navigation.currentConfiguration;
    await open(tester, sheet: true);
    await history.didPushRouteInformation(first);
    await tester.pumpAndSettle();
    expect(find.text('Sheet'), findsNothing);
    expect(find.text('Dialog'), findsOneWidget);
  });

  testWidgets(
    'explicit dismiss consumes history before the next dialog opens',
    (tester) async {
      await mount(tester);
      final home = navigation.currentConfiguration;
      await open(tester);
      key.currentState!.pop();
      await tester.pumpAndSettle();
      expect(moves, [-1]);
      await open(tester, sheet: true);
      await history.didPushRouteInformation(home);
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsOneWidget);
      expect(
        reports
            .where((call) => call.method == 'routeInformationUpdated')
            .last
            .arguments['replace'],
        isFalse,
      );
      await history.didPushRouteInformation(home);
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsNothing);
    },
  );

  testWidgets('system back dismisses a dialog and keeps the home route', (
    tester,
  ) async {
    await mount(tester);
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Dialog'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(moves, [-1]);
  });

  testWidgets('PopScope can handle back inside a dialog before dismissal', (
    tester,
  ) async {
    await mount(tester);
    final home = navigation.currentConfiguration;
    var detail = true;
    showDialog<void>(
      context: key.currentContext!,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => PopScope(
          canPop: !detail,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) setState(() => detail = false);
          },
          child: AlertDialog(title: Text(detail ? 'Detail' : 'List')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await history.didPushRouteInformation(home);
    await tester.pumpAndSettle();
    expect(find.text('List'), findsOneWidget);
    expect(
      reports
          .where((call) => call.method == 'routeInformationUpdated')
          .last
          .arguments['replace'],
      isFalse,
    );
    await history.didPushRouteInformation(home);
    await tester.pumpAndSettle();
    expect(find.text('List'), findsNothing);
  });

  testWidgets(
    'multiple overlays opened in one frame get separate history entries',
    (tester) async {
      await mount(tester);
      reports.clear();
      for (var i = 0; i < 2; i++) {
        showDialog<void>(
          context: key.currentContext!,
          builder: (_) => const AlertDialog(title: Text('Dialog')),
        );
      }
      await tester.pumpAndSettle();
      final entries = reports
          .where((call) => call.method == 'routeInformationUpdated')
          .toList();
      expect(entries, hasLength(2));
      await history.didPushRouteInformation(
        RouteInformation(
          uri: Uri.parse('/'),
          state: entries.first.arguments['state'],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dialog'), findsOneWidget);
    },
  );

  testWidgets('forward history cannot reopen a disposed dialog', (
    tester,
  ) async {
    await mount(tester);
    final home = navigation.currentConfiguration;
    await open(tester);
    final dialog = navigation.currentConfiguration;
    await history.didPushRouteInformation(home);
    await tester.pumpAndSettle();
    await history.didPushRouteInformation(dialog);
    await tester.pumpAndSettle();
    expect(find.text('Dialog'), findsNothing);
    expect(moves, isEmpty);
  });
}
