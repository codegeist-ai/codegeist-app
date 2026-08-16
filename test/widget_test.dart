import 'package:codegeist_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  testWidgets('renders the local model loader without starting work', (
    tester,
  ) async {
    await tester.pumpWidget(const MainApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.bySemanticsLabel('codegeist'), findsOneWidget);
    expect(find.text('Local chat'), findsOneWidget);
    expect(
      find.text('1.11 GB model download. Runs locally after the first load.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Load model'), findsOneWidget);
    expect(find.byKey(const Key('model-progress')), findsNothing);
    expect(find.byKey(const Key('chat-input')), findsNothing);
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(CheckedModeBanner), findsNothing);
  });

  testWidgets('shows the Alpha Preview disclosure before model loading', (
    tester,
  ) async {
    var loadRequests = 0;
    await tester.pumpWidget(
      MainApp(
        modelLoadOverride: () async {
          loadRequests += 1;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('load-model')));
    await tester.pumpAndSettle();

    expect(find.text('Codegeist Alpha Preview'), findsOneWidget);
    expect(find.textContaining('small experimental model'), findsOneWidget);
    expect(
      find.textContaining('inaccurate, incomplete, unsafe'),
      findsOneWidget,
    );
    expect(find.textContaining('approximately 1.11 GB'), findsOneWidget);
    expect(find.textContaining('stay on this device'), findsOneWidget);
    expect(find.textContaining('professional, legal, medical'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);
    expect(loadRequests, 0);
  });

  testWidgets('cancels the Alpha Preview without starting model loading', (
    tester,
  ) async {
    var loadRequests = 0;
    await tester.pumpWidget(
      MainApp(
        modelLoadOverride: () async {
          loadRequests += 1;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('load-model')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Codegeist Alpha Preview'), findsNothing);
    expect(find.byKey(const Key('model-progress')), findsNothing);
    expect(find.byKey(const Key('chat-input')), findsNothing);
    expect(loadRequests, 0);
  });

  testWidgets('continues from the Alpha Preview into one model load request', (
    tester,
  ) async {
    var loadRequests = 0;
    await tester.pumpWidget(
      MainApp(
        modelLoadOverride: () async {
          loadRequests += 1;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('load-model')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Codegeist Alpha Preview'), findsNothing);
    expect(loadRequests, 1);
  });
}
