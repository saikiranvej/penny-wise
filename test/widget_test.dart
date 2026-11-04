
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:penny_wise/main.dart';

void main() {
  testWidgets('PennyWise app launches successfully',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ExpenseProvider(),
        child: const PennyWiseApp(),
      ),
    );

    await tester.pump();

    expect(find.text('PennyWise'), findsOneWidget);
  });
}
