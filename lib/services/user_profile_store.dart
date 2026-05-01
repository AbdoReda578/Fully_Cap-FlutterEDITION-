import 'package:hive/hive.dart';

import '../models/user_profile.dart';

class UserProfileStore {
  UserProfileStore({required Box<dynamic> metaBox}) : _metaBox = metaBox;

  final Box<dynamic> _metaBox;

  static const String _prefix = 'user_profile_v1:';

  String _keyForEmail(String email) => '$_prefix${email.trim().toLowerCase()}';

  UserProfile? getSync(String email) {
    final raw = _metaBox.get(_keyForEmail(email));
    if (raw is Map) {
      return UserProfile.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  Future<void> upsert(UserProfile profile) async {
    await _metaBox.put(_keyForEmail(profile.email), profile.toJson());
  }

  Future<void> deleteForEmail(String email) async {
    await _metaBox.delete(_keyForEmail(email));
  }
}

