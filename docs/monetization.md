# Monetization

How ads, consent and the *Remove ads* purchase work, what must be set up outside the code, and what has been checked. The reasons are in [ADR 0030](decisions/0030-ads-and-purchase.md).

Last updated: 2026-11-05 — Milestone M11

## Rules

- **Three placements only**: an adaptive banner at the bottom of the Albums tab, one native card in the Stats tab, one interstitial before a manual slideshow. No other interstitial, no rewarded or app-open ad. A test enforces it.
- **Nothing about the user's media reaches an SDK**: requests are an empty `AdRequest()`, with no keywords and no content URL. A test enforces it.
- All features stay free. The purchase only removes ads.

## Launch sequence

`Monetization.start()` runs once, from `HomeShell`, so never during onboarding.

1. The cached `ad_free` setting is read before the first frame: no ad flashes.
2. The store is asked, for 5 seconds at most. A definite answer replaces the cached one; no answer keeps it.
3. Ad-free: stop here. The consent form and the ads SDK are never touched.
4. Otherwise: the price is read, consent is gathered, and the SDK starts only if ads may be requested.

| Phase | Slots | Meaning |
| --- | --- | --- |
| `starting` | Space reserved, nothing loaded | Waiting for the store and consent |
| `ready` | Ads load | Consent resolved, SDK started |
| `off` | No slot | Ad-free, no consent, consent failed, or no ad unit IDs in this build |

If consent cannot be resolved and there is no answer from a previous session, no ad is requested.

## Placements

| Slot | File | Behavior |
| --- | --- | --- |
| Banner | [ad_banner_slot.dart](../lib/features/monetization/ad_banner_slot.dart) | Above the floating bar, with a discreet *Remove ads* link. Its space stays when no ad comes, so nothing moves. One more try after 60 s. |
| Native card | [native_ad_card.dart](../lib/features/monetization/native_ad_card.dart) | Tile shape and border before the Trash tile, labeled *Ad*, neutral colors, small native template. Space reserved while loading, given back if no ad comes or the width is under 320 dp. |

## Ad before a manual slideshow

Asked by the product owner on 2026-11-05, which amends the brief's ban on interstitials.

- **When**: after *Start* in the options sheet of a manual slideshow (album page, selection, period). Never before a memory, a ritual or a saved slideshow, never during a slideshow.
- **How often**: at most every 5 minutes. The count restarts with the app.
- **No waiting**: the ad is loaded in advance. If none is ready, or it fails, the slideshow starts at once.
- **Length**: not set by the app. Google decides when the ad can be closed, and test ads may not reflect real ones. To avoid videos, choose a display-only type on the ad unit if AdMob offers it.

## Purchase

- **Product**: `remove_ads`, non-consumable, €4.99 set in the Play Console. The app shows only the store's localized price.
- **Acknowledged** when bought and at each launch if still pending, since Google Play refunds unacknowledged purchases after 3 days.
- **Restored** by the check at each launch and by Settings → *Restore purchase*, so it follows the Google account.
- **Refund**: ads return at the next launch or restore, when the store says the product is not owned.
- **States**: pending, cancelled, error and already owned each give a message.

There is no server, so purchases are not verified by a backend. Editing the local database on a rooted phone could remove ads; accepted for this price.

## Where it is offered

- Settings → *Ads*: *Remove ads — {price}*, or *Ad-free ✓* once bought.
- The link next to the banner.
- At most once ever: a sheet after more than 500 MB was **deleted for good from the Trash screen**, only with a store price. It is recorded as shown when it opens.

Moving items to the trash does not trigger it, since no space is freed yet; neither does the expired trash offered at launch.

## Consent

Google's UMP asks at launch when the law requires it. Settings → *Privacy & ad choices* reopens the form when UMP says it is required. Withdrawing consent removes the slots at once. A user who refuses personalization gets the limited or non-personalized ads that UMP's answer allows.

## Set up outside the code

Needed before ads or the purchase can work for real; all are the product owner's accounts.

1. **AdMob**: create the app and three ad units, banner, native and interstitial; publish a GDPR message under *Privacy & messaging*.
2. **Play Console**: create the product `remove_ads` at €4.99, add license testers, upload a build to a testing track. Billing does not work on a build that Play does not know.
3. **Build** with the real IDs, which are never committed:

```sh
flutter build appbundle --release \
  --dart-define=ADMOB_BANNER_UNIT_ID=ca-app-pub-xxx/yyy \
  --dart-define=ADMOB_NATIVE_UNIT_ID=ca-app-pub-xxx/zzz \
  --dart-define=ADMOB_INTERSTITIAL_UNIT_ID=ca-app-pub-xxx/vvv \
  -PadmobAppId=ca-app-pub-xxx~www
```

Debug and profile builds use Google's test units. A release build without IDs has no ads, no consent form and no *Ads* section.

## Permissions added by the SDKs

Merged into the manifest without being declared by the app. None gives access to photos.

| Permission | From |
| --- | --- |
| `com.android.vending.BILLING` | Billing |
| `com.google.android.gms.permission.AD_ID` | Ads: advertising ID |
| `ACCESS_ADSERVICES_AD_ID`, `ACCESS_ADSERVICES_ATTRIBUTION`, `ACCESS_ADSERVICES_TOPICS` | Ads: Android's Privacy Sandbox |
| `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `FOREGROUND_SERVICE` | Ads and Google libraries |

They must be reflected in the *Data safety* form and the *Contains ads* declaration (`docs/release.md`, M12).

## Tests

- [monetization_test.dart](../test/features/monetization/monetization_test.dart): launch order, purchase states, restore, refund, offline, placements, the offer, Settings.
- [dependency_rules_test.dart](../test/architecture/dependency_rules_test.dart): SDKs only behind interfaces, the two placements, no forbidden format, empty requests.
- On a device: [testing.md](testing.md#m11--monetization-to-verify-on-a-device).

## Known limitations

- The native template draws its text in the system font, not Manrope. A native factory in Kotlin could match it if the look is not good enough.
- A purchase stops the slots at once, but the SDK stays loaded until the app is closed.
- The price stays hidden until the next launch if the store did not answer.
