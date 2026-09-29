import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/constants.dart';
import '../models/models.dart';

/// Service for communicating with multiple AI provider APIs
/// Supports OpenRouter, OpenAI, Anthropic, and custom OpenAI-compatible APIs (DeepSeek, Groq, etc.)
class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  final Connectivity _connectivity = Connectivity();

  /// Check if device has internet connection
  Future<bool> hasInternetConnection() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Send message to AI provider and get response
  Future<AiResponse> sendMessage({
    required String apiKey,
    required String model,
    required String provider,
    required List<Map<String, String>> messages,
    required String userMessage,
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
      // Build system prompt with financial context
      final systemPrompt = _buildSystemPrompt(financialContext);

      // Route to the correct handler based on provider
      if (provider == 'anthropic') {
        return _sendAnthropicMessage(
          apiKey: apiKey,
          model: model,
          systemPrompt: systemPrompt,
          messages: messages,
          userMessage: userMessage,
        );
      } else {
        return _sendOpenAiCompatibleMessage(
          apiKey: apiKey,
          model: model,
          provider: provider,
          systemPrompt: systemPrompt,
          messages: messages,
          userMessage: userMessage,
          customBaseUrl: customBaseUrl,
        );
      }
    } catch (e) {
      return AiResponse(
        success: false,
        error: 'Terjadi kesalahan: ${e.toString()}',
      );
    }
  }

  /// Send message to OpenAI-compatible APIs (OpenRouter, OpenAI, Custom/DeepSeek, etc.)
  Future<AiResponse> _sendOpenAiCompatibleMessage({
    required String apiKey,
    required String model,
    required String provider,
    required String systemPrompt,
    required List<Map<String, String>> messages,
    required String userMessage,
    String? customBaseUrl,
  }) async {
    final baseUrl = AppConstants.getProviderBaseUrl(
      provider,
      customBaseUrl: customBaseUrl,
    );

    // Build messages list
    final apiMessages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...messages,
      {'role': 'user', 'content': userMessage},
    ];

    // Build headers based on provider
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    // OpenRouter-specific headers
    if (provider == 'openrouter') {
      headers['HTTP-Referer'] = 'https://myduitku.app';
      headers['X-Title'] = 'MyDuitKu';
    }

    final response = await http
        .post(
          Uri.parse(baseUrl),
          headers: headers,
          body: jsonEncode({'model': model, 'messages': apiMessages}),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Timeout: Server tidak merespons');
          },
        );

    return _handleOpenAiResponse(response);
  }

  /// Send message to Anthropic API (different format)
  Future<AiResponse> _sendAnthropicMessage({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required List<Map<String, String>> messages,
    required String userMessage,
  }) async {
    final baseUrl = AppConstants.getProviderBaseUrl('anthropic');

    // Build Anthropic-format messages (no 'system' role in messages array)
    final apiMessages = <Map<String, dynamic>>[
      ...messages.map((m) => {
            'role': m['role'] == 'assistant' ? 'assistant' : 'user',
            'content': m['content'],
          }),
      {'role': 'user', 'content': userMessage},
    ];

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    };

    final response = await http
        .post(
          Uri.parse(baseUrl),
          headers: headers,
          body: jsonEncode({
            'model': model,
            'max_tokens': 4096,
            'system': systemPrompt,
            'messages': apiMessages,
          }),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Timeout: Server tidak merespons');
          },
        );

    return _handleAnthropicResponse(response);
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
    } else {
      return _handleErrorResponse(response);
    }
  }

  /// Handle Anthropic API response (different format)
  AiResponse _handleAnthropicResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Anthropic returns content as array of blocks
      final contentBlocks = data['content'] as List;
      final textBlock = contentBlocks.firstWhere(
        (block) => block['type'] == 'text',
        orElse: () => {'text': ''},
      );
      final content = textBlock['text'] as String;
      final pendingTransaction = _parseTransactionFromResponse(content);

      return AiResponse(
        success: true,
        content: content,
        pendingTransaction: pendingTransaction,
      );
    } else {
      return _handleErrorResponse(response);
    }
  }

  /// Handle error responses (shared between providers)
  AiResponse _handleErrorResponse(http.Response response) {
    if (response.statusCode == 401) {
      return AiResponse(
        success: false,
        error:
            'API Key tidak valid. Silakan periksa API Key Anda di Pengaturan.',
      );
    } else if (response.statusCode == 429) {
      return AiResponse(
        success: false,
        error: 'Terlalu banyak permintaan. Silakan tunggu sebentar.',
      );
    } else {
      try {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ??
            errorData['error']?['type'] ??
            'Gagal menghubungi AI. Kode: ${response.statusCode}';
        return AiResponse(
          success: false,
          error: errorMessage.toString(),
        );
      } catch (_) {
        return AiResponse(
          success: false,
          error: 'Gagal menghubungi AI. Kode: ${response.statusCode}',
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
2. Jika user menyebutkan transaksi apapun (beli, bayar, jajan, makan, gaji, dapat uang, dll), kamu WAJIB menyertakan tag TRANSACTION_REQUEST di akhir pesanmu.
3. JANGAN pernah hanya bertanya konfirmasi tanpa menyertakan tag TRANSACTION_REQUEST. Tag harus SELALU ada jika ada transaksi yang disebutkan.
4. User akan melihat dialog konfirmasi otomatis dari aplikasi, jadi kamu tidak perlu meminta mereka bilang "ya" atau "setuju".
5. Jika diminta analisa, berikan insight yang berguna berdasarkan data yang ada.
6. Kamu PUNYA AKSES ke data keuangan user (saldo, daftar akun, transaksi hari ini, dan riwayat transaksi terbaru). Data ini ada di bagian bawah prompt ini. SELALU gunakan data tersebut untuk menjawab pertanyaan user tentang transaksi mereka.
7. JANGAN PERNAH bilang "saya tidak punya akses data" atau "saya tidak bisa melihat transaksi". Kamu SUDAH punya datanya.

FORMAT TRANSAKSI (WAJIB ada jika user menyebut transaksi):
Setelah pesanmu, SELALU sertakan format ini jika user menyebut transaksi apapun:

[TRANSACTION_REQUEST]
{
  "type": "income" atau "expense",
  "amount": jumlah dalam angka (tanpa titik atau koma),
  "categoryId": "pilih dari daftar kategori di bawah",
  "description": "deskripsi singkat"
}
[/TRANSACTION_REQUEST]

CONTOH RESPONS YANG BENAR:
User: "beli makaroni 15rb"
Respons: "Oke, aku catat pengeluaran untuk beli makaroni ya! 🍝

[TRANSACTION_REQUEST]
{
  "type": "expense",
  "amount": 15000,
  "categoryId": "cat_food",
  "description": "Beli makaroni"
}
[/TRANSACTION_REQUEST]"

User: "gajian 5 juta"
Respons: "Wah selamat gajian! 💰 Aku catat pemasukannya ya!

[TRANSACTION_REQUEST]
{
  "type": "income",
  "amount": 5000000,
  "categoryId": "cat_salary",
  "description": "Gaji bulanan"
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

INGAT: Tag TRANSACTION_REQUEST WAJIB disertakan setiap kali user menyebutkan transaksi! Aplikasi akan menampilkan dialog konfirmasi secara otomatis.
''');

    // Add financial context if available
    if (context != null) {
      buffer.writeln('\nTANGGAL HARI INI: ${context['currentDate'] ?? '-'}');

      buffer.writeln('\nKONTEKS KEUANGAN USER SAAT INI:');
      if (context['totalBalance'] != null) {
        buffer.writeln(
          '- Total Saldo: Rp${_formatNumber(context['totalBalance'])}',
        );
      }
      if (context['monthlyIncome'] != null) {
        buffer.writeln(
          '- Pemasukan Bulan Ini: Rp${_formatNumber(context['monthlyIncome'])}',
        );
      }
      if (context['monthlyExpense'] != null) {
        buffer.writeln(
          '- Pengeluaran Bulan Ini: Rp${_formatNumber(context['monthlyExpense'])}',
        );
      }
      if (context['topExpenseCategories'] != null) {
        buffer.writeln('- Kategori Pengeluaran Terbesar Bulan Ini:');
        for (final cat in context['topExpenseCategories'] as List) {
          buffer.writeln(
            '  * ${cat['name']}: Rp${_formatNumber(cat['amount'])}',
          );
        }
      }

      // Account details
      if (context['accounts'] != null) {
        final accounts = context['accounts'] as List;
        if (accounts.isNotEmpty) {
          buffer.writeln('\nDAFTAR AKUN:');
          for (final acc in accounts) {
            buffer.writeln(
              '- ${acc['name']} (${acc['type']}): Rp${_formatNumber(acc['balance'])}',
            );
          }
        }
      }

      // This month's transactions (ALL)
      if (context['thisMonthTransactions'] != null) {
        final monthTx = context['thisMonthTransactions'] as List;
        if (monthTx.isEmpty) {
          buffer.writeln('\nTRANSAKSI BULAN INI: Belum ada transaksi bulan ini.');
        } else {
          buffer.writeln('\nSEMUA TRANSAKSI BULAN INI (${monthTx.length} transaksi):');
          for (final tx in monthTx) {
            final type = tx['type'] == 'pemasukan' ? '📈' : '📉';
            buffer.writeln(
              '- $type [${tx['date']} ${tx['time']}] ${tx['description']} - Rp${_formatNumber(tx['amount'])} (${tx['category']}, akun: ${tx['account']})',
            );
          }
        }
      }

      // Last month summary + transactions
      if (context['lastMonthIncome'] != null ||
          context['lastMonthExpense'] != null) {
        buffer.writeln('\nRINGKASAN BULAN LALU:');
        if (context['lastMonthIncome'] != null) {
          buffer.writeln(
            '- Pemasukan: Rp${_formatNumber(context['lastMonthIncome'])}',
          );
        }
        if (context['lastMonthExpense'] != null) {
          buffer.writeln(
            '- Pengeluaran: Rp${_formatNumber(context['lastMonthExpense'])}',
          );
        }
      }
      if (context['lastMonthTransactions'] != null) {
        final lastTx = context['lastMonthTransactions'] as List;
        if (lastTx.isNotEmpty) {
          buffer.writeln('TRANSAKSI BULAN LALU (${lastTx.length} transaksi):');
          for (final tx in lastTx) {
            final type = tx['type'] == 'pemasukan' ? '📈' : '📉';
            buffer.writeln(
              '- $type [${tx['date']}] ${tx['description']} - Rp${_formatNumber(tx['amount'])} (${tx['category']})',
            );
          }
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
