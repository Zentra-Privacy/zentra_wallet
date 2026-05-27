import 'package:flutter_test/flutter_test.dart';
import 'package:zentra_wallet/core/qr_payload_parser.dart';

void main() {
  bool validate(String a) => a.startsWith('Z') && a.length > 20;

  group('QrPayloadParser.parsePayment', () {
    test('raw address', () {
      const addr = 'Z1234567890123456789012345678901234567890';
      final p = QrPayloadParser.parsePayment(addr, validateAddress: validate);
      expect(p?.address, addr);
    });

    test('zentra scheme', () {
      const addr = 'Z1234567890123456789012345678901234567890';
      final p = QrPayloadParser.parsePayment('zentra:$addr', validateAddress: validate);
      expect(p?.address, addr);
    });

    test('monero scheme with amount', () {
      const addr = 'Z1234567890123456789012345678901234567890';
      final p = QrPayloadParser.parsePayment(
        'monero:$addr?tx_amount=1.5',
        validateAddress: validate,
      );
      expect(p?.address, addr);
      expect(p?.amountDisplay, '1.5');
    });
  });

  group('QrPayloadParser.parseDaemonAddress', () {
    test('host:port', () {
      expect(QrPayloadParser.parseDaemonAddress('127.0.0.1:17750'), '127.0.0.1:17750');
    });

    test('http url', () {
      expect(
        QrPayloadParser.parseDaemonAddress('http://node.example.com:17750'),
        'node.example.com:17750',
      );
    });
  });
}
