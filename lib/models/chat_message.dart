/// Chat message model for AI chat
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.imageBase64,
    this.pendingAction,
    this.executedActions,
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
    pendingAction: json['pendingAction'] != null
        ? PendingAction.fromJson(
            json['pendingAction'] as Map<String, dynamic>,
          )
        : null,
    executedActions: json['executedActions'] != null
        ? (json['executedActions'] as List)
            .map((e) => ExecutedActionItem.fromJson(e as Map<String, dynamic>))
            .toList()
        : null,
  );

  final String id;
  final String content;
  final ChatRole role;
  final DateTime timestamp;
  final String? imageBase64;
  final PendingAction? pendingAction;
  final List<ExecutedActionItem>? executedActions;

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'role': role.name,
    'timestamp': timestamp.toIso8601String(),
    'imageBase64': imageBase64,
    'pendingAction': pendingAction?.toJson(),
    'executedActions': executedActions?.map((e) => e.toJson()).toList(),
  };

  ChatMessage copyWith({
    String? id,
    String? content,
    ChatRole? role,
    DateTime? timestamp,
    String? imageBase64,
    PendingAction? pendingAction,
    List<ExecutedActionItem>? executedActions,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      imageBase64: imageBase64 ?? this.imageBase64,
      pendingAction: pendingAction ?? this.pendingAction,
      executedActions: executedActions ?? this.executedActions,
    );
  }
}

/// Chat message roles
enum ChatRole { user, assistant, system }

/// Represents a single recorded transaction result or item
class ExecutedActionItem {
  ExecutedActionItem({
    required this.id,
    required this.type, // 'transaction', 'transfer', etc.
    required this.title,
    required this.subtitle,
    required this.amount,
    this.isIncome = false,
    this.transactionId,
    this.relatedTransactionId,
  });

  factory ExecutedActionItem.fromJson(Map<String, dynamic> json) =>
      ExecutedActionItem(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        amount: (json['amount'] as num).toDouble(),
        isIncome: json['isIncome'] as bool? ?? false,
        transactionId: json['transactionId'] as String?,
        relatedTransactionId: json['relatedTransactionId'] as String?,
      );

  final String id;
  final String type;
  final String title;
  final String subtitle;
  final double amount;
  final bool isIncome;
  final String? transactionId;
  final String? relatedTransactionId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'subtitle': subtitle,
    'amount': amount,
    'isIncome': isIncome,
    'transactionId': transactionId,
    'relatedTransactionId': relatedTransactionId,
  };
}

/// Pending non-transaction action requiring confirmation (create budget, account, goal, category)
class PendingAction {
  PendingAction({
    required this.actionType, // 'create_budget', 'create_account', 'create_goal', 'create_category'
    required this.data,
    required this.summary,
  });

  factory PendingAction.fromJson(Map<String, dynamic> json) => PendingAction(
        actionType: json['actionType'] as String,
        data: json['data'] as Map<String, dynamic>,
        summary: json['summary'] as String,
      );

  final String actionType;
  final Map<String, dynamic> data;
  final String summary;

  Map<String, dynamic> toJson() => {
    'actionType': actionType,
    'data': data,
    'summary': summary,
  };
}

/// Transaction item parsed from AI commands
class AiParsedTransaction {
  AiParsedTransaction({
    required this.type, // 'income', 'expense', 'transfer'
    required this.amount,
    this.categoryId,
    this.accountName,
    this.fromAccount,
    this.toAccount,
    this.description,
  });

  factory AiParsedTransaction.fromJson(Map<String, dynamic> json) =>
      AiParsedTransaction(
        type: json['type'] as String? ?? 'expense',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        categoryId: json['categoryId'] as String?,
        accountName: json['accountName'] as String?,
        fromAccount: json['fromAccount'] as String?,
        toAccount: json['toAccount'] as String?,
        description: json['description'] as String?,
      );

  final String type;
  final double amount;
  final String? categoryId;
  final String? accountName;
  final String? fromAccount;
  final String? toAccount;
  final String? description;

  Map<String, dynamic> toJson() => {
    'type': type,
    'amount': amount,
    'categoryId': categoryId,
    'accountName': accountName,
    'fromAccount': fromAccount,
    'toAccount': toAccount,
    'description': description,
  };

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get isTransfer => type == 'transfer';
}
