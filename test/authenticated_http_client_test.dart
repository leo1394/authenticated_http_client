import 'package:authenticated_http_client/authenticated_http_client.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    final awesome = AuthenticatedHttpClient.getInstance();

    setUp(() {
      // Additional setup goes here.
    });

    test('First Test', () {
      expect(awesome.toString(), isTrue);
    });
  });
}
