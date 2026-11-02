import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/outfit_placement.dart';
import 'package:all_fits/data/models/social.dart';

/// Profiles, follows, Community and outfits made for others. Only exists with
/// a Supabase account; who may see what is enforced by supabase/schema.sql.
abstract class SocialRepository {
  /// The signed-in user's profile, or null before they create one.
  Future<SocialProfile?> myProfile();

  /// Creates or updates the signed-in user's profile.
  Future<SocialProfile> saveProfile(SocialProfile profile);

  Future<bool> isUsernameAvailable(String username);

  /// Everyone else who has a profile, by username. Profiles across a block
  /// are left out by the `profiles` read policy.
  Future<List<SocialProfile>> people();

  /// Null when the profile doesn't exist or its owner blocked the caller.
  Future<ProfileSummary?> summary(String userId);

  /// Null when the caller may not see this closet.
  Future<PublicCloset?> closet(String userId);

  Future<FollowStatus> follow(String userId);

  /// Stops following [userId], or withdraws a request.
  Future<void> unfollow(String userId);

  /// Removes a follower, or declines their request.
  Future<void> removeFollower(String userId);

  Future<void> acceptFollower(String userId);

  Future<List<Connection>> connections();

  Future<void> block(String userId);

  Future<void> unblock(String userId);

  Future<List<SocialProfile>> blockedUsers();

  Future<void> report(
    String userId, {
    required String reason,
    String? outfitId,
  });

  /// Ids of the signed-in user's outfits shown on Discover.
  Future<Set<String>> postedOutfitIds();

  Future<void> setPosted(String outfitId, {required bool posted});

  /// One page of Community > Outfits, starting after the first [offset].
  Future<List<FeedPost>> feed(FeedFilter filter, {int offset = 0});

  Future<void> setLiked(FeedPost post, {required bool liked});

  /// One page of other people's public pieces, newest first, narrowed to
  /// [category] and to names or brands containing [query].
  Future<List<CommunityItem>> communityItems({
    ClothingCategory? category,
    String query = '',
    int offset = 0,
  });

  /// One piece with its counts; null when the caller may not see it.
  Future<CommunityItem?> communityItem(String ownerId, String itemId);

  Future<void> setItemLiked(CommunityItem item, {required bool liked});

  /// Counts [item] as added to the signed-in user's wardrobe.
  Future<void> recordItemCopy(CommunityItem item);

  /// Comments under [item], oldest first.
  Future<List<PostComment>> itemComments(CommunityItem item);

  Future<PostComment> addItemComment(CommunityItem item, String body);

  /// Deletes a comment the signed-in user wrote, or one on their own piece.
  Future<void> deleteItemComment(String commentId);

  /// One page of people the signed-in user doesn't follow yet.
  Future<List<SuggestedPerson>> suggestedPeople({int offset = 0});

  /// Comments under [post], oldest first.
  Future<List<PostComment>> comments(FeedPost post);

  Future<PostComment> addComment(FeedPost post, String body);

  /// Deletes a comment the signed-in user wrote, or one on their own post.
  Future<void> deleteComment(String commentId);

  /// Likes and comments others left on the signed-in user's posts.
  Future<PostActivityFeed> postActivity();

  /// Marks everything in [postActivity] as seen.
  Future<void> markActivitySeen();

  Future<void> sendStyledOutfit({
    required String recipientId,
    required List<String> itemIds,
    required List<OutfitPlacement> layout,
    String? name,
    String? message,
  });

  Future<List<StyledOutfit>> styledOutfits();

  Future<void> answerStyledOutfit(String id, StyledStatus status);

  Future<void> deleteStyledOutfit(String id);
}

class SupabaseSocialRepository implements SocialRepository {
  SupabaseSocialRepository(this._client, this._userId);

  // ponytail: the whole list is loaded and searched on the phone; page it and
  // search on the server once there are more people than this.
  static const int _peopleLimit = 500;

  final sb.SupabaseClient _client;
  final String _userId;

  @override
  Future<SocialProfile?> myProfile() => _guard(() async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();
    return row == null ? null : SocialProfile.fromJson(row);
  });

  @override
  Future<SocialProfile> saveProfile(SocialProfile profile) => _guard(() async {
    final before = await myProfile();
    final row = await _client
        .from('profiles')
        .upsert({
          ...profile.toRow(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();
    if (before != null && before.isPrivate && !profile.isPrivate) {
      // A public account has no requests to approve.
      await _client
          .from('follows')
          .update({'status': FollowStatus.accepted.name})
          .eq('followee_id', _userId)
          .eq('status', FollowStatus.pending.name);
    }
    return SocialProfile.fromJson(row);
  });

  @override
  Future<bool> isUsernameAvailable(String username) => _guard(() async {
    final row = await _client
        .from('profiles')
        .select('user_id')
        .eq('username', username)
        .maybeSingle();
    return row == null || row['user_id'] == _userId;
  });

  @override
  Future<List<SocialProfile>> people() => _guard(() async {
    final rows = await _client
        .from('profiles')
        .select()
        .neq('user_id', _userId)
        .order('username')
        .limit(_peopleLimit);
    return rows.map(SocialProfile.fromJson).toList();
  });

  @override
  Future<ProfileSummary?> summary(String userId) => _guard(() async {
    final json = await _rpc('profile_summary', {'p_user': userId});
    return json is Map ? ProfileSummary.fromJson(JsonMap.from(json)) : null;
  });

  @override
  Future<PublicCloset?> closet(String userId) => _guard(() async {
    final json = await _rpc('profile_closet', {'p_user': userId});
    return json is Map ? PublicCloset.fromJson(JsonMap.from(json)) : null;
  });

  @override
  Future<FollowStatus> follow(String userId) => _guard(() async {
    final status = await _rpc('follow_user', {'p_target': userId});
    return JsonReader.enumValue(FollowStatus.values, status) ??
        FollowStatus.pending;
  });

  @override
  Future<void> unfollow(String userId) => _guard(
    () => _client
        .from('follows')
        .delete()
        .eq('follower_id', _userId)
        .eq('followee_id', userId),
  );

  @override
  Future<void> removeFollower(String userId) => _guard(
    () => _client
        .from('follows')
        .delete()
        .eq('follower_id', userId)
        .eq('followee_id', _userId),
  );

  @override
  Future<void> acceptFollower(String userId) => _guard(
    () => _client
        .from('follows')
        .update({'status': FollowStatus.accepted.name})
        .eq('follower_id', userId)
        .eq('followee_id', _userId),
  );

  @override
  Future<List<Connection>> connections() => _guard(
    () async => parseRecords(await _rpc('my_connections'), Connection.fromJson),
  );

  @override
  Future<void> block(String userId) =>
      _guard(() => _rpc('block_user', {'p_target': userId}));

  @override
  Future<void> unblock(String userId) => _guard(
    () => _client
        .from('blocks')
        .delete()
        .eq('blocker_id', _userId)
        .eq('blocked_id', userId),
  );

  @override
  Future<List<SocialProfile>> blockedUsers() => _guard(
    () async =>
        parseRecords(await _rpc('blocked_profiles'), SocialProfile.fromJson),
  );

  @override
  Future<void> report(
    String userId, {
    required String reason,
    String? outfitId,
  }) => _guard(
    () => _client.from('reports').insert({
      'reporter_id': _userId,
      'target_id': userId,
      'outfit_id': outfitId,
      'reason': reason,
    }),
  );

  @override
  Future<Set<String>> postedOutfitIds() => _guard(() async {
    final rows = await _client
        .from('outfit_posts')
        .select('outfit_id')
        .eq('user_id', _userId);
    return {for (final row in rows) row['outfit_id'] as String};
  });

  @override
  Future<void> setPosted(String outfitId, {required bool posted}) =>
      _guard(() async {
        if (posted) {
          await _client.from('outfit_posts').upsert({
            'user_id': _userId,
            'outfit_id': outfitId,
          }, ignoreDuplicates: true);
        } else {
          await _client
              .from('outfit_posts')
              .delete()
              .eq('user_id', _userId)
              .eq('outfit_id', outfitId);
        }
      });

  @override
  Future<List<FeedPost>> feed(FeedFilter filter, {int offset = 0}) =>
      _guard(() async {
        final json = await _rpc('community_outfits', {
          'p_filter': filter.name,
          'p_offset': offset,
        });
        return parseRecords(json, FeedPost.fromJson);
      });

  @override
  Future<List<CommunityItem>> communityItems({
    ClothingCategory? category,
    String query = '',
    int offset = 0,
  }) => _guard(() async {
    final json = await _rpc('community_items', {
      'p_category': category?.name,
      'p_query': query.trim(),
      'p_offset': offset,
    });
    return parseRecords(json, CommunityItem.fromJson);
  });

  @override
  Future<CommunityItem?> communityItem(String ownerId, String itemId) =>
      _guard(() async {
        final json = await _rpc('community_item', {
          'p_owner': ownerId,
          'p_item': itemId,
        });
        return json is Map ? CommunityItem.fromJson(JsonMap.from(json)) : null;
      });

  @override
  Future<void> setItemLiked(CommunityItem item, {required bool liked}) =>
      _guard(() async {
        final row = _itemRow(item);
        if (liked) {
          await _client.from('item_likes').upsert(row, ignoreDuplicates: true);
        } else {
          await _client.from('item_likes').delete().match(row);
        }
      });

  @override
  Future<void> recordItemCopy(CommunityItem item) => _guard(
    () => _client
        .from('item_copies')
        .upsert(_itemRow(item), ignoreDuplicates: true),
  );

  @override
  Future<List<PostComment>> itemComments(CommunityItem item) => _guard(
    () async => parseRecords(
      await _rpc('item_comments_list', {
        'p_owner': item.owner.userId,
        'p_item': item.item.id,
      }),
      PostComment.fromJson,
    ),
  );

  @override
  Future<PostComment> addItemComment(CommunityItem item, String body) =>
      _guard(() async {
        final json = await _rpc('add_item_comment', {
          'p_owner': item.owner.userId,
          'p_item': item.item.id,
          'p_body': body,
        });
        return PostComment.fromJson(JsonMap.from(json as Map));
      });

  @override
  Future<void> deleteItemComment(String commentId) =>
      _guard(() => _client.from('item_comments').delete().eq('id', commentId));

  @override
  Future<List<SuggestedPerson>> suggestedPeople({int offset = 0}) => _guard(
    () async => parseRecords(
      await _rpc('suggested_people', {'p_offset': offset}),
      SuggestedPerson.fromJson,
    ),
  );

  Map<String, String> _itemRow(CommunityItem item) => {
    'user_id': _userId,
    'owner_id': item.owner.userId,
    'item_id': item.item.id,
  };

  @override
  Future<void> setLiked(FeedPost post, {required bool liked}) =>
      _guard(() async {
        final row = {
          'user_id': _userId,
          'owner_id': post.owner.userId,
          'outfit_id': post.outfit.id,
        };
        if (liked) {
          await _client.from('post_likes').upsert(row, ignoreDuplicates: true);
        } else {
          await _client.from('post_likes').delete().match(row);
        }
      });

  @override
  Future<List<PostComment>> comments(FeedPost post) => _guard(
    () async => parseRecords(
      await _rpc('post_comments_list', {
        'p_owner': post.owner.userId,
        'p_outfit': post.outfit.id,
      }),
      PostComment.fromJson,
    ),
  );

  @override
  Future<PostComment> addComment(FeedPost post, String body) =>
      _guard(() async {
        final json = await _rpc('add_post_comment', {
          'p_owner': post.owner.userId,
          'p_outfit': post.outfit.id,
          'p_body': body,
        });
        return PostComment.fromJson(JsonMap.from(json as Map));
      });

  @override
  Future<void> deleteComment(String commentId) =>
      _guard(() => _client.from('post_comments').delete().eq('id', commentId));

  @override
  Future<PostActivityFeed> postActivity() => _guard(() async {
    final json = await _rpc('post_activity');
    return json is Map
        ? PostActivityFeed.fromJson(JsonMap.from(json))
        : const PostActivityFeed();
  });

  @override
  Future<void> markActivitySeen() => _guard(() => _rpc('mark_activity_seen'));

  @override
  Future<void> sendStyledOutfit({
    required String recipientId,
    required List<String> itemIds,
    required List<OutfitPlacement> layout,
    String? name,
    String? message,
  }) => _guard(
    () => _rpc('send_styled_outfit', {
      'p_recipient': recipientId,
      'p_name': name ?? '',
      'p_message': message ?? '',
      'p_item_ids': itemIds,
      'p_layout': [for (final p in layout) p.toJson()],
    }),
  );

  @override
  Future<List<StyledOutfit>> styledOutfits() => _guard(
    () async =>
        parseRecords(await _rpc('styled_outfits_list'), StyledOutfit.fromJson),
  );

  @override
  Future<void> answerStyledOutfit(String id, StyledStatus status) => _guard(
    () => _client
        .from('styled_outfits')
        .update({'status': status.name})
        .eq('id', id),
  );

  @override
  Future<void> deleteStyledOutfit(String id) =>
      _guard(() => _client.from('styled_outfits').delete().eq('id', id));

  Future<dynamic> _rpc(String function, [Map<String, dynamic>? params]) =>
      _client.rpc(function, params: params);

  /// Maps server errors to messages people can act on.
  Future<R> _guard<R>(Future<R> Function() request) async {
    try {
      return await request();
    } on sb.PostgrestException catch (error) {
      developer.log('Social request failed', name: 'social', error: error);
      throw SocialException(switch (error.code) {
        // `raise exception` in schema.sql: already written for people.
        'P0001' => error.message,
        '23505' => 'This username is taken.',
        _ => 'Couldn’t reach the community. Please try again.',
      });
    } on AppException {
      rethrow;
    } catch (error) {
      developer.log('Social request failed', name: 'social', error: error);
      throw const SocialException(
        'Couldn’t reach the community. Please try again.',
      );
    }
  }
}
