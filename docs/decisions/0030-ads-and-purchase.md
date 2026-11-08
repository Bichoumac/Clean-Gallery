# ADR 0030 — Ads and purchase behind two interfaces

Which packages carry ads and billing, how they stay away from the rest of the app, and the choices the brief left open.

Last updated: 2026-11-05 — Milestone M11

- **Status**: Superseded by [ADR 0032](0032-open-source-without-ads.md) on 2026-11-08: the ads and the purchase were removed. This record and [monetization.md in the history](https://github.com/Bichoumac/Clean-Gallery/blob/80c471608c4cb98e67a21c59f4404ab6df0cb102/docs/monetization.md) describe what M11 built.
- **Date**: 2026-11-05

## Context

The brief asks for AdMob with UMP consent and a non-consumable purchase, restricted to two placements, with no media data reaching an SDK and no SDK started for an ad-free user.

## Decision

- `google_mobile_ads` for ads and consent, `in_app_purchase` and `in_app_purchase_android` for billing, each used in one file of `lib/platform/android/`, behind `AdsService` and `PurchaseService`.
- `Monetization`, a Riverpod controller, owns the launch order: store, then consent, then SDK. See [monetization.md](../monetization.md).
- **Banner**: the standard 320 × 50 dp, not adaptive. The SDK's current adaptive size can reach 15 % of the screen's height, and the product owner found it too big on the phone (2026-11-05). Adaptive banners may earn more.
- **Fail closed**: without an answer about consent, no ad is requested.
- **Native card**: Google's small native template, not a Kotlin native factory, so no layout is maintained on the native side.
- **The offer** comes after a deletion for good from the Trash screen, the moment space is really freed.
- **Ownership** is read with `queryPastPurchases`, which also reveals a refund, unlike a stream of restored purchases.

## Amendment: an interstitial before a manual slideshow

On 2026-11-05 the product owner asked for a quick ad before a slideshow started by hand. It reverses the brief's ban on interstitials and on ads around slideshows for this one case. It is kept narrow: manual launches only, at most every 5 minutes, loaded in advance so a slideshow never waits, and shown before the player so it never interrupts the photos or the music. The architecture test keeps every other full-screen ad out.

## Alternatives considered

- **A Kotlin native factory**: matches the app's font, but adds a layout and a channel for one card. Kept in reserve if the template looks wrong.
- **Waiting for a server check of purchases**: the app has no server and must not need one.
- **Collapsing the banner space when no ad comes**: moves the layout, which the brief forbids.

## Consequences

- Tests replace both services with fakes; the real SDKs only run on a device.
- The ads package brings `webview_flutter` and the permissions listed in [monetization.md](../monetization.md#permissions-added-by-the-sdks).
- The app's promise holds for media, but ads do use the network and the advertising ID; the store listing and the *Data safety* form must say so.
