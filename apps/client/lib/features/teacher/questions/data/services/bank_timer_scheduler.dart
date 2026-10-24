import 'dart:async';

import 'package:sat_east_client/features/teacher/questions/domain/services/bank_scheduler.dart';

BankCancel scheduleBankSearch(Duration delay, void Function() action) {
  final timer = Timer(delay, action);
  return timer.cancel;
}
