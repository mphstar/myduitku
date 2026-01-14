import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/database_service.dart';

/// Provider for managing user profile
class UserProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  UserProfile _profile = UserProfile();
  bool _isLoading = false;

  UserProfile get profile => _profile;
  bool get isLoading => _isLoading;

  /// Load user profile from database
  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    _profile = _db.getUserProfile();

    _isLoading = false;
    notifyListeners();
  }

  /// Update user profile
  Future<void> updateProfile({
    String? name,
    String? photoPath,
    String? currency,
    String? aiApiKey,
    String? aiModel,
  }) async {
    _profile = _profile.copyWith(
      name: name ?? _profile.name,
      photoPath: photoPath ?? _profile.photoPath,
      currency: currency ?? _profile.currency,
      aiApiKey: aiApiKey ?? _profile.aiApiKey,
      aiModel: aiModel ?? _profile.aiModel,
    );

    await _db.saveUserProfile(_profile);
    notifyListeners();
  }

  /// Clear profile photo
  Future<void> clearProfilePhoto() async {
    _profile = UserProfile(
      name: _profile.name,
      photoPath: null,
      currency: _profile.currency,
      createdAt: _profile.createdAt,
    );

    await _db.saveUserProfile(_profile);
    notifyListeners();
  }
}
