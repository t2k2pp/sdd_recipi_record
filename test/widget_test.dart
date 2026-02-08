import 'package:flutter_test/flutter_test.dart';

import 'package:sdd_recipi_record/main.dart';

void main() {
  testWidgets('Recipe app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const RecipeApp());
    expect(find.text('レシピ一覧'), findsOneWidget);
  });
}
