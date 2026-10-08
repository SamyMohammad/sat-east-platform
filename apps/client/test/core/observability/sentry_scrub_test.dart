import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/observability/sentry_error_reporter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('redactUrl', () {
    test('F-5 drops query strings (signed Storage URLs hold tokens)', () {
      expect(
        redactUrl(
          'https://x.supabase.co/storage/v1/object/sign/notes/a.pdf?token=abc',
        ),
        'https://x.supabase.co/storage/v1/object/sign/notes/a.pdf',
      );
    });

    test('F-5 replaces token path segments (video playlist URLs)', () {
      const token =
          'eyJrIjoicCIsImEiOiJkZW1vMSJ9.'
          'O5ZgfPz67HuSFvjDhiz31N4Ad4wvX0WaqZvEFDO0b2Y';
      expect(
        redactUrl('https://api.example.com/functions/v1/api/v/$token/key'),
        'https://api.example.com/functions/v1/api/v/:token/key',
      );
    });

    test('F-5 non-URLs are replaced', () {
      expect(redactUrl('not a url'), '[url]');
    });
  });

  test('F-5 scrubEvent keeps only the user id and no request secrets', () {
    final event = SentryEvent(
      user: SentryUser(
        id: 'user-uuid',
        email: 'student@example.com',
        ipAddress: '1.2.3.4',
        name: 'Sara',
      ),
      request: SentryRequest(
        method: 'POST',
        url: 'https://x.supabase.co/rest/v1/rpc/submit_attempt?select=*',
        headers: {'Authorization': 'Bearer secret-jwt'},
        cookies: 'sb-access-token=secret',
        data: {'answers': 'A,B,C'},
      ),
      breadcrumbs: [
        Breadcrumb.http(
          url: Uri.parse(
            'https://x.supabase.co/storage/v1/object/sign/a?token=t',
          ),
          method: 'GET',
        ),
      ],
    );

    final scrubbed = scrubEvent(event);

    expect(scrubbed.user?.id, 'user-uuid');
    expect(scrubbed.user?.email, isNull);
    expect(scrubbed.user?.ipAddress, isNull);
    expect(scrubbed.user?.name, isNull);
    expect(scrubbed.request?.method, 'POST');
    expect(
      scrubbed.request?.url,
      'https://x.supabase.co/rest/v1/rpc/submit_attempt',
    );
    expect(scrubbed.request?.headers, isEmpty);
    expect(scrubbed.request?.cookies, isNull);
    expect(scrubbed.request?.data, isNull);
    expect(
      scrubbed.breadcrumbs!.single.data!['url'],
      'https://x.supabase.co/storage/v1/object/sign/a',
    );
  });

  test('F-5 scrubBreadcrumb drops bodies and headers', () {
    final crumb = Breadcrumb(
      data: {
        'request_body': '{"answer":"B"}',
        'response_body': '{"key":"B"}',
        'headers': {'Authorization': 'Bearer x'},
        'status_code': 200,
      },
    );
    expect(scrubBreadcrumb(crumb)!.data, {'status_code': 200});
    expect(scrubBreadcrumb(null), isNull);
  });
}
