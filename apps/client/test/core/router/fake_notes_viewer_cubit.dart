import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/notes/presentation/cubit/notes_viewer_cubit.dart';
import 'package:sat_east_client/features/notes/presentation/cubit/notes_viewer_state.dart';

class FakeNotesViewerCubit extends MockCubit<NotesViewerState>
    implements NotesViewerCubit {}

NotesViewerCubit fakeNotesViewerCubit() {
  final cubit = FakeNotesViewerCubit();
  whenListen(
    cubit,
    const Stream<NotesViewerState>.empty(),
    initialState: const NotesViewerFailed(AppError('network')),
  );
  when(() => cubit.load(any(), any())).thenAnswer((_) async {});
  when(cubit.close).thenAnswer((_) async {});
  return cubit;
}
