# ADR 0032 — Open source, without ads

Why the ads and the *Remove ads* purchase were taken out, and what that changes for the release.

Last updated: 2026-11-08 — Open source

- **Status**: Accepted
- **Date**: 2026-11-08
- **Supersedes**: [ADR 0030](0030-ads-and-purchase.md)

## Context

M11 added three ad placements (a banner in Albums, a native card in Stats, an interstitial before a manual slideshow), Google's consent form and a non-consumable *Remove ads* purchase. It was merged on 2026-11-08 and tried on the phone, but the purchase never ran for real: it needed AdMob and Play Console setup that was not done yet.

The same day, the product owner asked to remove the whole ad side and release the app as open source instead.

## Decision

- **No ads, no purchase**: the ads and billing code, its two platform interfaces, the settings it cached (`ad_free`, `remove_ads_offer_shown`), its strings and its three packages (`google_mobile_ads`, `in_app_purchase`, `in_app_purchase_android`) are removed. The AdMob application ID leaves the manifest and the Gradle file; so does the rule removing the ads SDK's Topics permission, which no longer comes in.
- **Nothing replaces them**: no analytics, tracking or crash-reporting SDK either. A test fails if one of these packages comes back.
- **Open source under the GNU GPL v3** (product owner, 2026-11-08): `LICENSE` holds the license text, the README says so. Anyone may change and redistribute the app, and versions they distribute must stay under the GPL with their source.
- **Privacy policy in the repository**: [PRIVACY.md](../../PRIVACY.md), French and English, rewritten without ads or purchase. The published page must match it.
- The rule against secrets in the source stays, and matters more in a public repository: signing keys stay out of it.

## Consequences

- Without the ads SDK, the app needs only `INTERNET` for the map's tiles, and the APK no longer carries Google's ads and WebView libraries.
- Old installs keep two unused rows in the `settings` table; nothing reads them, and no migration is needed.
- M12's release checklist changes: the Play Console declares *No ads*, the *Data safety* form has no advertising ID, and there is no in-app product. The published privacy policy is replaced by the text of `PRIVACY.md`.
- Licenses of bundled content are now checked against open-source distribution rather than "an app with ads". For People ([ADR 0029](0029-face-model.md)), the question becomes whether the model licenses allow redistribution in an open-source app; it is not settled by this change.
- F-Droid becomes possible once the app has no proprietary dependency; it is not decided.
