import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/features/course_map/domain/entities/course_map.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_cubit.dart';
import 'package:sat_east_client/features/course_map/presentation/cubit/course_map_state.dart';

class FakeCourseMapCubit extends MockCubit<CourseMapState>
    implements CourseMapCubit {}

const completedMapTopic = MapTopic(
  id: 't1',
  slug: 'linear',
  title: 'Linear equations',
  sortLabel: '1.1',
  isFreePreview: true,
  status: TopicStatus.completed,
  lockReason: null,
);
const openMapTopic = MapTopic(
  id: 't2',
  slug: 'systems',
  title: 'Systems',
  sortLabel: '1.2',
  isFreePreview: false,
  status: TopicStatus.open,
  lockReason: null,
);
const lockedMapTopic = MapTopic(
  id: 't3',
  slug: 'quadratics',
  title: 'Quadratics',
  sortLabel: '2.1',
  isFreePreview: false,
  status: TopicStatus.locked,
  lockReason: PreviousQuiz('Systems'),
);

CourseMap courseMapFixture({
  ContinueTopic? continueTopic,
  List<MapUnit>? units,
}) => CourseMap(
  courseId: 'c1',
  slug: 'sat-math',
  title: 'SAT Math',
  continueTopic: continueTopic,
  units:
      units ??
      const [
        MapUnit(title: 'Algebra', topics: [completedMapTopic, openMapTopic]),
        MapUnit(title: null, topics: [lockedMapTopic]),
      ],
);

const continueMapTopic = ContinueTopic(
  topicId: 't2',
  slug: 'systems',
  title: 'Systems',
  unitTitle: 'Algebra',
);

FakeCourseMapCubit courseMapCubit(CourseMapState state) {
  final cubit = FakeCourseMapCubit();
  whenListen(cubit, const Stream<CourseMapState>.empty(), initialState: state);
  when(cubit.retry).thenAnswer((_) async {});
  return cubit;
}
