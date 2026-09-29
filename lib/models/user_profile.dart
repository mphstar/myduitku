/// User profile model
class UserProfile {
  UserProfile({
    this.name = 'User',
    this.photoPath,
    this.currency = 'IDR',
    this.primaryColor = 0xFF00B8A9,
    this.aiApiKey,
    this.aiModel,
    this.aiCustomBaseUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String? ?? 'User',
    photoPath: json['photoPath'] as String?,
    currency: json['currency'] as String? ?? 'IDR',
    primaryColor: json['primaryColor'] as int? ?? 0xFF00B8A9,
    aiApiKey: json['aiApiKey'] as String?,
    aiModel: json['aiModel'] as String?,
    aiCustomBaseUrl: json['aiCustomBaseUrl'] as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
  );

  final String name;
  final String? photoPath;
  final String currency;
  final int primaryColor;
  final String? aiApiKey;
  final String? aiModel;
  final String? aiCustomBaseUrl;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'name': name,
    'photoPath': photoPath,
    'currency': currency,
    'primaryColor': primaryColor,
    'aiApiKey': aiApiKey,
    'aiModel': aiModel,
    'aiCustomBaseUrl': aiCustomBaseUrl,
    'createdAt': createdAt.toIso8601String(),
  };

  UserProfile copyWith({
    String? name,
    String? photoPath,
    String? currency,
    int? primaryColor,
    String? aiApiKey,
    String? aiModel,
    String? aiCustomBaseUrl,
    DateTime? createdAt,
  }) {
    return UserProfile(
      name: name ?? this.name,
      photoPath: photoPath ?? this.photoPath,
      currency: currency ?? this.currency,
      primaryColor: primaryColor ?? this.primaryColor,
      aiApiKey: aiApiKey ?? this.aiApiKey,
      aiModel: aiModel ?? this.aiModel,
      aiCustomBaseUrl: aiCustomBaseUrl ?? this.aiCustomBaseUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
