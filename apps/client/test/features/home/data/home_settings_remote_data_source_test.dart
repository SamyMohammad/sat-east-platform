import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/error_codes.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/home/data/datasources/home_settings_remote_data_source.dart';
import 'package:sat_east_client/features/home/data/repositories/home_settings_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('LRN-07: reads integer value', () async {
    var reads = 0;
    final source = HomeSettingsRemoteDataSource(
      readWarnDays: () async {
        reads++;
        return {'value': 14};
      },
    );
    expect((await source.expiryWarnDays() as Success<int>).value, 14);
    expect(reads, 1);
  });
  test('LRN-07: PostgrestException maps to AppError', () async {
    final source = HomeSettingsRemoteDataSource(
      readWarnDays: () async {
        throw const PostgrestException(message: ErrorCodes.forbidden);
      },
    );
    expect(
      (await source.expiryWarnDays() as Failure<int>).error,
      const AppError(ErrorCodes.forbidden, ErrorCodes.forbidden),
    );
  });
  test('LRN-07: non-integer value -> invalid_input Failure', () async {
    for (final value in <Object?>[null, '14', 14.0, true, [], {}]) {
      final source = HomeSettingsRemoteDataSource(
        readWarnDays: () async => {'value': value},
      );
      expect(
        (await source.expiryWarnDays() as Failure<int>).error.code,
        ErrorCodes.invalidInput,
      );
    }
  });
  test('LRN-07: missing value -> invalid_input Failure', () async {
    final source = HomeSettingsRemoteDataSource(readWarnDays: () async => {});
    expect(
      (await source.expiryWarnDays() as Failure<int>).error.code,
      ErrorCodes.invalidInput,
    );
  });
  test('LRN-07: transport exception maps to network', () async {
    final source = HomeSettingsRemoteDataSource(
      readWarnDays: () async {
        throw const SocketException('offline');
      },
    );
    expect(
      (await source.expiryWarnDays() as Failure<int>).error.code,
      ErrorCodes.network,
    );
  });
  test('LRN-07: unknown exception maps to internal', () async {
    final source = HomeSettingsRemoteDataSource(
      readWarnDays: () async {
        throw StateError('unexpected');
      },
    );
    expect(
      (await source.expiryWarnDays() as Failure<int>).error.code,
      ErrorCodes.internal,
    );
  });
  test('LRN-07: settings repository passes success through', () async {
    final repository = HomeSettingsRepositoryImpl(
      HomeSettingsRemoteDataSource(readWarnDays: () async => {'value': 7}),
    );
    expect((await repository.expiryWarnDays() as Success<int>).value, 7);
  });
  test('LRN-07: settings repository passes failure through', () async {
    final repository = HomeSettingsRepositoryImpl(
      HomeSettingsRemoteDataSource(
        readWarnDays: () async => {'value': 'invalid'},
      ),
    );
    expect(
      (await repository.expiryWarnDays() as Failure<int>).error.code,
      ErrorCodes.invalidInput,
    );
  });
}
