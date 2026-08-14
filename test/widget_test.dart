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
}
