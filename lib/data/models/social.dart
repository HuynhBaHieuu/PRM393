import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/outfit_placement.dart';

// Records shared between accounts. They come from the functions in
// supabase/schema.sql, which use snake_case keys and never include price,
// notes or wear history.

enum FollowStatus { pending, accepted }

/// Someone's public profile. [isPrivate] limits their closet to accepted
/// followers; [allowStyling] lets others make outfits from it.
class SocialProfile {
  const SocialProfile({
    required this.userId,
    required this.username,
    this.displayName = '',
    this.bio = '',
    this.avatarUrl,
    this.isPrivate = false,
    this.allowStyling = true,
  });

  factory SocialProfile.fromJson(JsonMap json) {
    final userId = JsonReader.nonEmptyString(json, 'user_id');
    final username = JsonReader.nonEmptyString(json, 'username');
    if (userId == null || username == null) {
      throw const FormatException('Profile is missing an id or username');
    }
    return SocialProfile(
      userId: userId,
      username: username,
      displayName: JsonReader.string(json, 'display_name') ?? '',
      bio: JsonReader.string(json, 'bio') ?? '',
      avatarUrl: JsonReader.nonEmptyString(json, 'avatar_url'),
      isPrivate: JsonReader.boolean(json, 'is_private'),
      allowStyling: JsonReader.boolean(json, 'allow_styling', fallback: true),
    );
  }

  final String userId;
  final String username;
  final String displayName;
  final String bio;
  final String? avatarUrl;
  final bool isPrivate;
  final bool allowStyling;

  /// The name to show: the display name, or the username without one.
  String get name => displayName.isEmpty ? username : displayName;

  JsonMap toRow() => {
    'user_id': userId,
    'username': username,
    'display_name': displayName,
    'bio': bio,
    'avatar_url': avatarUrl,
    'is_private': isPrivate,
    'allow_styling': allowStyling,
  };

  SocialProfile copyWith({
    String? username,
    String? displayName,
    String? bio,
    String? avatarUrl,
    bool? isPrivate,
    bool? allowStyling,
  }) => SocialProfile(
    userId: userId,
    username: username ?? this.username,
    displayName: displayName ?? this.displayName,
    bio: bio ?? this.bio,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    isPrivate: isPrivate ?? this.isPrivate,
    allowStyling: allowStyling ?? this.allowStyling,
  );
}

/// A profile as the signed-in user sees it.
class ProfileSummary {
  const ProfileSummary({
    required this.profile,
    this.followers = 0,
    this.following = 0,
    this.myFollow,
    this.followsMe = false,
    this.blockedByMe = false,
    this.canViewCloset = false,
    this.canStyle = false,
  });

  factory ProfileSummary.fromJson(JsonMap json) => ProfileSummary(
    profile: SocialProfile.fromJson(_map(json['profile'])),
    followers: JsonReader.integer(json, 'followers'),
    following: JsonReader.integer(json, 'following'),
    myFollow: JsonReader.enumValue(FollowStatus.values, json['my_follow']),
    followsMe: JsonReader.boolean(json, 'follows_me'),
    blockedByMe: JsonReader.boolean(json, 'blocked_by_me'),
    canViewCloset: JsonReader.boolean(json, 'can_view_closet'),
    canStyle: JsonReader.boolean(json, 'can_style'),
  );

  final SocialProfile profile;
  final int followers;
  final int following;

  /// Whether the signed-in user follows this profile, or asked to.
  final FollowStatus? myFollow;
  final bool followsMe;
  final bool blockedByMe;
  final bool canViewCloset;
  final bool canStyle;
}

/// What others may see of someone's closet.
class PublicCloset {
  const PublicCloset({this.items = const [], this.outfits = const []});

  factory PublicCloset.fromJson(JsonMap json) => PublicCloset(
    items: parseRecords(json['items'], ClothingItem.fromJson),
    outfits: parseRecords(json['outfits'], Outfit.fromJson),
  );

  final List<ClothingItem> items;
  final List<Outfit> outfits;

  List<ClothingItem> itemsOf(Outfit outfit) {
    final byId = {for (final item in items) item.id: item};
    return [for (final id in outfit.itemIds) ?byId[id]];
  }
}

enum FeedFilter {
  latest('Latest'),
  following('Following'),
  saved('Saved');

  const FeedFilter(this.label);

  final String label;
}

/// An outfit someone shared on Discover, with its pieces.
class FeedPost {
  const FeedPost({
    required this.owner,
    required this.outfit,
    required this.items,
    required this.postedAt,
    this.saved = false,
  });

  factory FeedPost.fromJson(JsonMap json) {
    final postedAt = JsonReader.date(json, 'posted_at');
    if (postedAt == null) throw const FormatException('Post has no date');
    return FeedPost(
      owner: SocialProfile.fromJson(_map(json['owner'])),
      outfit: Outfit.fromJson(_map(json['outfit'])),
      items: parseRecords(json['items'], ClothingItem.fromJson),
      postedAt: postedAt,
      saved: JsonReader.boolean(json, 'saved'),
    );
  }

  final SocialProfile owner;
  final Outfit outfit;
  final List<ClothingItem> items;
  final DateTime postedAt;
  final bool saved;

  /// Pieces in the outfit's order.
  List<ClothingItem> get orderedItems {
    final byId = {for (final item in items) item.id: item};
    return [for (final id in outfit.itemIds) ?byId[id]];
  }

  FeedPost copyWith({bool? saved}) => FeedPost(
    owner: owner,
    outfit: outfit,
    items: items,
    postedAt: postedAt,
    saved: saved ?? this.saved,
  );
}

enum StyledStatus { pending, saved, dismissed }

/// An outfit made from the recipient's clothes by someone else. [incoming]
/// is true when the signed-in user is the recipient; [other] is whoever is
/// on the other side.
class StyledOutfit {
  const StyledOutfit({
    required this.id,
    required this.other,
    required this.incoming,
    required this.itemIds,
    required this.items,
    required this.createdAt,
    this.name,
    this.message,
    this.layout = const [],
    this.status = StyledStatus.pending,
  });

  factory StyledOutfit.fromJson(JsonMap json) {
    final id = JsonReader.nonEmptyString(json, 'id');
    final createdAt = JsonReader.date(json, 'created_at');
    if (id == null || createdAt == null) {
      throw const FormatException('Styled outfit is missing an id or date');
    }
    final data = _map(json['data']);
    return StyledOutfit(
      id: id,
      other: SocialProfile.fromJson(_map(json['other'])),
      incoming: JsonReader.boolean(json, 'incoming'),
      name: JsonReader.nonEmptyString(data, 'name'),
      message: JsonReader.nonEmptyString(data, 'message'),
      itemIds: JsonReader.stringList(data, 'itemIds'),
      layout: [
        if (data['layout'] case final List<dynamic> raw)
          ...raw.map(OutfitPlacement.tryFromJson).whereType<OutfitPlacement>(),
      ],
      items: parseRecords(data['items'], ClothingItem.fromJson),
      status:
          JsonReader.enumValue(StyledStatus.values, json['status']) ??
          StyledStatus.pending,
      createdAt: createdAt,
    );
  }

  final String id;
  final SocialProfile other;
  final bool incoming;
  final String? name;
  final String? message;
  final List<String> itemIds;
  final List<OutfitPlacement> layout;

  /// The pieces as they were when sent.
  final List<ClothingItem> items;
  final StyledStatus status;
  final DateTime createdAt;

  bool get isPending => status == StyledStatus.pending;

  List<ClothingItem> get orderedItems {
    final byId = {for (final item in items) item.id: item};
    return [for (final id in itemIds) ?byId[id]];
  }
}

/// A follow between the signed-in user and [profile]. [isFollower] means
/// [profile] follows (or asked to follow) the signed-in user.
class Connection {
  const Connection({
    required this.profile,
    required this.isFollower,
    required this.status,
  });

  factory Connection.fromJson(JsonMap json) => Connection(
    profile: SocialProfile.fromJson(_map(json['profile'])),
    isFollower: JsonReader.boolean(json, 'follower'),
    status:
        JsonReader.enumValue(FollowStatus.values, json['status']) ??
        FollowStatus.pending,
  );

  final SocialProfile profile;
  final bool isFollower;
  final FollowStatus status;

  bool get isAccepted => status == FollowStatus.accepted;
}

JsonMap _map(Object? raw) {
  if (raw is Map) return JsonMap.from(raw);
  throw const FormatException('Expected an object');
}

/// Parses each entry of a JSON list, skipping malformed ones.
List<T> parseRecords<T>(Object? raw, T Function(JsonMap json) fromJson) {
  if (raw is! List) return const [];
  final values = <T>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    try {
      values.add(fromJson(JsonMap.from(entry)));
    } on FormatException {
      // Skip it; one bad record shouldn't hide the rest.
    }
  }
  return values;
}
