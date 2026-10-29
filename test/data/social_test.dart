import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/extensions/string_extensions.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/data/models/outfit_placement.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/data/repositories/social_repository.dart';
import 'package:all_fits/features/social/screens/edit_profile_screen.dart';
import 'package:all_fits/features/social/screens/people_screens.dart';
import 'package:all_fits/features/social/social_controller.dart';

import '../helpers/test_harness.dart';

Map<String, dynamic> _card(
  String id,
  String username, {
  bool private = false,
}) => {
  'user_id': id,
  'username': username,
  'display_name': '',
  'avatar_url': null,
  'is_private': private,
};

Connection _connection(
  String id, {
  required bool follower,
  required bool accepted,
}) => Connection(
  profile: SocialProfile(userId: id, username: 'user_$id'),
  isFollower: follower,
  status: accepted ? FollowStatus.accepted : FollowStatus.pending,
);

StyledOutfit _styled(
  String id, {
  required bool incoming,
  StyledStatus status = StyledStatus.pending,
}) => StyledOutfit(
  id: id,
  other: const SocialProfile(userId: 'u2', username: 'mia'),
  incoming: incoming,
  itemIds: const ['a'],
  items: const [],
  status: status,
  createdAt: testNow,
);

class _FakeSocialRepository implements SocialRepository {
  List<Connection> connectionList = [];
  List<StyledOutfit> styledList = [];
  List<SocialProfile> peopleList = [];

  @override
  Future<SocialProfile?> myProfile() async =>
      const SocialProfile(userId: 'me', username: 'hieu');

  @override
  Future<List<Connection>> connections() async => connectionList;

  @override
  Future<List<SocialProfile>> people() async => peopleList;

  @override
  Future<List<StyledOutfit>> styledOutfits() async => styledList;

  @override
  Future<Set<String>> postedOutfitIds() async => {'o1'};

  @override
  Future<void> setPosted(String outfitId, {required bool posted}) async {}

  @override
  Future<void> acceptFollower(String userId) async {
    connectionList = [
      for (final c in connectionList)
        c.profile.userId == userId
            ? Connection(
                profile: c.profile,
                isFollower: c.isFollower,
                status: FollowStatus.accepted,
              )
            : c,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Validators.username (spec rule 5)', () {
    test('accepts lowercase letters, numbers, _ and . from 3 to 20 long', () {
      expect(Validators.username('hieu.huynh_05'), isNull);
      expect(Validators.username('abc'), isNull);
      expect(Validators.username('a' * 20), isNull);
    });

    test('rejects too short, too long, capitals, accents and spaces', () {
      expect(Validators.username('ab'), isNotNull);
      expect(Validators.username('a' * 21), isNotNull);
      expect(Validators.username('Hieu'), isNotNull);
      expect(Validators.username('hiếu'), isNotNull);
      expect(Validators.username('hieu huynh'), isNotNull);
      expect(Validators.username('hieu-huynh'), isNotNull);
    });

    test('suggestUsername cleans the sign-up handle or gives up', () {
      expect(suggestUsername('Hieu.Huynh+test'), 'hieu.huynhtest');
      expect(suggestUsername('x'), '');
      expect(suggestUsername('a' * 30).length, Validators.maxUsernameLength);
      expect(Validators.username(suggestUsername('Quan_MBA 007')), isNull);
    });
  });

  group('parsing server records', () {
    test('profile summary reads counts, follow state and permissions', () {
      final summary = ProfileSummary.fromJson({
        'profile': {
          ..._card('u2', 'zanzi', private: true),
          'bio': 'Brown everything',
          'allow_styling': false,
        },
        'followers': 1570,
        'following': 207,
        'my_follow': 'pending',
        'follows_me': true,
        'blocked_by_me': false,
        'can_view_closet': false,
        'can_style': false,
      });
      expect(summary.profile.username, 'zanzi');
      expect(summary.profile.isPrivate, isTrue);
      expect(summary.profile.allowStyling, isFalse);
      expect(summary.followers, 1570);
      expect(summary.myFollow, FollowStatus.pending);
      expect(summary.followsMe, isTrue);
      expect(summary.canViewCloset, isFalse);
    });

    test('feed post keeps outfit order and skips malformed pieces', () {
      final post = FeedPost.fromJson({
        'owner': _card('u2', 'zanzi'),
        'posted_at': '2026-10-01T09:00:00Z',
        'saved': true,
        'outfit': {
          'id': 'o1',
          'name': 'Brown layers',
          'itemIds': ['b', 'a', 'gone'],
        },
        'items': [
          {'id': 'a', 'name': 'Jacket', 'category': 'outerwear'},
          {'id': 'b', 'name': 'Shirt', 'category': 'tops'},
          {'name': 'No id'},
        ],
      });
      expect(post.saved, isTrue);
      expect(post.orderedItems.map((i) => i.id), ['b', 'a']);
      // The server never sends these; the model must not invent them.
      expect(
        post.items.every((i) => i.price == null && i.notes == null),
        isTrue,
      );
    });

    test('styled outfit reads message, layout and direction', () {
      final styled = StyledOutfit.fromJson({
        'id': 's1',
        'created_at': '2026-10-01T09:00:00Z',
        'status': 'saved',
        'incoming': true,
        'other': _card('u3', 'mia'),
        'data': {
          'message': 'For Friday',
          'itemIds': ['a'],
          'layout': [
            const OutfitPlacement(
              itemId: 'a',
              x: .5,
              y: .5,
              width: .4,
              height: .4,
            ).toJson(),
            {'itemId': 'bad'},
          ],
          'items': [
            {'id': 'a', 'name': 'Jacket', 'category': 'outerwear'},
          ],
        },
      });
      expect(styled.incoming, isTrue);
      expect(styled.status, StyledStatus.saved);
      expect(styled.message, 'For Friday');
      expect(styled.layout, hasLength(1));
      expect(styled.orderedItems.single.name, 'Jacket');
    });
  });

  group('SocialController', () {
    test('splits follows and counts what the bell shows', () async {
      final repository = _FakeSocialRepository()
        ..connectionList = [
          _connection('a', follower: true, accepted: true),
          _connection('b', follower: true, accepted: false),
          _connection('c', follower: false, accepted: true),
          _connection('d', follower: false, accepted: false),
        ]
        ..styledList = [
          _styled('s1', incoming: true),
          _styled('s2', incoming: true, status: StyledStatus.saved),
          _styled('s3', incoming: false),
        ];
      final social = SocialController(
        repository: repository,
        imageStorage: FakeImageStorageService(),
      );
      await social.load();

      expect(social.hasProfile, isTrue);
      expect(social.followers.map((c) => c.profile.userId), ['a']);
      expect(social.incomingRequests.map((c) => c.profile.userId), ['b']);
      expect(social.following.map((c) => c.profile.userId), ['c']);
      expect(social.sentRequests.map((c) => c.profile.userId), ['d']);
      expect(social.styledForMe, hasLength(2));
      expect(social.styledByMe, hasLength(1));
      expect(social.notificationCount, 2); // one request + one new outfit
      expect(social.isPosted('o1'), isTrue);

      await social.acceptFollower('b');
      expect(social.incomingRequests, isEmpty);
      expect(social.followers, hasLength(2));
      expect(social.notificationCount, 1);

      await social.setPosted('o1', posted: false);
      expect(social.isPosted('o1'), isFalse);
    });

    test('a failed load leaves the app usable', () async {
      final social = SocialController(
        repository: _BrokenRepository(),
        imageStorage: FakeImageStorageService(),
      );
      await social.load(); // must not throw
      expect(social.hasProfile, isFalse);
      expect(social.notificationCount, 0);
      expect(social.error, isNotNull);
    });
  });

  group('Find friends', () {
    test('folding drops Vietnamese accents and case', () {
      expect('Huỳnh Bá Hiếu'.folded, 'huynh ba hieu');
      expect('Đặng Thị Ưng'.folded, 'dang thi ung');
      expect('hieu_dev.05'.folded, 'hieu_dev.05');
    });

    testWidgets('lists everyone, then narrows by username or name', (
      tester,
    ) async {
      final repository = _FakeSocialRepository()
        ..peopleList = const [
          SocialProfile(
            userId: 'u1',
            username: 'huynhbahieu',
            displayName: 'Huỳnh Bá Hiếu',
          ),
          SocialProfile(userId: 'u2', username: 'hieu_dev'),
          SocialProfile(userId: 'u3', username: 'mia'),
        ];
      final social = SocialController(
        repository: repository,
        imageStorage: FakeImageStorageService(),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: social,
          child: const MaterialApp(home: UserSearchScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('huynhbahieu'), findsOneWidget);
      expect(find.text('hieu_dev'), findsOneWidget);
      expect(find.text('mia'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Hiếu');
      await tester.pump();
      expect(find.text('huynhbahieu'), findsOneWidget); // by name, no accents
      expect(find.text('hieu_dev'), findsOneWidget); // middle of a username
      expect(find.text('mia'), findsNothing);

      await tester.enterText(find.byType(TextField), '@hieu_d');
      await tester.pump();
      expect(find.text('hieu_dev'), findsOneWidget);
      expect(find.text('huynhbahieu'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No users found'), findsOneWidget);
    });
  });
}

class _BrokenRepository extends _FakeSocialRepository {
  @override
  Future<SocialProfile?> myProfile() async =>
      throw StateError('profiles table missing');
}
