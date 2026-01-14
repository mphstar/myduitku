/// User profile model
class UserProfile {
  UserProfile({
    this.name = 'User',
    this.photoPath,
    this.currency = 'IDR',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String? ?? 'User',
    photoPath: json['photoPath'] as String?,
    currency: json['currency'] as String? ?? 'IDR',
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
  );

  final String name;
  final String? photoPath;
  final String currency;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'name': name,
    'photoPath': photoPath,
    'currency': currency,
    'createdAt': createdAt.toIso8601String(),
  };

  UserProfile copyWith({
    String? name,
    String? photoPath,
    String? currency,
    DateTime? createdAt,
  }) {
    return UserProfile(
      name: name ?? this.name,
      photoPath: photoPath ?? this.photoPath,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
