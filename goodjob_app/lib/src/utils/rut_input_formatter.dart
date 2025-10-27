import 'package:flutter/services.dart';

import 'rut_utils.dart';

class RutInputFormatter extends TextInputFormatter {
  const RutInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = RutUtils.normalize(newValue.text);
    final formatted = RutUtils.format(normalized);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}