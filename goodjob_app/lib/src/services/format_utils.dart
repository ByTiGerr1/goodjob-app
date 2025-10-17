import 'package:intl/intl.dart';

// Clase de utilidades para formatos de datos comunes
class FormatUtils {
  
  // ----------------------------------------------------
  // FORMATO DE MONEDA (PESO CHILENO - CLP)
  // ----------------------------------------------------
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'es_CL', // Localidad chilena: punto de miles, coma decimal
      symbol: '\$', 
      decimalDigits: 0, // CLP no usa decimales
      // CLAVE: Forzamos el símbolo (¤) a ir antes del número
      customPattern: '¤#,##0', 
    );
    return formatter.format(amount);
  }

  // ----------------------------------------------------
  // FORMATO DE DECIMALES (Con separadores chilenos)
  // ----------------------------------------------------
  static String formatDecimal(double number, {int decimalDigits = 1}) {
    final formatter = NumberFormat.decimalPattern('es_CL');
    formatter.minimumFractionDigits = decimalDigits;
    formatter.maximumFractionDigits = decimalDigits;
    return formatter.format(number);
  }

  // ----------------------------------------------------
  // FORMATO DE FECHAS
  // ----------------------------------------------------
  static String formatDate(DateTime date) {
    final formatter = DateFormat('dd/MM/yyyy', 'es_CL'); 
    return formatter.format(date);
  }
}
