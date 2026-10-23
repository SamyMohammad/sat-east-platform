import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_filter.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/topic_option.dart';
import 'package:sat_east_client/features/teacher/questions/domain/repositories/question_bank_repository.dart';
import 'package:sat_east_client/features/teacher/questions/domain/services/bank_scheduler.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_bank_state.dart';

class QuestionBankCubit extends Cubit<QuestionBankState> {
  QuestionBankCubit(
    this._repository, {
    required this.schedule,
    this.searchDelay = const Duration(milliseconds: 300),
  }) : super(const QuestionBankState(loading: true));
  final QuestionBankRepository _repository;
  final BankScheduler schedule;
  final Duration searchDelay;
  BankCancel? _cancelSearch;
  List<BankCourse>? _topics;
  var _generation = 0;
  Future<void> load() => _request(state.filter, 1);
  Future<void> retry() async {
    if (isClosed || state.loading) return;
    await _request(state.filter, state.page);
  }

  Future<void> nextPage() async {
    if (isClosed || state.loading || !(state.bank?.hasNext ?? false)) return;
    await _request(state.filter, state.page + 1);
  }

  Future<void> prevPage() async {
    if (isClosed || state.loading || !(state.bank?.hasPrevious ?? false)) {
      return;
    }
    await _request(state.filter, state.page - 1);
  }

  Future<void> setFilter(BankFilter filter) async {
    if (isClosed || filter == state.filter) return;
    final searchOnly =
        filter.q != state.filter.q &&
        filter.withValue('q', state.filter.q) == state.filter;
    if (!searchOnly) {
      await _request(filter, 1);
      return;
    }
    _cancelSearch?.call();
    final generation = ++_generation;
    _start(filter, 1);
    _cancelSearch = schedule(searchDelay, () {
      _cancelSearch = null;
      unawaited(_fetch(filter, 1, generation));
    });
  }

  Future<void> _request(BankFilter filter, int page) async {
    if (isClosed) return;
    _cancelSearch?.call();
    _cancelSearch = null;
    final generation = ++_generation;
    _start(filter, page);
    await _fetch(filter, page, generation);
  }

  void _start(BankFilter filter, int page) => emit(
    QuestionBankState(
      filter: filter,
      page: page,
      topics: _topics ?? const [],
      loading: true,
    ),
  );
  Future<void> _fetch(BankFilter filter, int page, int generation) async {
    if (_topics == null) {
      final result = await _repository.topics();
      if (isClosed || generation != _generation) return;
      switch (result) {
        case Success(:final value):
          _topics = List.unmodifiable(value);
        case Failure(:final error):
          emit(QuestionBankState(filter: filter, page: page, error: error));
          return;
      }
    }
    final result = await _repository.list(filter, page);
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Success(:final value):
        emit(
          QuestionBankState(
            filter: filter,
            page: page,
            topics: _topics!,
            bank: value,
          ),
        );
      case Failure(:final error):
        emit(
          QuestionBankState(
            filter: filter,
            page: page,
            topics: _topics!,
            error: error,
          ),
        );
    }
  }

  @override
  Future<void> close() {
    _generation++;
    _cancelSearch?.call();
    _cancelSearch = null;
    return super.close();
  }
}
