import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/constants.dart';
import '../models/models.dart';

/// Service for communicating with OpenRouter AI API
class OpenRouterService {
  static final OpenRouterService _instance = OpenRouterService._internal();
  factory OpenRouterService() => _instance;
  OpenRouterService._internal();

  final Connectivity _connectivity = Connectivity();

  /// Check if device has internet connection
  Future<bool> hasInternetConnection() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Send message to OpenRouter AI and get response
  Future<OpenRouterResponse> sendMessage({
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
    required String userMessage,
    Map<String, dynamic>? financialContext,
  }) async {
    // Check internet connection first
    if (!await hasInternetConnection()) {
      return OpenRouterResponse(
        success: false,
        error: 'Tidak ada koneksi internet. Silakan periksa koneksi Anda.',
      );
    }

    try {
      // Build system prompt with financial context
      final systemPrompt = _buildSystemPrompt(financialContext);

      // Build messages list
      final apiMessages = <Map<String, String>>[
        {'role': 'system', 'content': systemPrompt},
        ...messages,
        {'role': 'user', 'content': userMessage},
      ];

      final response = await http
          .post(
            Uri.parse(AppConstants.openRouterApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
              'HTTP-Referer': 'https://myduitku.app',
              'X-Title': 'MyDuitKu',
            },
            body: jsonEncode({'model': model, 'messages': apiMessages}),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Timeout: Server tidak merespons');
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;

        // Parse response for potential transaction
        final pendingTransaction = _parseTransactionFromResponse(content);

        return OpenRouterResponse(
          success: true,
          content: content,
          pendingTransaction: pendingTransaction,
        );
      } else if (response.statusCode == 401) {
        return OpenRouterResponse(
          success: false,
          error:
              'API Key tidak valid. Silakan periksa API Key Anda di Pengaturan.',
        );
      } else if (response.statusCode == 429) {
        return OpenRouterResponse(
          success: false,
          error: 'Terlalu banyak permintaan. Silakan tunggu sebentar.',
        );
      } else {
        final errorData = jsonDecode(response.body);
        return OpenRouterResponse(
          success: false,
          error:
              errorData['error']?['message'] ??
              'Gagal menghubungi AI. Kode: ${response.statusCode}',
        );
      }
    } catch (e) {
      return OpenRouterResponse(
        success: false,
        error: 'Terjadi kesalahan: ${e.toString()}',
      );
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
        buffer.writeln('- Kategori Pengeluaran Terbesar:');
        for (final cat in context['topExpenseCategories'] as List) {
          buffer.writeln(
            '  * ${cat['name']}: Rp${_formatNumber(cat['amount'])}',
          );
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

/// Response from OpenRouter API
class OpenRouterResponse {
  OpenRouterResponse({
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
