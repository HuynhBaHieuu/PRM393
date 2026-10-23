import 'package:all_fits/core/constants/app_config.dart';

/// The user's plan. Premium is simulated: upgrading takes no payment.
enum SubscriptionPlan {
  free('Free'),
  premium('Premium');

  const SubscriptionPlan(this.label);

  final String label;

  bool get isPremium => this == SubscriptionPlan.premium;

  /// Most clothing items the plan can hold, or null for no limit.
  int? get wardrobeLimit => isPremium ? null : AppConfig.freeWardrobeLimit;

  /// AI Stylist messages the plan can send per day, or null for no limit.
  int? get stylistMessagesPerDay =>
      isPremium ? null : AppConfig.freeStylistMessagesPerDay;

  /// Most collections the plan can hold, or null for no limit.
  int? get collectionLimit => isPremium ? null : AppConfig.freeCollectionLimit;

  /// Whether a wardrobe of [itemCount] pieces has room for one more.
  bool canAddItem(int itemCount) {
    final limit = wardrobeLimit;
    return limit == null || itemCount < limit;
  }

  /// Whether [collectionCount] collections leave room for one more. After
  /// Premium ends, existing collections stay; only new ones are blocked.
  bool canAddCollection(int collectionCount) {
    final limit = collectionLimit;
    return limit == null || collectionCount < limit;
  }
}
