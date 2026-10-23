import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'package:all_fits/core/utils/load_status.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/models/outfit_placement.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/data/repositories/social_repository.dart';

/// The signed-in user's side of the community: their profile, who they
/// follow and who follows them, outfits made for and by them, and which of
/// their outfits are on Discover. Other people's profiles and the feed are
/// fetched by the screens that show them, through [repository].
class SocialController extends ChangeNotifier {
  SocialController({
    required this.repository,
    required ImageStorageService imageStorage,
  }) : _images = imageStorage;

  final SocialRepository repository;
  final ImageStorageService _images;

  LoadStatus _status = LoadStatus.idle;
  Object? _error;
  SocialProfile? _me;
  List<Connection> _connections = const [];
  List<StyledOutfit> _styled = const [];
  Set<String> _postedIds = const {};

  LoadStatus get status => _status;
  Object? get error => _error;

  /// Null until the user creates a profile.
  SocialProfile? get me => _me;
  bool get hasProfile => _me != null;

  List<Connection> get followers =>
      _connections.where((c) => c.isFollower && c.isAccepted).toList();
  List<Connection> get following =>
      _connections.where((c) => !c.isFollower && c.isAccepted).toList();
  List<Connection> get incomingRequests =>
      _connections.where((c) => c.isFollower && !c.isAccepted).toList();
  List<Connection> get sentRequests =>
      _connections.where((c) => !c.isFollower && !c.isAccepted).toList();

  List<StyledOutfit> get styledForMe =>
      _styled.where((s) => s.incoming).toList();
  List<StyledOutfit> get styledByMe =>
      _styled.where((s) => !s.incoming).toList();
  int get unansweredStyledCount =>
      _styled.where((s) => s.incoming && s.isPending).length;

  /// What the bell shows: follow requests plus unanswered outfits.
  int get notificationCount => incomingRequests.length + unansweredStyledCount;

  bool isPosted(String outfitId) => _postedIds.contains(outfitId);

  StyledOutfit? styledById(String id) {
    for (final s in _styled) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Never throws: the rest of the app works without the community.
  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        repository.myProfile(),
        repository.connections(),
        repository.styledOutfits(),
        repository.postedOutfitIds(),
      ]);
      _me = results[0] as SocialProfile?;
      _connections = results[1] as List<Connection>;
      _styled = results[2] as List<StyledOutfit>;
      _postedIds = results[3] as Set<String>;
      _status = LoadStatus.ready;
    } catch (error) {
      developer.log('Community not loaded', name: 'social', error: error);
      _status = LoadStatus.failure;
      _error = error;
    }
    notifyListeners();
  }

  /// Uploads [photoPath] when given, then saves [profile].
  Future<SocialProfile> saveProfile(
    SocialProfile profile, {
    String? photoPath,
  }) async {
    var next = profile;
    if (photoPath != null) {
      next = next.copyWith(avatarUrl: await _images.saveImage(photoPath));
    }
    final saved = await repository.saveProfile(next);
    final previousPhoto = _me?.avatarUrl;
    _me = saved;
    notifyListeners();
    if (photoPath != null && previousPhoto != null) {
      await _images.deleteImage(previousPhoto);
    }
    // Going public approves waiting requests on the server.
    if (!saved.isPrivate && incomingRequests.isNotEmpty) {
      await _reloadConnections();
    }
    return saved;
  }

  Future<FollowStatus> follow(String userId) async {
    final status = await repository.follow(userId);
    await _reloadConnections();
    return status;
  }

  Future<void> unfollow(String userId) =>
      _thenReload(repository.unfollow(userId));

  Future<void> acceptFollower(String userId) =>
      _thenReload(repository.acceptFollower(userId));

  Future<void> removeFollower(String userId) =>
      _thenReload(repository.removeFollower(userId));

  Future<void> block(String userId) async {
    await repository.block(userId);
    await Future.wait([_reloadConnections(), _reloadStyled()]);
  }

  Future<void> unblock(String userId) => repository.unblock(userId);

  Future<void> setPosted(String outfitId, {required bool posted}) async {
    await repository.setPosted(outfitId, posted: posted);
    _postedIds = {
      ..._postedIds.where((id) => id != outfitId),
      if (posted) outfitId,
    };
    notifyListeners();
  }

  Future<void> sendStyledOutfit({
    required String recipientId,
    required List<String> itemIds,
    required List<OutfitPlacement> layout,
    String? message,
  }) async {
    await repository.sendStyledOutfit(
      recipientId: recipientId,
      itemIds: itemIds,
      layout: layout,
      message: message,
    );
    await _reloadStyled();
  }

  Future<void> answerStyledOutfit(String id, StyledStatus status) async {
    await repository.answerStyledOutfit(id, status);
    await _reloadStyled();
  }

  Future<void> deleteStyledOutfit(String id) async {
    await repository.deleteStyledOutfit(id);
    await _reloadStyled();
  }

  Future<void> _thenReload(Future<void> request) async {
    await request;
    await _reloadConnections();
  }

  Future<void> _reloadConnections() async {
    _connections = await repository.connections();
    notifyListeners();
  }

  Future<void> _reloadStyled() async {
    _styled = await repository.styledOutfits();
    notifyListeners();
  }
}
