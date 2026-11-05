/// What the store reports about a purchase in progress.
enum PurchaseUpdate {
  /// Waiting for a payment that takes time, such as cash at a shop.
  pending,

  /// Paid. The purchase has been acknowledged.
  purchased,

  /// The user left the purchase screen.
  cancelled,

  /// The store reported an error.
  failed,

  /// The account already owns the product.
  alreadyOwned,
}

/// The single non-consumable product of the app, `remove_ads`.
///
/// See `docs/monetization.md`.
abstract interface class PurchaseService {
  /// Updates of purchases started with [buyRemoveAds].
  Stream<PurchaseUpdate> get updates;

  /// The price in the store's own format, or `null` when the store or the
  /// product is unavailable. Never hard-code a price.
  Future<String?> removeAdsPrice();

  /// Whether the account owns the product, or `null` when the store could
  /// not say (offline, for example): keep the cached answer then.
  ///
  /// Acknowledges a purchase that was not, since Google Play refunds those
  /// after 3 days.
  Future<bool?> ownsRemoveAds();

  /// Opens the store's purchase screen. Returns `false` when it could not
  /// be opened; the outcome otherwise comes through [updates].
  Future<bool> buyRemoveAds();

  /// Stops listening to the store.
  Future<void> dispose();
}
