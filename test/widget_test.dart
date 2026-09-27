import 'package:flutter_test/flutter_test.dart';

import 'package:immora_mobile/main.dart';

void main() {
  testWidgets('Splash affiche le slogan et le bouton Commencer',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ImmoraApp());

    expect(find.text('L’immobilier, simplifié'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
  });
}
