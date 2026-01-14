import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// TextInputFormatter that formats numeric input as Indonesian currency
/// Displays numbers with thousand separators (e.g., 1.000.000)
class CurrencyInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('id');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow empty value
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove all non-digit characters
    final String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // If no digits, return empty
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Parse to number and format
    final int? number = int.tryParse(digitsOnly);
    if (number == null) {
      return oldValue;
    }

    final String formatted = _formatter.format(number);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Parse currency-formatted text to double
  static double? parse(String text) {
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    return double.tryParse(digitsOnly);
  }
}
