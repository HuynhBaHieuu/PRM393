/// Keys used for local persistence. Bump the version suffix when a
/// stored format changes incompatibly.
abstract final class StorageKeys {
  // Per-user data. Stored under a user scope (see [userScope]); the bare keys
  // are only read once to migrate data created before accounts existed.
  static const String clothingItems = 'wardrobe.items.v1';
  static const String outfits = 'outfits.v1';
  static const String calendarEntries = 'calendar.entries.v1';
  static const String settings = 'settings.v1';

  // Per-user, always kept on the device, even with Supabase.
  static const String stylistChats = 'stylist.chats.v1';
  static const String stylistUsage = 'stylist.usage.v1';

  static const List<String> userDataKeys = [
    clothingItems,
    outfits,
    calendarEntries,
    settings,
  ];

  // Device-wide auth data.
  static const String accounts = 'auth.accounts.v1';
  static const String session = 'auth.session.v1';
  static const String lastEmail = 'auth.lastEmail.v1';
  static const String legacyDataAdopted = 'auth.legacyAdopted.v1';

  /// Prefix that isolates one user's data from other accounts on the device.
  static String userScope(String userId) => 'user.$userId.';

  static String corruptBackup(String key) => '$key.corrupt';
}
