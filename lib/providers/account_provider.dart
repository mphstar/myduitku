import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import 'package:uuid/uuid.dart';

/// Provider for managing accounts
class AccountProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final Uuid _uuid = const Uuid();

  List<Account> _accounts = [];
  bool _isLoading = false;

  List<Account> get accounts => _accounts;
  bool get isLoading => _isLoading;

  /// Get total balance across all accounts
  double get totalBalance => _accounts.fold(0, (sum, acc) => sum + acc.balance);

  /// Load accounts from database (auto-create default Cash wallet if empty)
  Future<void> loadAccounts() async {
    _isLoading = true;
    notifyListeners();

    _accounts = _db.getAccounts();

    if (_accounts.isEmpty) {
      final defaultAccount = Account(
        id: 'acc_cash_default',
        name: 'Tunai / Cash',
        type: AccountType.cash,
        balance: 0,
        icon: 'account_balance_wallet',
        color: 0xFF00B8A9,
      );
      await _db.saveAccount(defaultAccount);
      _accounts = [defaultAccount];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new account and return the created Account
  Future<Account> addAccount({
    required String name,
    required AccountType type,
    required double balance,
    String? icon,
    int? color,
  }) async {
    final account = Account(
      id: _uuid.v4(),
      name: name,
      type: type,
      balance: balance,
      icon: icon ?? 'account_balance_wallet',
      color: color ?? 0xFF00B8A9,
    );

    await _db.saveAccount(account);
    await loadAccounts();
    return account;
  }

  /// Update an existing account
  Future<void> updateAccount(Account account) async {
    await _db.saveAccount(account);
    await loadAccounts();
  }

  /// Delete an account
  Future<void> deleteAccount(String id) async {
    await _db.deleteAccount(id);
    await loadAccounts();
  }

  /// Update account balance after transaction
  Future<void> updateBalance(
    String accountId,
    double amount,
    TransactionType type,
  ) async {
    final account = _db.getAccount(accountId);
    if (account != null) {
      final newBalance = type == TransactionType.income
          ? account.balance + amount
          : account.balance - amount;

      await _db.saveAccount(account.copyWith(balance: newBalance));
      await loadAccounts();
    }
  }

  /// Revert account balance (for transaction deletion)
  Future<void> revertBalance(
    String accountId,
    double amount,
    TransactionType type,
  ) async {
    final account = _db.getAccount(accountId);
    if (account != null) {
      final newBalance = type == TransactionType.income
          ? account.balance - amount
          : account.balance + amount;

      await _db.saveAccount(account.copyWith(balance: newBalance));
      await loadAccounts();
    }
  }

  /// Get account by ID
  Account? getAccountById(String id) {
    try {
      return _accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}
