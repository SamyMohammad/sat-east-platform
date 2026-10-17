import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/features/topic/presentation/cubit/topic_cubit.dart';
import 'package:sat_east_client/features/topic/presentation/cubit/topic_state.dart';

import '../../features/topic/topic_fixture.dart';

class FakeTopicCubit extends MockCubit<TopicState> implements TopicCubit {}

Future<void> registerFakeTopicCubit({
  TopicState? state,
  void Function(String)? onLoad,
}) async {
  await unregisterFakeTopicCubit();
  getIt.registerFactory<TopicCubit>(() {
    final cubit = FakeTopicCubit();
    whenListen(
      cubit,
      const Stream<TopicState>.empty(),
      initialState: state ?? const TopicLoaded(topicFixture),
    );
    when(() => cubit.load(any())).thenAnswer((invocation) async {
      onLoad?.call(invocation.positionalArguments.single as String);
    });
    when(cubit.close).thenAnswer((_) async {});
    return cubit;
  });
}

Future<void> unregisterFakeTopicCubit() async {
  if (getIt.isRegistered<TopicCubit>()) {
    await getIt.unregister<TopicCubit>();
  }
}
