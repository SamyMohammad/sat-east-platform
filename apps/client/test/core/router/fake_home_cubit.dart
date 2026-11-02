import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/di/injection.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/home/domain/entities/home_summary.dart';
import 'package:sat_east_client/features/home/domain/usecases/get_home_summary.dart';
import 'package:sat_east_client/features/home/presentation/cubit/home_cubit.dart';

class _GetHomeSummary extends Mock implements GetHomeSummary {}

Future<void> registerFakeHomeCubit() async {
  await unregisterFakeHomeCubit();
  getIt.registerFactory<HomeCubit>(() {
    final getSummary = _GetHomeSummary();
    when(getSummary.call).thenAnswer(
      (_) async => const Success(HomeNotEnrolled('Student')),
    );
    return HomeCubit(getSummary);
  });
}

Future<void> unregisterFakeHomeCubit() async {
  if (getIt.isRegistered<HomeCubit>()) {
    await getIt.unregister<HomeCubit>();
  }
}
