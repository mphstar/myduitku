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

      final pendingTransaction = _parseTransactionFromResponse(content);

      return AiResponse(
        success: true,
        content: content,
        pendingTransaction: pendingTransaction,
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
Kamu adalah asisten keuangan pribadi bernama DuitAI untuk aplikasi MyDuitKu.
Tugasmu adalah membantu user mencatat pemasukan dan pengeluaran, serta memberikan analisa keuangan.

ATURAN PENTING:
1. Selalu gunakan Bahasa Indonesia yang ramah dan santai.
2. Jika user menyebutkan transaksi apapun (beli, bayar, jajan, makan, gaji, dapat uang, transfer, dll), kamu WAJIB menyertakan tag TRANSACTION_REQUEST di akhir pesanmu.
3. Tentukan akun (rekening/dompet) dan kategori yang paling cocok secara cerdas:
   - Jika user menyebut bank/metode (misal BCA, Mandiri, Cash, Dompet, QRIS, GoPay), sebutkan nama akun tersebut di tag TRANSACTION_REQUEST.
   - Pilih categoryId yang paling tepat.
4. JANGAN pernah hanya bertanya konfirmasi tanpa menyertakan tag TRANSACTION_REQUEST. Tag harus SELALU ada jika ada transaksi yang disebutkan.
5. User akan melihat dialog konfirmasi interaktif di aplikasi, jadi kamu tidak perlu meminta konfirmasi manual di teks.

FORMAT TRANSAKSI (WAJIB ada jika user menyebut transaksi):
Setelah pesanmu, SELALU sertakan format ini jika user menyebut transaksi apapun:

[TRANSACTION_REQUEST]
{
  "type": "income" atau "expense",
  "amount": jumlah dalam angka (tanpa titik atau koma),
  "categoryId": "pilih dari daftar kategori di bawah",
  "accountName": "nama akun jika disebutkan user, misal BCA / Cash / Mandiri / GoPay",
  "description": "deskripsi singkat"
}
[/TRANSACTION_REQUEST]

CONTOH RESPONS:
User: "beli makan siang 25rb"
Respons: "Oke, aku bantu catat pengeluaran makan siangnya ya! 🍲

[TRANSACTION_REQUEST]
{
  "type": "expense",
  "amount": 25000,
  "categoryId": "cat_food",
  "description": "Makan siang"
}
[/TRANSACTION_REQUEST]"

KATEGORI PENGELUARAN (expense):
- cat_food: Makanan & Minuman
- cat_transport: Transportasi
- cat_shopping: Belanja
- cat_bills: Tagihan & Utilitas
- cat_entertainment: Hiburan
- cat_health: Kesehatan
- cat_education: Pendidikan
- cat_other_expense: Lainnya

KATEGORI PEMASUKAN (income):
- cat_salary: Gaji
- cat_bonus: Bonus
- cat_investment: Investasi
- cat_gift: Hadiah
- cat_other_income: Lainnya
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

  /// Parse AI response to extract transaction request
  PendingTransaction? _parseTransactionFromResponse(String content) {
    final regex = RegExp(
      r'\[TRANSACTION_REQUEST\]\s*(\{[\s\S]*?\})\s*\[\/TRANSACTION_REQUEST\]',
      multiLine: true,
    );

    final match = regex.firstMatch(content);
    if (match == null) return null;

    try {
      final jsonStr = match.group(1)!;
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      return PendingTransaction(
        type: data['type'] as String,
        amount: (data['amount'] as num).toDouble(),
        categoryId: data['categoryId'] as String,
        accountName: data['accountName'] as String?,
        description: data['description'] as String?,
      );
    } catch (e) {
      return null;
    }
  }

  /// Remove transaction request tags from display content
  String cleanResponseContent(String content) {
    return content
        .replaceAll(
          RegExp(r'\[TRANSACTION_REQUEST\][\s\S]*?\[\/TRANSACTION_REQUEST\]'),
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
    this.pendingTransaction,
  });

  final bool success;
  final String? content;
  final String? error;
  final PendingTransaction? pendingTransaction;
}