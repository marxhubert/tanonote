import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:tano/features/settings/licenses_page.dart';

void main() {
  // The page reads its notices from the bundle, so the test needs the binding
  // to resolve asset keys the same way the app does.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every notice the page shows is bundled', () async {
    for (final (String title, String asset) in LicensesPage.notices) {
      expect(
        title.trim(),
        isNotEmpty,
        reason: 'the notice has no title: $asset',
      );
      final String text = await rootBundle.loadString(asset);
      expect(
        text.trim(),
        isNotEmpty,
        reason: 'the bundled notice is empty: $asset',
      );
    }
  });

  test('the project licence and the font licence are both shown', () {
    final List<String> assets = LicensesPage.notices
        .map(((String, String) notice) => notice.$2)
        .toList();

    expect(assets, contains('LICENSE'));
    expect(assets, contains('assets/fonts/NotoSerif-LICENSE.txt'));
  });

  test('the AGPL notice is the licence itself, not a summary', () async {
    final String licence = await rootBundle.loadString('LICENSE');

    expect(licence, contains('GNU AFFERO GENERAL PUBLIC LICENSE'));
    expect(licence, contains('Version 3'));
  });
}
