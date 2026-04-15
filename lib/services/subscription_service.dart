import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// サブスクリプション商品ID
/// ※ App Store Connect / Google Play Console で設定するIDと一致させること
class SubscriptionIds {
  static const String monthly = 'ponpoko_premium_monthly'; // 月額 ¥400
  static const String annual = 'ponpoko_premium_annual';   // 年額 ¥3,000
  static const Set<String> all = {monthly, annual};
}

/// サブスクリプション状態
enum SubscriptionStatus {
  trial,        // トライアル中（無料）
  active,       // 有料サブスク有効
  expired,      // トライアル終了・未購入
  notAvailable, // 購入機能が利用不可
}

class SubscriptionService extends ChangeNotifier {
  static const String _installDateKey = 'install_date';
  static const String _subscriptionActiveKey = 'subscription_active';
  static const String _activeProductIdKey = 'active_product_id';
  static final int _trialDays = kDebugMode ? 9999 : 3; // デバッグ時は無制限、本番は3日

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;

  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  bool _subscriptionActive = false;
  String? _activeProductId;
  DateTime? _installDate;
  bool _isLoading = false;

  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => _products;
  bool get subscriptionActive => _subscriptionActive;
  bool get isLoading => _isLoading;

  ProductDetails? get monthlyProduct {
    try {
      return _products.firstWhere((p) => p.id == SubscriptionIds.monthly);
    } catch (_) {
      return null;
    }
  }

  ProductDetails? get annualProduct {
    try {
      return _products.firstWhere((p) => p.id == SubscriptionIds.annual);
    } catch (_) {
      return null;
    }
  }

  /// 現在のサブスクリプション状態
  SubscriptionStatus get status {
    if (!_isAvailable) return SubscriptionStatus.notAvailable;
    if (_subscriptionActive) return SubscriptionStatus.active;
    if (_isInTrial()) return SubscriptionStatus.trial;
    return SubscriptionStatus.expired;
  }

  /// カロリー分析機能が使えるか
  bool get canUseCalorieAnalysis {
    return status == SubscriptionStatus.active ||
        status == SubscriptionStatus.trial ||
        status == SubscriptionStatus.notAvailable; // 購入不可環境では無制限（シミュレーター等）
  }

  /// トライアル残り日数
  int get trialDaysRemaining {
    if (_installDate == null) return 0;
    final elapsed = DateTime.now().difference(_installDate!).inDays;
    final remaining = _trialDays - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// トライアル中かどうか
  bool _isInTrial() {
    if (_installDate == null) return false;
    final elapsed = DateTime.now().difference(_installDate!);
    return elapsed.inDays < _trialDays;
  }

  /// サービス初期化
  Future<void> init() async {
    await _loadPrefs();
    await _initIAP();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // 初回インストール日を記録
    final installDateStr = prefs.getString(_installDateKey);
    if (installDateStr == null) {
      _installDate = DateTime.now();
      await prefs.setString(_installDateKey, _installDate!.toIso8601String());
    } else {
      _installDate = DateTime.parse(installDateStr);
    }

    _subscriptionActive = prefs.getBool(_subscriptionActiveKey) ?? false;
    _activeProductId = prefs.getString(_activeProductIdKey);
  }

  Future<void> _initIAP() async {
    _isAvailable = await _iap.isAvailable();

    if (!_isAvailable) {
      debugPrint('[SubscriptionService] In-App Purchase not available');
      notifyListeners();
      return;
    }

    // 購入ストリームをリッスン
    _purchaseSubscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _purchaseSubscription.cancel(),
      onError: (error) => debugPrint('[SubscriptionService] Error: $error'),
    );

    // 商品情報を取得
    await _fetchProducts();

    // 未完了の購入を処理
    await _iap.restorePurchases();
  }

  Future<void> _fetchProducts() async {
    try {
      final response = await _iap.queryProductDetails(SubscriptionIds.all);
      if (response.error != null) {
        debugPrint('[SubscriptionService] Product query error: ${response.error}');
      }
      _products = response.productDetails;
      debugPrint('[SubscriptionService] Products loaded: ${_products.map((p) => p.id).toList()}');
      notifyListeners();
    } catch (e) {
      debugPrint('[SubscriptionService] Failed to fetch products: $e');
    }
  }

  /// 購入処理
  Future<bool> purchase(ProductDetails product) async {
    if (!_isAvailable) return false;

    try {
      _isLoading = true;
      notifyListeners();

      final purchaseParam = PurchaseParam(productDetails: product);
      bool result;

      // サブスクリプションとして購入
      result = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      return result;
    } catch (e) {
      debugPrint('[SubscriptionService] Purchase error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 購入の復元
  Future<void> restorePurchases() async {
    if (!_isAvailable) return;
    _isLoading = true;
    notifyListeners();
    await _iap.restorePurchases();
  }

  /// 購入状態の更新ハンドラ
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      await _handlePurchase(purchase);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    debugPrint('[SubscriptionService] Purchase update: ${purchase.productID}, status: ${purchase.status}');

    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      // 購入・復元成功
      if (SubscriptionIds.all.contains(purchase.productID)) {
        await _setSubscriptionActive(true, purchase.productID);
      }
    } else if (purchase.status == PurchaseStatus.error) {
      debugPrint('[SubscriptionService] Purchase error: ${purchase.error}');
    } else if (purchase.status == PurchaseStatus.canceled) {
      debugPrint('[SubscriptionService] Purchase canceled');
    }

    // 購入を完了としてマーク（必須）
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  Future<void> _setSubscriptionActive(bool active, String? productId) async {
    _subscriptionActive = active;
    _activeProductId = productId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_subscriptionActiveKey, active);
    if (productId != null) {
      await prefs.setString(_activeProductIdKey, productId);
    } else {
      await prefs.remove(_activeProductIdKey);
    }
    notifyListeners();
  }

  /// インストール日（デバッグ・テスト用）
  DateTime? get installDate => _installDate;

  /// テスト用：インストール日を強制リセット（デバッグビルドのみ）
  Future<void> resetTrialForDebug() async {
    if (!kDebugMode) return;
    final prefs = await SharedPreferences.getInstance();
    _installDate = DateTime.now();
    await prefs.setString(_installDateKey, _installDate!.toIso8601String());
    await prefs.setBool(_subscriptionActiveKey, false);
    await prefs.remove(_activeProductIdKey);
    _subscriptionActive = false;
    _activeProductId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_isAvailable) {
      _purchaseSubscription.cancel();
    }
    super.dispose();
  }
}
