import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/constants.dart';
import '../models/models.dart';

/// Service for communicating with any OpenAI-Compatible API (OpenAI, Local LLM, Groq, DeepSeek, OpenRouter, Ollama, etc.)
class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  final Connectivity _connectivity = Connectivity();

  /// Check if device has internet connection
  Future<bool> hasInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (_) {
      // If connectivity check fails (e.g. on web or platform limitation), allow request to proceed
      return true;
    }
  }

  /// Fetch available models list from OpenAI-compatible /models endpoint
  Future<List<String>> fetchModels({
    required String apiKey,
    String? customBaseUrl,
  }) async {
    try {
      final modelsUrl = AppConstants.formatModelsUrl(customBaseUrl);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (apiKey.trim().isNotEmpty) 'Authorization': 'Bearer ${apiKey.trim()}',
      };

      final response = await http
          .get(Uri.parse(modelsUrl), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final modelIds = <String>[];

        // Format 1: { "data": [ { "id": "model-name" } ] }
        if (data is Map && data.containsKey('data') && data['data'] is List) {
          for (final item in data['data'] as List) {
            if (item is Map && item.containsKey('id')) {
              modelIds.add(item['id'].toString());
            } else if (item is String) {
              modelIds.add(item);
            }
          }
        }
        // Format 2: { "models": [ ... ] } (e.g. Ollama/custom proxy)
        else if (data is Map && data.containsKey('models') && data['models'] is List) {
          for (final item in data['models'] as List) {
            if (item is Map && item.containsKey('name')) {
              modelIds.add(item['name'].toString());
            } else if (item is Map && item.containsKey('id')) {
              modelIds.add(item['id'].toString());
            } else if (item is String) {
              modelIds.add(item);
            }
          }
        }
        // Format 3: [ { "id": "..." } ]
        else if (data is List) {
          for (final item in data) {
            if (item is Map && item.containsKey('id')) {
              modelIds.add(item['id'].toString());
            } else if (item is String) {
              modelIds.add(item);
            }
          }
        }

        modelIds.sort();
        return modelIds;
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Send message to OpenAI-compatible AI endpoint (supports text + optional image)
  Future<AiResponse> sendMessage({
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> messages,
    required String userMessage,
    String? imageBase64,
    String? customBaseUrl,
    Map<String, dynamic>? financialContext,
  }) async {
    // Check internet connection first
    if (!await hasInternetConnection()) {
      return AiResponse(
        success: false,
        error: 'Tidak ada koneksi internet. Silakan periksa koneksi Anda.',
      );
    }

    try {
      final systemPrompt = _buildSystemPrompt(financialContext);
      final endpointUrl = AppConstants.formatChatCompletionsUrl(customBaseUrl);

      // Build user message content (either String or Multi-modal array)
      dynamic userContent;
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        userContent = [
          {
            'type': 'text',
            'text': userMessage.isEmpty
                ? 'Tolong analisa struk / gambar ini dan catat transaksinya jika ada.'
                : userMessage,
          },
          {
            'type': 'image_url',
            'image_url': {
              'url': imageBase64.startsWith('data:')
                  ? imageBase64
                  : 'data:image/jpeg;base64,$imageBase64',
            },
          },
        ];
      } else {
        userContent = userMessage;
      }

      // Build messages list
      final apiMessages = <Map<String, dynamic>>[
        {'role': 'system', 'content': systemPrompt},
        ...messages,
        {'role': 'user', 'content': userContent},
      ];

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (apiKey.trim().isNotEmpty) 'Authorization': 'Bearer ${apiKey.trim()}',
      };

      final bodyMap = {
        'model': model.trim().isEmpty ? AppConstants.defaultAiModel : model.trim(),
        'messages': apiMessages,
      };

      final client = http.Client();
      final response = await client
          .post(
            Uri.parse(endpointUrl),
            headers: headers,
            body: jsonEncode(bodyMap),
          )
          .timeout(
            const Duration(seconds: 40),
            onTimeout: () {
              throw Exception('Timeout: Server AI tidak merespons dalam 40 detik');
            },
          );

      return _handleOpenAiResponse(response);
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('Failed to fetch') || errorMsg.contains('ClientException')) {
        return AiResponse(
          success: false,
          error:
              'Gagal terhubung ke server AI (Failed to fetch). Pastikan server backend Anda mengizinkan CORS (Cross-Origin Resource Sharing) atau periksa koneksi internet / domain endpoint.',
        );
      }
      return AiResponse(
        success: false,
        error: 'Terjadi kesalahan: $errorMsg',
      );
    }
  }

  /// Handle OpenAI-compatible API response
  AiResponse _handleOpenAiResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;

      final actionData = _parseAiActionFromResponse(content);

      return AiResponse(
        success: true,
        content: content,
        parsedTransactions: actionData.transactions,
        pendingAction: actionData.pendingAction,
      );
    } else if (response.statusCode == 401) {
      return AiResponse(
        success: false,
        error: 'API Key tidak valid atau tidak memiliki izin akses.',
      );
    } else if (response.statusCode == 404) {
      return AiResponse(
        success: false,
        error: 'Endpoint API tidak ditemukan (404). Periksa kembali Base URL di pengaturan.',
      );
    } else if (response.statusCode == 429) {
      return AiResponse(
        success: false,
        error: 'Terlalu banyak permintaan (Rate limit). Silakan tunggu beberapa saat.',
      );
    } else {
      try {
        final errorData = jsonDecode(response.body);
        return AiResponse(
          success: false,
          error: errorData['error']?['message'] ??
              'Gagal menghubungi AI (Status ${response.statusCode}).',
        );
      } catch (_) {
        return AiResponse(
          success: false,
          error: 'Gagal menghubungi AI. Status kode: ${response.statusCode}',
        );
      }
    }
  }

  /// Build system prompt for financial assistant
  String _buildSystemPrompt(Map<String, dynamic>? context) {
    final buffer = StringBuffer();
    buffer.writeln('''
Kamu adalah asisten keuangan pribadi pintar bernama DuitAI untuk aplikasi MyDuitKu.
Tugasmu adalah:
1. Membantu user langsung mencatat transaksi pengeluaran, pemasukan, maupun transfer/tarik tunai/pindah dana (bisa multi transaksi sekaligus) TANPA perlu bertanya konfirmasi kepada user. Transaksi akan LANGSUNG dicatat otomatis oleh sistem ke database!
2. Membantu user membuat Budget (anggaran), Akun (rekening/dompet), Kategori baru, atau Goal (tabungan) jika diminta. Karena pembuatan master data ini penting, sistem akan meminta konfirmasi user dengan tag [CONFIRM_ACTION].
3. Memberikan analisa keuangan, tips, dan informasi berdasarkan konteks user.

==================================================
ATURAN UTAMA:
==================================================
1. Selalu gunakan Bahasa Indonesia yang ramah, ringkas, dan jelas.
2. TRANSAKSI (Pengeluaran, Pemasukan, Transfer / Tarik Tunai / Top Up):
   - LANGSUNG catat dengan tag [TRANSACTIONS_EXECUTE] [...] [/TRANSACTIONS_EXECUTE].
   - JANGAN meminta konfirmasi transaksi di dialog, karena aplikasi langsung menyimpannya dan menyediakan tombol "Koreksi / Edit" atau "Batalkan" jika ada kesalahan!
   - KASUS MULTI-TRANSAKSI / DUA PROSES (Misal: Tarik tunai dari BCA, Top up e-wallet dari Bank, dll):
     * Opsi A (Transfer): Gunakan type "transfer", sebutkan "fromAccount" dan "toAccount", "amount", dan "description".
     * ATAU Opsi B (Sepasang Expense & Income): Catat 2 transaksi dalam array [TRANSACTIONS_EXECUTE]! (Contoh 1: expense dari BCA 'Tarik tunai', Contoh 2: income ke Cash 'Pemasukan tunai dari BCA').
     * Jika ada beberapa pengeluaran sekaligus (misal beli bensin 30rb dan makan 25rb pakai Cash): Catat 2 objek transaksi dalam array!
3. PEMBUATAN MASTER DATA (Budget, Akun, Goal, Kategori):
   - Gunakan tag [CONFIRM_ACTION] { ... } [/CONFIRM_ACTION] agar aplikasi memunculkan dialog konfirmasi sebelum membuat data tersebut.

==================================================
FORMAT TAG SISTEM (JSON):
==================================================

A. TAG TRANSAKSI OTOMATIS (Bisa 1 atau banyak transaksi):
[TRANSACTIONS_EXECUTE]
[
  {
    "type": "expense" | "income" | "transfer",
    "amount": 50000,
    "categoryId": "cat_food", // jika expense/income
    "accountName": "BCA",     // jika expense/income
    "fromAccount": "BCA",     // wajib jika type transfer
    "toAccount": "Cash",      // wajib jika type transfer
    "description": "Makan siang"
  }
]
[/TRANSACTIONS_EXECUTE]

B. TAG KONFIRMASI BUAT DATA BARU (Budget, Akun, Goal, Kategori):
[CONFIRM_ACTION]
{
  "actionType": "create_budget" | "create_account" | "create_goal" | "create_category",
  "summary": "Buat budget Makanan Rp 1.500.000/bulan",
  "data": {
    // untuk create_budget:
    "categoryId": "cat_food",
    "categoryName": "Makanan",
    "amount": 1500000,
    "period": "monthly" // weekly / monthly / yearly

    // ATAU untuk create_account:
    // "name": "Bank Jago",
    // "type": "bank", // cash / bank / ewallet / investment / other
    // "balance": 500000

    // ATAU untuk create_goal:
    // "name": "Beli Laptop",
    // "targetAmount": 15000000,
    // "deadline": "2026-12-31"

    // ATAU untuk create_category:
    // "name": "Langganan",
    // "type": "expense" // income / expense
  }
}
[/CONFIRM_ACTION]

==================================================
CONTOH KASUS:
==================================================
Contoh 1 (Dua proses / Tarik Tunai):
User: "Saya baru tarik uang 500rb dari BCA ke dompet cash"
Respons:
"Siap, penarikan tunai Rp500.000 dari BCA ke Cash sudah langsung dicatat! 💸

[TRANSACTIONS_EXECUTE]
[
  {
    "type": "transfer",
    "amount": 500000,
    "fromAccount": "BCA",
    "toAccount": "Cash",
    "description": "Tarik tunai BCA ke Cash"
  }
]
[/TRANSACTIONS_EXECUTE]"

Contoh 2 (Multi transaksi biasa):
User: "Tadi beli bensin 50rb pakai BCA sama beli kopi 25rb tunai"
Respons:
"Oke, pengeluaran bensin dan kopi sudah langsung dicatat ya! 🚗☕

[TRANSACTIONS_EXECUTE]
[
  {
    "type": "expense",
    "amount": 50000,
    "categoryId": "cat_transport",
    "accountName": "BCA",
    "description": "Beli bensin"
  },
  {
    "type": "expense",
    "amount": 25000,
    "categoryId": "cat_food",
    "accountName": "Cash",
    "description": "Beli kopi"
  }
]
[/TRANSACTIONS_EXECUTE]"

Contoh 3 (Buat Budget):
User: "Tolong buatkan budget makan 1 juta per bulan"
Respons:
"Aku sudah siapkan pembuatan budget Makanan sebesar Rp1.000.000 per bulan. Silakan konfirmasi ya! 📊

[CONFIRM_ACTION]
{
  "actionType": "create_budget",
  "summary": "Buat budget Makanan Rp 1.000.000 / bulan",
  "data": {
    "categoryId": "cat_food",
    "categoryName": "Makanan",
    "amount": 1000000,
    "period": "monthly"
  }
}
[/CONFIRM_ACTION]"

DAFTAR KATEGORI DEFAULT:
Pengeluaran (expense):
- cat_food (Makanan & Minuman)
- cat_transport (Transportasi)
- cat_shopping (Belanja)
- cat_bills (Tagihan & Utilitas)
- cat_entertainment (Hiburan)
- cat_health (Kesehatan)
- cat_education (Pendidikan)
- cat_other_expense (Lainnya)

Pemasukan (income):
- cat_salary (Gaji)
- cat_bonus (Bonus)
- cat_investment (Investasi)
- cat_gift (Hadiah)
- cat_other_income (Lainnya)
''');

    // Add financial context if available
    if (context != null) {
      buffer.writeln('\nKONTEKS KEUANGAN USER SAAT INI:');
      if (context['currentDate'] != null) {
        buffer.writeln('- Tanggal Hari Ini: ${context['currentDate']}');
      }
      if (context['totalBalance'] != null) {
        buffer.writeln('- Total Saldo: Rp${_formatNumber(context['totalBalance'])}');
      }
      if (context['monthlyIncome'] != null) {
        buffer.writeln('- Pemasukan Bulan Ini: Rp${_formatNumber(context['monthlyIncome'])}');
      }
      if (context['monthlyExpense'] != null) {
        buffer.writeln('- Pengeluaran Bulan Ini: Rp${_formatNumber(context['monthlyExpense'])}');
      }
      if (context['accounts'] != null) {
        buffer.writeln('- Daftar Akun:');
        for (final acc in context['accounts'] as List) {
          buffer.writeln('  * ${acc['name']} (${acc['type']}): Rp${_formatNumber(acc['balance'])}');
        }
      }
      if (context['thisMonthTransactions'] != null) {
        buffer.writeln('- Transaksi Bulan Ini:');
        for (final tx in (context['thisMonthTransactions'] as List).take(15)) {
          buffer.writeln('  * ${tx['date']}: ${tx['type']} Rp${_formatNumber(tx['amount'])} (${tx['category']}) - ${tx['description']}');
        }
      }
    }

    return buffer.toString();
  }

  String _formatNumber(dynamic number) {
    final value = (number as num).toDouble();
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  /// Parse AI response to extract actions (transactions or confirmation request)
  ({List<AiParsedTransaction> transactions, PendingAction? pendingAction})
      _parseAiActionFromResponse(String content) {
    final transactions = <AiParsedTransaction>[];
    PendingAction? pendingAction;

    // 1. Check for [TRANSACTIONS_EXECUTE] [...] [/TRANSACTIONS_EXECUTE]
    final multiTxRegex = RegExp(
      r'\[TRANSACTIONS_EXECUTE\]\s*([\s\S]*?)\s*\[\/TRANSACTIONS_EXECUTE\]',
      multiLine: true,
    );
    final multiMatch = multiTxRegex.firstMatch(content);
    if (multiMatch != null) {
      try {
        final rawJson = multiMatch.group(1)!.trim();
        final decoded = jsonDecode(rawJson);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              transactions.add(AiParsedTransaction.fromJson(item));
            }
          }
        } else if (decoded is Map<String, dynamic>) {
          transactions.add(AiParsedTransaction.fromJson(decoded));
        }
      } catch (_) {}
    }

    // Fallback support for older single [TRANSACTION_REQUEST] tag
    if (transactions.isEmpty) {
      final singleTxRegex = RegExp(
        r'\[TRANSACTION_REQUEST\]\s*(\{[\s\S]*?\})\s*\[\/TRANSACTION_REQUEST\]',
        multiLine: true,
      );
      final singleMatch = singleTxRegex.firstMatch(content);
      if (singleMatch != null) {
        try {
          final rawJson = singleMatch.group(1)!.trim();
          final data = jsonDecode(rawJson) as Map<String, dynamic>;
          transactions.add(AiParsedTransaction.fromJson(data));
        } catch (_) {}
      }
    }

    // 2. Check for [CONFIRM_ACTION] {...} [/CONFIRM_ACTION]
    final confirmRegex = RegExp(
      r'\[CONFIRM_ACTION\]\s*(\{[\s\S]*?\})\s*\[\/CONFIRM_ACTION\]',
      multiLine: true,
    );
    final confirmMatch = confirmRegex.firstMatch(content);
    if (confirmMatch != null) {
      try {
        final rawJson = confirmMatch.group(1)!.trim();
        final data = jsonDecode(rawJson) as Map<String, dynamic>;
        pendingAction = PendingAction.fromJson(data);
      } catch (_) {}
    }

    return (transactions: transactions, pendingAction: pendingAction);
  }

  /// Remove transaction and action tags from display content
  String cleanResponseContent(String content) {
    return content
        .replaceAll(
          RegExp(r'\[TRANSACTIONS_EXECUTE\][\s\S]*?\[\/TRANSACTIONS_EXECUTE\]'),
          '',
        )
        .replaceAll(
          RegExp(r'\[TRANSACTION_REQUEST\][\s\S]*?\[\/TRANSACTION_REQUEST\]'),
          '',
        )
        .replaceAll(
          RegExp(r'\[CONFIRM_ACTION\][\s\S]*?\[\/CONFIRM_ACTION\]'),
          '',
        )
        .trim();
  }
}

/// Response from AI API
class AiResponse {
  AiResponse({
    required this.success,
    this.content,
    this.error,
    this.parsedTransactions,
    this.pendingAction,
  });

  final bool success;
  final String? content;
  final String? error;
  final List<AiParsedTransaction>? parsedTransactions;
  final PendingAction? pendingAction;
}