class RutUtils {
  const RutUtils._();

  /// Removes any formatting characters and uppercases the verifier digit.
  static String normalize(String rut) {
    final sanitized = rut.replaceAll(RegExp(r'[^0-9kK]'), '').toUpperCase();
    return sanitized;
  }

  /// Returns the formatted version of the RUT using dots and hyphen.
  static String format(String rut) {
    final normalized = normalize(rut);
    if (normalized.isEmpty) {
      return '';
    }
    if (normalized.length == 1) {
      return normalized;
    }
    final body = normalized.substring(0, normalized.length - 1);
    final verifier = normalized.substring(normalized.length - 1);
    final formattedBody = _addThousandsSeparators(body);
    return '$formattedBody-$verifier';
  }

  /// Returns the numerical body of the RUT without the verifier digit.
  static String bodyWithoutVerifier(String rut) {
    final normalized = normalize(rut);
    if (normalized.length <= 1) {
      return '';
    }
    return normalized.substring(0, normalized.length - 1);
  }

  /// Returns the verifier digit of the RUT.
  static String verifierDigit(String rut) {
    final normalized = normalize(rut);
    if (normalized.isEmpty) {
      return '';
    }
    return normalized.substring(normalized.length - 1);
  }

  /// Validates the RUT using the Chilean modulus 11 algorithm.
  static bool isValid(String rut) {
    final normalized = normalize(rut);
    if (normalized.length < 8 || normalized.length > 9) {
      return false;
    }

    final body = normalized.substring(0, normalized.length - 1);
    final verifier = normalized.substring(normalized.length - 1);

    if (!RegExp(r'^[0-9]+$').hasMatch(body)) {
      return false;
    }

    final expectedVerifier = _calculateVerifierDigit(body);
    return expectedVerifier == verifier;
  }

  static String _calculateVerifierDigit(String body) {
    int sum = 0;
    int multiplier = 2;

    for (int i = body.length - 1; i >= 0; i--) {
      sum += int.parse(body[i]) * multiplier;
      multiplier = multiplier == 7 ? 2 : multiplier + 1;
    }

    final mod = 11 - (sum % 11);
    if (mod == 11) {
      return '0';
    }
    if (mod == 10) {
      return 'K';
    }
    return mod.toString();
  }

  static String _addThousandsSeparators(String body) {
    if (body.isEmpty) {
      return body;
    }
    final segments = <String>[];
    int end = body.length;
    while (end > 3) {
      final start = end - 3;
      segments.insert(0, body.substring(start, end));
      end = start;
    }
    segments.insert(0, body.substring(0, end));
    return segments.join('.');
  }
}