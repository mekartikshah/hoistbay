import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoistbay/components/app_dialog.dart';

void main() {
  testWidgets('confirm pops itself and leaves dialogs pushed by onConfirm open',
      (tester) async {
    int confirmCalls = 0;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (_) => AppConfirmDialog(
                title: 'Delete Selected Objects',
                message: 'Delete 1 object(s)?',
                confirmLabel: 'Delete',
                onConfirm: () {
                  confirmCalls++;
                  showDialog<void>(
                    context: context,
                    builder: (_) => const AlertDialog(title: Text('Deleting Objects')),
                  );
                },
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(confirmCalls, 1);
    expect(find.text('Delete Selected Objects'), findsNothing);
    expect(find.text('Deleting Objects'), findsOneWidget);
  });

  testWidgets('confirm still returns true to awaiting callers', (tester) async {
    bool? result;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showDialog<bool>(
              context: context,
              builder: (_) => const AppConfirmDialog(
                title: 'Logout',
                message: 'Are you sure?',
                confirmLabel: 'Logout',
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });
}
