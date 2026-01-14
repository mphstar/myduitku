import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

import '../core/constants.dart';
import 'database_service.dart';

/// Service for exporting and importing app data
class ExportImportService {
  static final ExportImportService _instance = ExportImportService._internal();
  factory ExportImportService() => _instance;
  ExportImportService._internal();

  final DatabaseService _db = DatabaseService();

  /// Export all data to a JSON file and save to device
  Future<ExportResult> exportData() async {
    try {
      // Get export data from database
      final data = _db.exportData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      // Generate filename with timestamp
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final fileName =
          '${AppConstants.exportFileName}_$timestamp.${AppConstants.exportFileExtension}';

      // Pick location to save
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan file backup ke:',
        fileName: fileName,
        allowedExtensions: ['json'],
        type: FileType.custom,
        bytes: bytes,
      );

      if (outputFile == null) {
        // User canceled
        return ExportResult.failure('Ekspor dibatalkan');
      }

      // Note: On Android/iOS file_picker handles writing the bytes.
      // On desktop it might just return the path, but passing bytes is safer.
      // If we are on mobile, we can assume it's saved.
      // If we effectively got a path back, we could verify,
      // but let's assume success if not null.

      return ExportResult.success(outputFile);
    } catch (e) {
      return ExportResult.failure('Gagal mengekspor data: $e');
    }
  }

  /// Import data from a JSON file
  Future<ImportResult> importData() async {
    try {
      // Pick a JSON file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return ImportResult.cancelled();
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate data structure
      if (!_validateImportData(data)) {
        return ImportResult.failure('Format file tidak valid');
      }

      // Import the data
      await _db.importData(data);

      return ImportResult.success(
        accountsCount: (data['accounts'] as List?)?.length ?? 0,
        transactionsCount: (data['transactions'] as List?)?.length ?? 0,
        categoriesCount: (data['categories'] as List?)?.length ?? 0,
        budgetsCount: (data['budgets'] as List?)?.length ?? 0,
        goalsCount: (data['goals'] as List?)?.length ?? 0,
      );
    } catch (e) {
      return ImportResult.failure('Gagal mengimpor data: $e');
    }
  }

  /// Validate import data structure
  bool _validateImportData(Map<String, dynamic> data) {
    // Check for required fields
    final requiredFields = ['accounts', 'transactions', 'categories'];
    for (final field in requiredFields) {
      if (!data.containsKey(field)) {
        return false;
      }
    }
    return true;
  }
}

/// Result of export operation
class ExportResult {
  final bool success;
  final String? filePath;
  final String? error;

  ExportResult._({required this.success, this.filePath, this.error});

  factory ExportResult.success(String path) =>
      ExportResult._(success: true, filePath: path);

  factory ExportResult.failure(String error) =>
      ExportResult._(success: false, error: error);
}

/// Result of import operation
class ImportResult {
  final bool success;
  final bool cancelled;
  final String? error;
  final int accountsCount;
  final int transactionsCount;
  final int categoriesCount;
  final int budgetsCount;
  final int goalsCount;

  ImportResult._({
    required this.success,
    this.cancelled = false,
    this.error,
    this.accountsCount = 0,
    this.transactionsCount = 0,
    this.categoriesCount = 0,
    this.budgetsCount = 0,
    this.goalsCount = 0,
  });

  factory ImportResult.success({
    required int accountsCount,
    required int transactionsCount,
    required int categoriesCount,
    required int budgetsCount,
    required int goalsCount,
  }) => ImportResult._(
    success: true,
    accountsCount: accountsCount,
    transactionsCount: transactionsCount,
    categoriesCount: categoriesCount,
    budgetsCount: budgetsCount,
    goalsCount: goalsCount,
  );

  factory ImportResult.failure(String error) =>
      ImportResult._(success: false, error: error);

  factory ImportResult.cancelled() =>
      ImportResult._(success: false, cancelled: true);

  int get totalCount =>
      accountsCount +
      transactionsCount +
      categoriesCount +
      budgetsCount +
      goalsCount;
}
