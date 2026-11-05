import 'package:clean_gallery/core/database/settings_repository.dart';
import 'package:clean_gallery/core/database/trash_repository.dart';
import 'package:clean_gallery/core/media/media_thumbnail.dart';
import 'package:clean_gallery/core/providers.dart';
import 'package:clean_gallery/core/settings/app_settings.dart';
import 'package:clean_gallery/core/settings/settings_controller.dart';
import 'package:clean_gallery/features/library/albums_screen.dart';
import 'package:clean_gallery/features/monetization/ad_banner_slot.dart';
import 'package:clean_gallery/features/monetization/monetization_controller.dart';
import 'package:clean_gallery/features/monetization/native_ad_card.dart';
import 'package:clean_gallery/features/monetization/remove_ads_offer.dart';
import 'package:clean_gallery/platform/purchase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  group('launch sequence and purchase', () {
    late FakeAdsService ads;
    late FakePurchaseService purchases;

    ProviderContainer container({AppSettings settings = const AppSettings()}) {
      final db = inMemoryDatabase();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          initialAppSettingsProvider.overrideWithValue(settings),
          adsServiceProvider.overrideWithValue(ads),
          purchaseServiceProvider.overrideWithValue(purchases),
        ],
      );
      addTearDown(container.dispose);
      container.listen(monetizationProvider, (_, _) {});
      return container;
    }

    Monetization controller(ProviderContainer c) =>
        c.read(monetizationProvider.notifier);

    setUp(() {
      ads = FakeAdsService(configured: true);
      purchases = FakePurchaseService();
    });

    test('consent comes before the SDK, and nothing loads before it', () async {
      final c = container();
      expect(c.read(monetizationProvider).phase, AdsPhase.starting);
      expect(ads.calls, isEmpty);

      await controller(c).start();

      expect(ads.calls, ['consent', 'initialize', 'preload']);
      expect(c.read(monetizationProvider).phase, AdsPhase.ready);
      expect(c.read(monetizationProvider).price, '4,99 €');
    });

    test('without consent, the SDK never starts', () async {
      ads.consent = false;
      final c = container();
      await controller(c).start();
      expect(ads.calls, ['consent']);
      expect(c.read(monetizationProvider).phase, AdsPhase.off);
    });

    test('a purchase found at launch: no consent, no SDK, cached', () async {
      purchases.owned = true;
      final c = container();
      await controller(c).start();

      expect(ads.calls, isEmpty);
      final state = c.read(monetizationProvider);
      expect(state.adFree, isTrue);
      expect(state.phase, AdsPhase.off);
      expect(c.read(appSettingsControllerProvider).adFree, isTrue);
      expect(
        await c.read(settingsRepositoryProvider).read(SettingKeys.adFree),
        'true',
      );
    });

    test('the cached answer shows no ad before the store replies', () {
      final c = container(settings: const AppSettings(adFree: true));
      expect(c.read(monetizationProvider).phase, AdsPhase.off);
    });

    test('offline, the cached purchase stays', () async {
      purchases.owned = null;
      final c = container(settings: const AppSettings(adFree: true));
      await controller(c).start();
      expect(ads.calls, isEmpty);
      expect(c.read(monetizationProvider).adFree, isTrue);
    });

    test('a refunded purchase brings ads back at launch', () async {
      purchases.owned = false;
      final c = container(settings: const AppSettings(adFree: true));
      await controller(c).start();
      expect(ads.calls, ['consent', 'initialize', 'preload']);
      expect(c.read(monetizationProvider).adFree, isFalse);
      expect(c.read(monetizationProvider).phase, AdsPhase.ready);
    });

    test('a build without ad units asks for nothing', () async {
      ads = FakeAdsService();
      final c = container();
      expect(c.read(monetizationProvider).phase, AdsPhase.off);
      await controller(c).start();
      expect(ads.calls, isEmpty);
    });

    test('buying removes ads at once and is saved', () async {
      final c = container();
      await controller(c).start();
      await controller(c).buy();
      expect(purchases.buys, 1);

      purchases.emit(PurchaseUpdate.purchased);
      await pumpEventQueue();

      final state = c.read(monetizationProvider);
      expect(state.adFree, isTrue);
      expect(state.phase, AdsPhase.off);
      expect(state.message, PurchaseMessage.purchased);
      expect(c.read(appSettingsControllerProvider).adFree, isTrue);
    });

    for (final (update, message) in [
      (PurchaseUpdate.pending, PurchaseMessage.pending),
      (PurchaseUpdate.cancelled, PurchaseMessage.cancelled),
      (PurchaseUpdate.failed, PurchaseMessage.failed),
    ]) {
      test('$update keeps the ads and gives a message', () async {
        final c = container();
        await controller(c).start();
        purchases.emit(update);
        await pumpEventQueue();
        final state = c.read(monetizationProvider);
        expect(state.adFree, isFalse);
        expect(state.message, message);
        controller(c).messageShown();
        expect(c.read(monetizationProvider).message, isNull);
      });
    }

    test('already owned counts as restored', () async {
      final c = container();
      await controller(c).start();
      purchases.emit(PurchaseUpdate.alreadyOwned);
      await pumpEventQueue();
      expect(c.read(monetizationProvider).adFree, isTrue);
      expect(c.read(monetizationProvider).message, PurchaseMessage.restored);
    });

    test('a purchase screen refused because already owned restores', () async {
      final c = container();
      await controller(c).start();
      purchases
        ..canOpen = false
        ..owned = true;
      await controller(c).buy();
      expect(c.read(monetizationProvider).adFree, isTrue);
      expect(c.read(monetizationProvider).message, PurchaseMessage.restored);
    });

    test('a purchase screen that cannot open is an error', () async {
      final c = container();
      await controller(c).start();
      purchases.canOpen = false;
      await controller(c).buy();
      expect(c.read(monetizationProvider).adFree, isFalse);
      expect(c.read(monetizationProvider).message, PurchaseMessage.failed);
    });

    test('restore: found, nothing, store unreachable', () async {
      final c = container();
      await controller(c).start();

      await controller(c).restore();
      expect(
        c.read(monetizationProvider).message,
        PurchaseMessage.nothingToRestore,
      );

      purchases.owned = null;
      await controller(c).restore();
      expect(c.read(monetizationProvider).message, PurchaseMessage.failed);

      purchases.owned = true;
      await controller(c).restore();
      expect(c.read(monetizationProvider).message, PurchaseMessage.restored);
      expect(c.read(monetizationProvider).adFree, isTrue);
    });

    group('ad before a manual slideshow', () {
      final start = DateTime(2026, 11, 5, 12);

      int shown() => ads.calls.where((c) => c == 'interstitial').length;

      test('shown, then at most once every 5 minutes', () async {
        final c = container();
        await controller(c).start();

        await controller(c).showSlideshowAd(now: start);
        expect(shown(), 1);
        await controller(c).showSlideshowAd(
          now: start.add(const Duration(minutes: 4, seconds: 59)),
        );
        expect(shown(), 1);
        await controller(c)
            .showSlideshowAd(now: start.add(const Duration(minutes: 5)));
        expect(shown(), 2);
      });

      test('the next one is loaded after it closes', () async {
        final c = container();
        await controller(c).start();
        await controller(c).showSlideshowAd(now: start);
        await pumpEventQueue();
        expect(ads.calls.where((c) => c == 'preload'), hasLength(2));
      });

      test('never for an ad-free user', () async {
        purchases.owned = true;
        final c = container();
        await controller(c).start();
        await controller(c).showSlideshowAd(now: start);
        expect(ads.calls, isEmpty);
      });

      test('never without consent', () async {
        ads.consent = false;
        final c = container();
        await controller(c).start();
        await controller(c).showSlideshowAd(now: start);
        expect(shown(), 0);
      });
    });

    test('withdrawing consent stops the ads', () async {
      final c = container();
      await controller(c).start();
      ads.consent = false;
      await controller(c).showPrivacyOptions();
      expect(c.read(monetizationProvider).phase, AdsPhase.off);
    });
  });

  group('placements', () {
    Future<void> openTab(WidgetTester tester, String name) async {
      await tester.tap(find.byTooltip(name));
      await tester.pumpAndSettle();
    }

    const adKey = ValueKey('fake-ad');

    testApp('Albums has the banner and its link, Stats the labeled card', (
      tester,
    ) async {
      final ads = FakeAdsService(configured: true);
      await pumpTestApp(tester, ads: ads);

      expect(find.byType(AdBannerSlot), findsNothing);
      await openTab(tester, 'Albums');
      expect(find.byType(AlbumsScreen), findsOneWidget);
      expect(find.byType(AdBannerSlot), findsOneWidget);
      expect(find.text('Remove ads'), findsOneWidget);
      expect(find.byKey(adKey), findsOneWidget);
      expect(ads.calls, contains('banner'));

      await openTab(tester, 'Stats');
      await tester.scrollUntilVisible(
        find.byType(NativeAdCard),
        200,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Ad'), findsOneWidget);
      expect(ads.calls, contains('native'));
    });

    testApp('an ad-free user has no slot, and the SDK is never asked', (
      tester,
    ) async {
      final ads = FakeAdsService(configured: true);
      await pumpTestApp(
        tester,
        ads: ads,
        purchases: FakePurchaseService(owned: true),
        settings: const AppSettings(adFree: true),
      );
      await openTab(tester, 'Albums');
      expect(find.byType(AdBannerSlot), findsNothing);
      await openTab(tester, 'Stats');
      expect(find.byType(NativeAdCard), findsNothing);
      expect(ads.calls, isEmpty);
    });

    testApp('a banner that does not load keeps its space', (tester) async {
      final ads = FakeAdsService(configured: true, fill: false);
      await pumpTestApp(tester, ads: ads);
      await openTab(tester, 'Albums');
      expect(find.byKey(adKey), findsNothing);
      expect(find.byType(AdBannerSlot), findsOneWidget);
      expect(tester.getSize(find.byType(AdBannerSlot)).height, greaterThan(50));
      // Let the single retry run and fail.
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(ads.calls.where((c) => c == 'banner'), hasLength(2));
    });
  });

  group('offer after a large cleanup', () {
    Future<void> deleteFromTrash(
      WidgetTester tester, {
      required int sizeBytes,
      FakePurchaseService? purchases,
      AppSettings settings = const AppSettings(),
      bool configured = true,
    }) async {
      final db = inMemoryDatabase();
      addTearDown(db.close);
      await TrashRepository(db)
          .trash([testItem(1, sizeBytes: sizeBytes)], retentionDays: 30);
      await pumpTestApp(
        tester,
        media: FakeMediaSource(items: [testItem(1, sizeBytes: sizeBytes)]),
        database: db,
        ads: FakeAdsService(configured: configured),
        purchases: purchases,
        settings: settings,
      );
      await tester.tap(find.byTooltip('Albums'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trash').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MediaThumbnail));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete for good'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
    }

    testApp('over 500 MB: shown with the store price, then never again', (
      tester,
    ) async {
      await deleteFromTrash(tester, sizeBytes: removeAdsOfferThreshold + 1);
      expect(find.text('No thanks'), findsOneWidget);
      expect(find.textContaining('4,99 €'), findsOneWidget);
      await tester.tap(find.text('No thanks'));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold).first);
      expect(
        ProviderScope.containerOf(context)
            .read(appSettingsControllerProvider)
            .removeAdsOfferShown,
        isTrue,
      );
    });

    testApp('at 500 MB or less: nothing', (tester) async {
      await deleteFromTrash(tester, sizeBytes: removeAdsOfferThreshold);
      expect(find.text('No thanks'), findsNothing);
    });

    testApp('already shown once: nothing', (tester) async {
      await deleteFromTrash(
        tester,
        sizeBytes: removeAdsOfferThreshold + 1,
        settings: const AppSettings(removeAdsOfferShown: true),
      );
      expect(find.text('No thanks'), findsNothing);
    });

    testApp('no price from the store: nothing', (tester) async {
      await deleteFromTrash(
        tester,
        sizeBytes: removeAdsOfferThreshold + 1,
        purchases: FakePurchaseService(price: null),
      );
      expect(find.text('No thanks'), findsNothing);
    });
  });

  group('settings', () {
    Future<void> openAds(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Restore purchase'),
        300,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      await tester.pumpAndSettle();
    }

    testApp('shows the store price, restore and privacy choices', (
      tester,
    ) async {
      final purchases = FakePurchaseService();
      await pumpTestApp(
        tester,
        ads: FakeAdsService(configured: true, privacyRequired: true),
        purchases: purchases,
      );
      await openAds(tester);
      expect(find.text('Remove ads — 4,99 €'), findsOneWidget);
      expect(find.text('Privacy & ad choices'), findsOneWidget);

      await tester.tap(find.text('Remove ads — 4,99 €'));
      await tester.pumpAndSettle();
      expect(purchases.buys, 1);

      await tester.tap(find.text('Restore purchase'));
      await tester.pumpAndSettle();
      expect(
        find.text('No purchase found on this Google account.'),
        findsOneWidget,
      );
    });

    testApp('once purchased, shows the ad-free state', (tester) async {
      await pumpTestApp(
        tester,
        ads: FakeAdsService(configured: true, privacyRequired: true),
        purchases: FakePurchaseService(owned: true),
        settings: const AppSettings(adFree: true),
      );
      await openAds(tester);
      expect(find.text('Ad-free ✓'), findsOneWidget);
      expect(find.text('Privacy & ad choices'), findsNothing);
    });

    testApp('a build without ads has no section', (tester) async {
      await pumpTestApp(tester);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Restore purchase', skipOffstage: false), findsNothing);
    });
  });
}
