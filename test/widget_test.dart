import 'package:codegeist_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders codegeist on the start screen', (tester) async {
    await tester.pumpWidget(const MainApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
    expect(find.text('codegeist'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('codegeist'), matching: find.byType(Center)),
      findsOneWidget,
    );
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(ButtonStyleButton), findsNothing);
    expect(find.byType(CheckedModeBanner), findsNothing);
  });
}
