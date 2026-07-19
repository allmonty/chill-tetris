import 'package:flutter_test/flutter_test.dart';

import 'package:chill_tetris/main.dart';

void main() {
  testWidgets('Home screen shows the title and mode buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ChillTetrisApp());

    expect(find.text('TETRIS'), findsOneWidget);
    expect(find.text('Stage'), findsOneWidget);
    expect(find.text('Infinite'), findsOneWidget);
  });
}
