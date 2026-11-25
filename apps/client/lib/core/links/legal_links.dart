import 'package:sat_east_client/core/env/env.dart';

/// The Terms and Privacy pages, served by the landing site.
class LegalLinks {
  LegalLinks([String? landingUrl])
    : _base = (landingUrl ?? Env.landingUrl).replaceFirst(RegExp(r'/+$'), '');

  final String _base;

  Uri get terms => Uri.parse('$_base/terms');

  Uri get privacy => Uri.parse('$_base/privacy');
}
