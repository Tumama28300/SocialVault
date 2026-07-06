import 'package:flutter_test/flutter_test.dart';

import 'package:social_vault/main.dart';

void main() {
  testWidgets('SocialVaultApp builds without throwing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SocialVaultApp());

    expect(find.text('Social Vault'), findsOneWidget);
  });
}
