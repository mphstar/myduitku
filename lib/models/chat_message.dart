/// Chat message model for AI chat
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.imageBase64,
    this.pendingTransaction,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    content: json['content'] as String,
    role: ChatRole.values.firstWhere(
      (e) => e.name == json['role'],
      orElse: () => ChatRole.user,
    ),
    timestamp: DateTime.parse(json['timestamp'] as String),
    imageBase64: json['imageBase64'] as String?,
    pendingTransaction: json['pendingTransaction'] != null
        ? PendingTransaction.fromJson(
            json['pendingTransaction'] as Map<String, dynamic>,
          )
        : null,
  );

  final String id;
  final String content;
  final ChatRole role;
  final DateTime timestamp;
  final String? imageBase64;
  final PendingTransaction? pendingTransaction;

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'role': role.name,
    'timestamp': timestamp.toIso8601String(),
    'imageBase64': imageBase64,
    'pendingTransaction': pendingTransaction?.toJson(),
  };

  ChatMessage copyWith({
    String? id,
    String? content,
    ChatRole? role,
    DateTime? timestamp,
    String? imageBase64,
    PendingTransaction? pendingTransaction,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      imageBase64: imageBase64 ?? this.imageBase64,
      pendingTransaction: pendingTransaction ?? this.pendingTransaction,
    );
  }
}

/// Chat message roles
enum ChatRole { user, assistant, system }

/// Pending transaction data from AI
class PendingTransaction {
  PendingTransaction({
    required this.type,
    required this.amount,
    required this.categoryId,
    this.accountName,
    this.description,
  });

  factory PendingTransaction.fromJson(Map<String, dynamic> json) =>
      PendingTransaction(
        type: json['type'] as String,
        amount: (json['amount'] as num).toDouble(),
        categoryId: json['categoryId'] as String,
        accountName: json['accountName'] as String?,
        description: json['description'] as String?,
      );

  final String type; // 'income' or 'expense'
  final double amount;
  final String categoryId;
  final String? accountName;
  final String? description;

  Map<String, dynamic> toJson() => {
    'type': type,
    'amount': amount,
    'categoryId': categoryId,
    'accountName': accountName,
    'description': description,
  };

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
}
