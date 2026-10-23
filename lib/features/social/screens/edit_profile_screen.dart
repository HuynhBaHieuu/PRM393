import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/data/local/image_picker_service.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/data/models/user_account.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/social/widgets/social_widgets.dart';

/// Fits' Edit profile: photo, rows that open an editor, and the privacy
/// switches. With a profile, every change saves at once; without one, the
/// rows fill a draft that "Create profile" saves.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late SocialProfile _draft;
  String? _photoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final me = context.read<SocialController>().me;
    final settings = context.read<SettingsController>();
    _draft =
        me ??
        SocialProfile(
          userId: context.read<AppUser>().id,
          username: suggestUsername(settings.username),
          displayName: settings.displayName,
        );
  }

  bool get _creating => context.read<SocialController>().me == null;

  /// Saves [next] right away for an existing profile.
  Future<void> _apply(SocialProfile next, {String? photoPath}) async {
    setState(() {
      _draft = next;
      if (photoPath != null) _photoPath = photoPath;
    });
    if (!_creating) await _save();
  }

  Future<void> _save() async {
    if (_saving) return;
    final social = context.read<SocialController>();
    final settings = context.read<SettingsController>();
    final navigator = Navigator.of(context);
    final creating = _creating;
    setState(() => _saving = true);
    try {
      final saved = await social.saveProfile(_draft, photoPath: _photoPath);
      // The Profile tab title and greeting read these.
      await settings.updateProfile(
        displayName: saved.displayName,
        username: saved.username,
      );
      if (!mounted) return;
      setState(() {
        _draft = saved;
        _photoPath = null;
      });
      if (creating) {
        navigator.pop();
        context.showSnack('Profile created');
      }
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePhoto() async {
    final picker = context.read<ImagePickerService>();
    final source = await showModalBottomSheet<ImagePickSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImagePickSource.gallery),
            ),
            if (picker.supportsCamera)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImagePickSource.camera),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final path = await picker.pickImage(source);
      if (path != null) await _apply(_draft, photoPath: path);
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    }
  }

  Future<void> _editField(_Field field) async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FieldEditor(field: field, initial: field.read(_draft)),
      ),
    );
    if (value != null) await _apply(field.write(_draft, value));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final me = context.watch<SocialController>().me;
    final creating = me == null;
    final helpStyle = text.bodyMedium?.copyWith(color: palette.textSecondary);

    return Scaffold(
      appBar: AppBar(
        title: Text(creating ? 'Create profile' : 'Edit profile'),
        bottom: _saving
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: InkWell(
              onTap: _saving ? null : _changePhoto,
              customBorder: const CircleBorder(),
              child: UserAvatar(
                name: _draft.name,
                url: _draft.avatarUrl,
                photoPath: _photoPath,
                size: 112,
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: _saving ? null : _changePhoto,
              style: TextButton.styleFrom(
                foregroundColor: palette.textSecondary,
              ),
              child: const Text('Change photo'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final field in _Field.values)
            _FieldRow(
              label: field.label,
              value: field.read(_draft),
              onTap: _saving ? null : () => _editField(field),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
              vertical: AppSpacing.sm,
            ),
            child: Divider(),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
            ),
            secondary: const Icon(Icons.lock_outline_rounded),
            title: Text('Private account', style: text.titleMedium),
            value: _draft.isPrivate,
            onChanged: _saving
                ? null
                : (value) => _apply(_draft.copyWith(isPrivate: value)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'When your account is public, your profile, clothes and '
                  'outfits can be seen by anyone. Price, notes and how often '
                  'you wear something always stay private.',
                  style: helpStyle,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'When your account is private, only the followers you '
                  'approve can see your wardrobe, and your outfits leave '
                  'Discover. Your username and profile picture is visible to '
                  'anyone.',
                  style: helpStyle,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
            ),
            secondary: const Icon(Icons.style_outlined),
            title: Text('Let others style me', style: text.titleMedium),
            subtitle: const Text(
              'People who can see your closet can make outfits from it for '
              'you.',
            ),
            value: _draft.allowStyling,
            onChanged: _saving
                ? null
                : (value) => _apply(_draft.copyWith(allowStyling: value)),
          ),
          if (creating) ...[
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Create profile'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lower-cased and stripped to what a username allows, from [source] (the
/// handle set at sign-up). Availability is checked when saving.
String suggestUsername(String source) {
  final cleaned = source.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.]'), '');
  final clipped = cleaned.length > Validators.maxUsernameLength
      ? cleaned.substring(0, Validators.maxUsernameLength)
      : cleaned;
  return clipped.length >= Validators.minUsernameLength ? clipped : '';
}

enum _Field {
  name('Name', Validators.maxNameLength),
  username('Username', Validators.maxUsernameLength),
  bio('Bio', Validators.maxBioLength);

  const _Field(this.label, this.maxLength);

  final String label;
  final int maxLength;

  String read(SocialProfile p) => switch (this) {
    _Field.name => p.displayName,
    _Field.username => p.username,
    _Field.bio => p.bio,
  };

  SocialProfile write(SocialProfile p, String value) => switch (this) {
    _Field.name => p.copyWith(displayName: value),
    _Field.username => p.copyWith(username: value),
    _Field.bio => p.copyWith(bio: value),
  };

  String get help => switch (this) {
    _Field.name =>
      'Help people discover your account by using the name you are known by.',
    _Field.username =>
      'Choose a unique username for your profile. Lowercase letters, '
          'numbers, _ and . only.',
    _Field.bio => 'A few words about your style.',
  };
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final empty = value.isEmpty;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: text.bodyLarge?.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                empty ? 'Add' : value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(
                  color: empty ? palette.textTertiary : palette.ink,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Cancel / title / Save over one field, with Fits' character counter and,
/// for usernames, a live availability check.
class _FieldEditor extends StatefulWidget {
  const _FieldEditor({required this.field, required this.initial});

  final _Field field;
  final String initial;

  @override
  State<_FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends State<_FieldEditor> {
  static const Duration _debounce = Duration(milliseconds: 400);

  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  )..addListener(_onChanged);
  Timer? _timer;

  /// Null while unknown or not a username.
  bool? _available;
  int _check = 0;

  bool get _isUsername => widget.field == _Field.username;

  String get _value =>
      _isUsername ? _text.text.trim().toLowerCase() : _text.text.trim();

  String? get _error => switch (widget.field) {
    _Field.username => Validators.username(_value),
    _Field.name => Validators.optionalName(_value),
    _Field.bio => null,
  };

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() => _available = null);
    if (!_isUsername) return;
    _timer?.cancel();
    if (_error != null || _value == widget.initial) return;
    final check = ++_check;
    _timer = Timer(_debounce, () async {
      try {
        final free = await context
            .read<SocialController>()
            .repository
            .isUsernameAvailable(_value);
        if (mounted && check == _check) setState(() => _available = free);
      } catch (_) {
        // Saving checks again; the unique constraint has the last word.
      }
    });
  }

  bool get _canSave => _error == null && (!_isUsername || _available != false);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final error = _text.text.isEmpty && !_isUsername ? null : _error;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 96,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        centerTitle: true,
        title: Text(widget.field.label),
        actions: [
          TextButton(
            onPressed: _canSave
                ? () => Navigator.of(context).pop(_value)
                : null,
            child: const Text('Save'),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          TextField(
            controller: _text,
            autofocus: true,
            maxLength: widget.field.maxLength,
            minLines: widget.field == _Field.bio ? 3 : 1,
            maxLines: widget.field == _Field.bio ? 5 : 1,
            autocorrect: !_isUsername,
            textCapitalization: _isUsername
                ? TextCapitalization.none
                : TextCapitalization.sentences,
            decoration: InputDecoration(
              prefixText: _isUsername ? '@' : null,
              errorText: error,
            ),
          ),
          if (_isUsername && _available != null && error == null)
            Row(
              children: [
                Icon(
                  _available! ? Icons.check_circle_rounded : Icons.cancel,
                  size: AppSizes.iconSm,
                  color: _available! ? palette.success : palette.danger,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _available!
                      ? 'Username is available'
                      : 'This username is taken',
                  style: text.bodyMedium,
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.field.help,
            style: text.bodyMedium?.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
