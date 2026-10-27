import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/data/models/bank_models.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_filter.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/bank_page.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/topic_option.dart';
import 'package:sat_east_client/features/teacher/questions/domain/repositories/question_bank_repository.dart';

const Map<String, Object?> bankJson = {
  'total': 3,
  'page': 1,
  'page_size': 2,
  'rows': <Object?>[
    {
      'id': 'q1',
      'external_ref': 'BANK_1',
      'stem_preview': r'Solve $x+1=2$.',
      'type': 'mcq',
      'topic_title': 'Linear equations',
      'subtopic_title': 'One step',
      'difficulty': 'M',
      'pool': 'practice',
      'status': 'published',
      'version': 2,
      'updated_at': '2026-10-24T12:00:00Z',
    },
    {
      'id': 'q2',
      'external_ref': null,
      'stem_preview': 'Second question',
      'type': 'spr',
      'topic_title': 'Linear equations',
      'subtopic_title': 'One step',
      'difficulty': 'H',
      'pool': 'quiz',
      'status': 'draft',
      'version': 1,
      'updated_at': '2026-10-24T11:00:00Z',
    },
  ],
};
const List<Object?> topicsJson = [
  {
    'course_code': 'SAT',
    'topics': <Object?>[
      {
        'id': 't1',
        'slug': 'linear',
        'title': 'Linear equations',
        'subtopics': <Object?>[
          {'id': 's1', 'slug': 'one-step', 'title': 'One step'},
        ],
      },
      {
        'id': 't2',
        'slug': 'other',
        'title': 'Other topic',
        'subtopics': <Object?>[],
      },
    ],
  },
  {'course_code': 'EST', 'topics': <Object?>[]},
];
final BankPage bankPage = bankPageFromJson(bankJson);
final List<BankCourse> bankTopics = bankTopicsFromJson(topicsJson);

class FakeBankRepository implements QuestionBankRepository {
  Result<BankPage> listResult = Success(bankPage);
  Result<List<BankCourse>> topicsResult = Success(bankTopics);
  Future<Result<BankPage>>? pendingList;
  Future<Result<List<BankCourse>>>? pendingTopics;
  final List<(BankFilter, int)> calls = [];
  int topicCalls = 0;
  @override
  Future<Result<BankPage>> list(BankFilter filter, int page) {
    calls.add((filter, page));
    return pendingList ?? Future.value(listResult);
  }

  @override
  Future<Result<List<BankCourse>>> topics() {
    topicCalls++;
    return pendingTopics ?? Future.value(topicsResult);
  }
}

class FakeBankScheduler {
  final List<void Function()> _tasks = [];
  int cancellations = 0;
  void Function() schedule(Duration delay, void Function() action) {
    _tasks.add(action);
    return () {
      if (_tasks.remove(action)) cancellations++;
    };
  }

  int get pending => _tasks.length;
  void fire() {
    final tasks = List<void Function()>.of(_tasks);
    _tasks.clear();
    for (final task in tasks) {
      task();
    }
  }
}
