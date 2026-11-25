import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/links/legal_links.dart';

void main() {
  test('P3: pages hang off the landing base URL', () {
    final links = LegalLinks('https://landing.example');

    expect(links.terms, Uri.parse('https://landing.example/terms'));
    expect(links.privacy, Uri.parse('https://landing.example/privacy'));
  });

  test('P3: a trailing slash on the base URL is ignored', () {
    final links = LegalLinks('https://landing.example/');

    expect(links.terms, Uri.parse('https://landing.example/terms'));
  });
}
