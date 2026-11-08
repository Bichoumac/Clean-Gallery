import 'dart:async';

import 'package:clean_gallery/platform/purchase_service.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// [PurchaseService] on Google Play Billing.
final class AndroidPurchaseService implements PurchaseService {
  /// Creates the service and starts listening to the store.
  AndroidPurchaseService() {
    _subscription = _store.purchaseStream.listen(
      (purchases) => unawaited(_onPurchases(purchases)),
      onError: (Object _) => _updates.add(PurchaseUpdate.failed),
    );
  }

  /// Product ID in the Play Console. Not a secret.
  static const _productId = 'remove_ads';

  final InAppPurchase _store = InAppPurchase.instance;
  final _updates = StreamController<PurchaseUpdate>.broadcast();
  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  @override
  Stream<PurchaseUpdate> get updates => _updates.stream;

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      // The store reports cancellations and errors with an empty product ID.
      switch (purchase.status) {
        case PurchaseStatus.canceled:
          _updates.add(PurchaseUpdate.cancelled);
        case PurchaseStatus.error:
          _updates.add(
            purchase.error?.message.contains('itemAlreadyOwned') ?? false
                ? PurchaseUpdate.alreadyOwned
                : PurchaseUpdate.failed,
          );
        case PurchaseStatus.pending:
          if (purchase.productID == _productId) {
            _updates.add(PurchaseUpdate.pending);
          }
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.productID != _productId) continue;
          final acknowledged = await _acknowledge(purchase);
          // An acknowledgment that failed is tried again at the next launch.
          _updates.add(
            acknowledged ? PurchaseUpdate.purchased : PurchaseUpdate.failed,
          );
      }
    }
  }

  Future<bool> _acknowledge(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return true;
    try {
      await _store.completePurchase(purchase);
      return true;
    } on Exception {
      return false;
    }
  }

  Future<ProductDetails?> _product() async {
    try {
      if (!await _store.isAvailable()) return null;
      final response = await _store.queryProductDetails({_productId});
      return response.productDetails
          .where((product) => product.id == _productId)
          .firstOrNull;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<String?> removeAdsPrice() async => (await _product())?.price;

  @override
  Future<bool?> ownsRemoveAds() async {
    try {
      if (!await _store.isAvailable()) return null;
      final response = await _store
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
          .queryPastPurchases();
      if (response.error != null) return null;
      final owned = response.pastPurchases.where(
        (purchase) =>
            purchase.productID == _productId &&
            (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored),
      );
      for (final purchase in owned) {
        await _acknowledge(purchase);
      }
      return owned.isNotEmpty;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<bool> buyRemoveAds() async {
    final product = await _product();
    if (product == null) return false;
    try {
      return await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription.cancel();
    await _updates.close();
  }
}
