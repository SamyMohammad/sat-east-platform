import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf_spike/page_watermark.dart';
import 'package:pdfrx/pdfrx.dart';

/// SPIKE app (SEC-02). Config from --dart-define, overridable on web with
/// query parameters: ?server=http://host:8792&asset=notes1&user=Sara
///   &mode=memory|uri   memory = download once, open from bytes (default)
///                      uri    = let pdfrx load the signed URL itself
///   &jumpAfter=40      seconds until it jumps to the last page (expiry test)
void main() {
  const defaultServer = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'http://localhost:8792',
  );
  final q = Uri.base.queryParameters;
  runApp(
    MaterialApp(
      title: 'PDF spike',
      theme: ThemeData(useMaterial3: true),
      home: NotesScreen(
        server: Uri.parse(q['server'] ?? defaultServer),
        assetId: q['asset'] ?? 'notes1',
        user: q['user'] ?? 'Sara Ahmed',
        loadFromMemory: q['mode'] != 'uri',
        jumpAfter: int.tryParse(q['jumpAfter'] ?? ''),
      ),
    ),
  );
}

void spikeLog(String line) {
  // ignore: avoid_print — spike diagnostics, read from the console.
  print('[pdf-spike] $line');
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({
    required this.server,
    required this.assetId,
    required this.user,
    required this.loadFromMemory,
    this.jumpAfter,
    super.key,
  });

  final Uri server;
  final String assetId;
  final String user;
  final bool loadFromMemory;
  final int? jumpAfter;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _controller = PdfViewerController();
  String? _watermark;
  Uri? _url;
  Uint8List? _bytes;
  String _status = 'Requesting signed URL…';
  Timer? _jumpTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      // SPIKE: the real client calls the `api` Edge Function via supabase.functions.
      final res = await http.post(
        widget.server.resolve('/pdf-url'),
        headers: {
          'content-type': 'application/json',
          // Percent-encoded: HTTP headers cannot carry Arabic names.
          'x-spike-user': Uri.encodeComponent(widget.user),
        },
        body: jsonEncode({'assetId': widget.assetId}),
      );
      if (res.statusCode != 200) throw Exception('pdf-url ${res.statusCode}');
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final w = j['watermark'] as Map<String, dynamic>;
      final url = Uri.parse(j['url'] as String);
      Uint8List? bytes;
      if (widget.loadFromMemory) {
        // One GET while the URL is valid; the bytes live only in memory.
        final file = await http.get(url);
        if (file.statusCode != 200) throw Exception('pdf ${file.statusCode}');
        bytes = file.bodyBytes;
        spikeLog('downloaded ${bytes.length} bytes into memory');
      }
      if (!mounted) return;
      setState(() {
        _watermark = '${w['name']} · ${w['shortId']}';
        _url = url;
        _bytes = bytes;
        _status = widget.loadFromMemory
            ? 'Opened from memory'
            : 'Opened from URL';
      });
      spikeLog('opened (${widget.loadFromMemory ? 'memory' : 'uri'})');
    } on Object catch (e) {
      spikeLog('open failed: $e');
      if (mounted) setState(() => _status = 'Could not open the notes.');
    }
  }

  void _onReady(PdfDocument document, PdfViewerController controller) {
    spikeLog('ready: ${document.pages.length} pages');
    final after = widget.jumpAfter;
    if (after == null) return;
    _jumpTimer = Timer(Duration(seconds: after), () {
      spikeLog('jumping to last page ${document.pages.length}');
      unawaited(
        controller.goToPage(
          pageNumber: document.pages.length,
          duration: Duration.zero,
        ),
      );
    });
  }

  @override
  void dispose() {
    _jumpTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final watermark = _watermark;
    final params = PdfViewerParams(
      // SEC-02: nothing to copy, no context menu actions.
      textSelectionParams: const PdfTextSelectionParams(enabled: false),
      onViewerReady: _onReady,
      onPageChanged: (n) => spikeLog('page $n'),
      pageOverlaysBuilder: watermark == null
          ? null
          : (context, pageRect, page) => [PageWatermark(text: watermark)],
      errorBannerBuilder: (context, error, stackTrace, ref) {
        spikeLog('viewer error: $error');
        return const Center(child: Text('Could not load this page.'));
      },
    );
    final Widget body;
    if (_bytes != null) {
      body = PdfViewer.data(
        _bytes!,
        sourceName: widget.assetId,
        controller: _controller,
        params: params,
      );
    } else if (_url != null) {
      body = PdfViewer.uri(_url!, controller: _controller, params: params);
    } else {
      body = Center(child: Text(_status));
    }
    return Scaffold(
      appBar: AppBar(title: Text('Notes — $_status')),
      body: body,
    );
  }
}
