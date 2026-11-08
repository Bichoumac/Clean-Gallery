import 'package:clean_gallery/core/app_links.dart';
import 'package:clean_gallery/core/theme/font_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  /// Scrolls [text] into view, at the top of the page, clear of the
  /// navigation bar.
  Future<void> reveal(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
  }

  testApp('Settings opens the privacy policy in the browser', (tester) async {
    final bridge = FakePlatformBridge();
    await pumpTestApp(tester, bridge: bridge);
    await openSettings(tester);
    await reveal(tester, 'Privacy policy');
    await tester.tap(find.text('Privacy policy'));
    await tester.pump();
    expect(bridge.openedLinks, [AppLinks.privacyPolicy]);
  });

  testApp('About shows the version, the promise and the links', (tester) async {
    final bridge = FakePlatformBridge();
    await pumpTestApp(tester, bridge: bridge);
    await openSettings(tester);
    await reveal(tester, 'About Clean Gallery');
    await tester.tap(find.text('About Clean Gallery'));
    await tester.pumpAndSettle();

    expect(find.text('Version 1.0.0'), findsOneWidget);
    expect(
      find.textContaining('Your photos never leave your device.'),
      findsOneWidget,
    );
    expect(find.textContaining('GNU GPL v3'), findsOneWidget);

    await tester.tap(find.text('Source code'));
    await tester.pump();
    await reveal(tester, 'Map data © OpenStreetMap contributors');
    await tester.tap(find.text('Map data © OpenStreetMap contributors'));
    await tester.pump();
    expect(bridge.openedLinks, [
      AppLinks.source,
      AppLinks.openStreetMapCopyright,
    ]);
  });

  testApp('About opens the licenses page', (tester) async {
    await pumpTestApp(tester);
    await openSettings(tester);
    await reveal(tester, 'About Clean Gallery');
    await tester.tap(find.text('About Clean Gallery'));
    await tester.pumpAndSettle();
    await reveal(tester, 'Open source libraries');
    await tester.tap(find.text('Open source libraries'));
    await tester.pumpAndSettle();
    expect(find.text('Clean Gallery'), findsWidgets);
    expect(find.text('1.0.0'), findsOneWidget);
  });

  test('the bundled fonts are on the licenses page', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFontLicenses();
    final packages = <String>{};
    await for (final license in LicenseRegistry.licenses) {
      packages.addAll(license.packages);
    }
    expect(packages, containsAll(['Manrope', 'Bricolage Grotesque']));
  });
}
