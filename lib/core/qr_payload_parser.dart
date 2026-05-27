/// Parsed QR content for send / node setup (Monero-style URIs + plain text).
class QrPaymentPayload {
  const QrPaymentPayload({
    required this.address,
    this.amountDisplay,
    this.paymentId,
  });

  final String address;
  final String? amountDisplay;
  final String? paymentId;
}

class QrPayloadParser {
  static const _paymentSchemes = ['zentra', 'monero'];

  /// Payment QR: `zentra:ADDRESS`, `monero:ADDRESS?tx_amount=1.5`, or raw address.
  static QrPaymentPayload? parsePayment(
    String raw, {
    required bool Function(String address) validateAddress,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    var body = trimmed;
    for (final scheme in _paymentSchemes) {
      final prefix = '$scheme:';
      if (body.toLowerCase().startsWith(prefix)) {
        body = body.substring(prefix.length);
        break;
      }
    }

    String addressPart = body;
    String? query;
    final q = body.indexOf('?');
    if (q >= 0) {
      addressPart = body.substring(0, q).trim();
      query = body.substring(q + 1);
    }

    // Some QR encoders use monero://ADDRESS
    if (addressPart.startsWith('//')) {
      addressPart = addressPart.substring(2);
    }

    final address = addressPart.trim();
    if (!validateAddress(address)) return null;

    String? amount;
    String? paymentId;
    if (query != null && query.isNotEmpty) {
      final params = Uri.splitQueryString(query);
      amount = params['tx_amount'] ?? params['amount'];
      paymentId = params['tx_payment_id'] ?? params['payment_id'];
      if (amount != null) {
        amount = amount.trim();
        if (amount.isEmpty) amount = null;
      }
      if (paymentId != null && paymentId.isEmpty) paymentId = null;
    }

    return QrPaymentPayload(
      address: address,
      amountDisplay: amount,
      paymentId: paymentId,
    );
  }

  /// Node QR: `host:port`, `http://host:port`, or `zentra-node:host:port`.
  static String? parseDaemonAddress(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;

    for (final prefix in ['zentra-node:', 'zentrad:', 'node:']) {
      if (s.toLowerCase().startsWith(prefix)) {
        s = s.substring(prefix.length);
        break;
      }
    }
    if (s.startsWith('//')) s = s.substring(2);

    if (s.startsWith('http://') || s.startsWith('https://')) {
      try {
        final uri = Uri.parse(s);
        final host = uri.host;
        if (host.isEmpty) return null;
        final port = uri.hasPort ? uri.port : 17750;
        return '$host:$port';
      } catch (_) {
        return null;
      }
    }

    // host:port or hostname:port
    if (RegExp(r'^[\w.\-]+:\d{1,5}$').hasMatch(s)) {
      return s;
    }
    return null;
  }
}
