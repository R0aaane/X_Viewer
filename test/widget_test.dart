import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitterviewer/widgets/section_empty_view.dart';

void main() {
  testWidgets('empty view shows title and message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SectionEmptyView(
          title: 'No items',
          message: 'Nothing here yet',
        ),
      ),
    );

    expect(find.text('No items'), findsOneWidget);
    expect(find.text('Nothing here yet'), findsOneWidget);
  });
}
