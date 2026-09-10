import 'package:intl/intl.dart';

class FormatUtils {
  static String safeFormat(dynamic v, {int decimalDigits = 2, bool compact = true}) {
    if (v == null) return "0.00";
    
    double val;
    if (v is num) {
      val = v.toDouble();
    } else {
      val = double.tryParse(v.toString().replaceAll(',', '').trim()) ?? 0.0;
    }
    
    if (!val.isFinite) return "0.00";

    // Compact Indian Format with L/Cr Suffixes (Only if compact is true)
    if (compact) {
      if (val >= 10000000) { // 1 Crore
        return "${(val / 10000000).toStringAsFixed(decimalDigits)}Cr";
      }
      if (val >= 100000) { // 1 Lakh
        return "${(val / 100000).toStringAsFixed(decimalDigits)}L";
      }
      if (val >= 1000) { // 1 Thousand
        return "${(val / 1000).toStringAsFixed(1)}K";
      }
    }
    
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '',
      decimalDigits: decimalDigits,
    );
    
    return formatter.format(val).trim();
  }

  static String safeFixed(double? v, int digits) {
    if (v == null || !v.isFinite) return "0.0";
    return v.toStringAsFixed(digits);
  }
}
