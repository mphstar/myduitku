/// User profile model
class UserProfile {
  UserProfile({
    this.name = 'User',
    this.photoPath,
    this.currency = 'IDR',
    this.aiApiKey,
    this.aiModel,
    this.aiProvider,
    this.aiCustomBaseUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String? ?? 'User',
    photoPath: json['photoPath'] as String?,
    currency: json['currency'] as String? ?? 'IDR',
    aiApiKey: json['aiApiKey'] as String?,
    aiModel: json['aiModel'] as String?,
    aiProvider: json['aiProvider'] as String?,
    aiCustomBaseUrl: json['aiCustomBaseUrl'] as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
  );

  final String name;
  final String? photoPath;
  final String currency;
  final String? aiApiKey;
  final String? aiModel;
  final String? aiProvider;
  final String? aiCustomBaseUrl;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'name': name,
    'photoPath': photoPath,
    'currency': currency,
    'aiApiKey': aiApiKey,
    'aiModel': aiModel,
    'aiProvider': aiProvider,
    'aiCustomBaseUrl': aiCustomBaseUrl,
    'createdAt': createdAt.toIso8601String(),
  };

  UserProfile copyWith({
    String? name,
    String? photoPath,
    String? currency,
    String? aiApiKey,
    String? aiModel,
    String? aiProvider,
    String? aiCustomBaseUrl,
    DateTime? createdAt,
  }) {
    return UserProfile(
      name: name ?? this.name,
      photoPath: photoPath ?? this.photoPath,
      currency: currency ?? this.currency,
      aiApiKey: aiApiKey ?? this.aiApiKey,
      aiModel: aiModel ?? this.aiModel,
      aiProvider: aiProvider ?? this.aiProvider,
      aiCustomBaseUrl: aiCustomBaseUrl ?? this.aiCustomBaseUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
