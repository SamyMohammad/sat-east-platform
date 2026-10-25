import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/supabase_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('LRN-02: mapFunctionException', () {
    for (final (details, status, expected) in <(Object?, int, String)>[
      (
        {
          'error': {'code': 'video_needed'},
        },
        400,
        'video_needed',
      ),
      (
        {
          'error': {'code': 'topic_locked'},
        },
        400,
        'topic_locked',
      ),
      (
        {
          'error': {'code': 'boom'},
        },
        400,
        'internal',
      ),
      (null, 401, 'not_authenticated'),
      ('plain text', 500, 'internal'),
    ]) {
      test('maps $details with status $status to $expected', () {
        expect(
          mapFunctionException(
            FunctionException(status: status, details: details),
          ).code,
          expected,
        );
      });
    }
    test('recognizes video server codes', () {
      expect(ErrorCodes.isServerCode('video_needed'), isTrue);
      expect(ErrorCodes.isServerCode('quota_exceeded'), isTrue);
      expect(ErrorCodes.isServerCode(ErrorCodes.unsupported), isFalse);
    });
  });
  for (final code in [
    'practice_needed',
    'cooldown_active',
    'deadline_passed',
  ]) {
    test('PRC-03: preserves quiz server error $code', () {
      expect(
        mapPostgrestException(PostgrestException(message: code)).code,
        code,
      );
    });
  }

  group('P1-2: mapAuthException', () {
    const cases = <String, String>{
      'invalid_credentials': ErrorCodes.invalidCredentials,
      'email_not_confirmed': ErrorCodes.emailNotConfirmed,
      'user_already_exists': ErrorCodes.emailTaken,
      'email_exists': ErrorCodes.emailTaken,
      'weak_password': ErrorCodes.weakPassword,
      'over_request_rate_limit': ErrorCodes.rateLimited,
      'over_email_send_rate_limit': ErrorCodes.rateLimited,
    };
    for (final entry in cases.entries) {
      test('P1-2: maps ${entry.key} to ${entry.value}', () {
        final error = mapAuthException(
          AuthApiException('boom', statusCode: '400', code: entry.key),
        );
        expect(error.code, entry.value);
      });
    }

    test('P1-2: maps unknown code to internal', () {
      final error = mapAuthException(
        const AuthApiException(
          'boom',
          statusCode: '500',
          code: 'something_new',
        ),
      );
      expect(error.code, ErrorCodes.internal);
    });

    test('P1-2: maps null code on AuthException to internal', () {
      expect(
        mapAuthException(const AuthException('boom')).code,
        ErrorCodes.internal,
      );
    });

    test('P1-2: maps retryable fetch exception with null code to network', () {
      expect(
        mapAuthException(AuthRetryableFetchException()).code,
        ErrorCodes.network,
      );
    });

    test('P1-2: keeps original message for logs', () {
      final error = mapAuthException(
        const AuthApiException('raw text', code: 'invalid_credentials'),
      );
      expect(error.message, 'raw text');
    });
  });

  group('P1-2: mapPostgrestException', () {
    const known = [
      ErrorCodes.notAuthenticated,
      ErrorCodes.forbidden,
      ErrorCodes.invalidInput,
      ErrorCodes.deviceLimit,
      ErrorCodes.rateLimited,
      ErrorCodes.internal,
    ];
    for (final code in known) {
      test('P1-2: maps message $code to the same code', () {
        expect(
          mapPostgrestException(PostgrestException(message: code)).code,
          code,
        );
      });
    }

    for (final code in ['not_enrolled', 'access_expired', 'topic_locked']) {
      test('L-1: mapPostgrestException keeps $code', () {
        expect(
          mapPostgrestException(PostgrestException(message: code)).code,
          code,
        );
      });
    }

    test('P1-2: maps unknown message to internal', () {
      final error = mapPostgrestException(
        const PostgrestException(message: 'relation x does not exist'),
      );
      expect(error.code, ErrorCodes.internal);
    });

    test('P1-2: keeps original message for logs', () {
      final error = mapPostgrestException(
        const PostgrestException(message: 'weird failure'),
      );
      expect(error.message, 'weird failure');
    });
  });

  group('P1-2: mapUnknownError', () {
    test('P1-2: maps SocketException to network', () {
      expect(
        mapUnknownError(const SocketException('offline')).code,
        ErrorCodes.network,
      );
    });

    test('P1-2: maps TimeoutException to network', () {
      expect(
        mapUnknownError(TimeoutException('slow')).code,
        ErrorCodes.network,
      );
    });

    test('P1-2: maps http ClientException to network', () {
      expect(mapUnknownError(ClientException('x')).code, ErrorCodes.network);
    });

    test('P1-2: maps any other error to internal', () {
      expect(mapUnknownError(StateError('bug')).code, ErrorCodes.internal);
    });
  });
}
