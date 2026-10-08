import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hoistbay/providers/app_state.dart';
import 'package:hoistbay/widgets/unified_action_bar.dart';

void main() {
  testWidgets('search box empties when the app resets the search (e.g. folder change)',
      (tester) async {
    final appState = AppState();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: appState,
      child: const MaterialApp(home: Scaffold(body: UnifiedActionBar())),
    ));

    await tester.enterText(find.byType(TextField), 'report');
    await tester.pump();
    expect(appState.searchQuery, 'report');

    // loadObjects() resets the query the same way when navigating.
    appState.clearSearch();
    await tester.pump();
    await tester.pump();

    expect(find.text('report'), findsNothing);
  });

  test('switching section clears the active search', () {
    final appState = AppState();
    appState.searchObjects('report');

    appState.selectSection(AppSection.cloudFront);

    expect(appState.searchQuery, isEmpty);
    expect(appState.filteredObjects, isEmpty);
  });
}
