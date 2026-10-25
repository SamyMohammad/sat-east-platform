final _youtubeId = RegExp(r'^[A-Za-z0-9_-]{11}$');

String? parseYoutubeId(String input) {
  final text = input.trim();
  if (_youtubeId.hasMatch(text)) {
    return text;
  }
  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  if (uri == null ||
      uri.userInfo.isNotEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  final segments = uri.pathSegments;
  final host = uri.host.toLowerCase();
  String? id;
  if (host == 'youtu.be' || host == 'www.youtu.be') {
    if (segments.length == 1) id = segments.single;
  } else if (host == 'youtube.com' ||
      host == 'www.youtube.com' ||
      host == 'm.youtube.com') {
    if (segments.length == 1 && segments.single == 'watch') {
      id = uri.queryParameters['v'];
    } else if (segments.length == 2 &&
        (segments.first == 'embed' || segments.first == 'shorts')) {
      id = segments.last;
    }
  }
  return id != null && _youtubeId.hasMatch(id) ? id : null;
}
