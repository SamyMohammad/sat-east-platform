import 'package:url_launcher/url_launcher.dart' as launcher;

/// Opens a URL outside the app (a new tab on web, the browser on mobile).
/// A function type so widget tests inject a fake and never open anything.
/// Returns false when the link could not be opened.
typedef ExternalLinkLauncher = Future<bool> Function(Uri url);

Future<bool> launchExternalLink(Uri url) async {
  try {
    return await launcher.launchUrl(
      url,
      mode: launcher.LaunchMode.externalApplication,
    );
  } on Object {
    return false;
  }
}
