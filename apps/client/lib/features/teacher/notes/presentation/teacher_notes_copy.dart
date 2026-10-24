import 'package:sat_east_client/core/errors/error_codes.dart';

String teacherNotesError(String code) => switch (code) {
  ErrorCodes.notesPdfRequired => 'Choose a PDF file.',
  ErrorCodes.notesInvalidPdf => "Couldn't read this PDF. Choose another file.",
  ErrorCodes.notesTooLarge => 'This PDF is too large. Choose a smaller file.',
  ErrorCodes.notesCleanupFailed =>
    "Couldn't finish cleaning up the upload. "
        'Reload and delete the draft notes.',
  ErrorCodes.forbidden => 'Only the teacher can change the notes.',
  ErrorCodes.invalidInput => "That change wasn't saved. Reload and try again.",
  'unsupported' => 'PDF uploads are available on the web.',
  _ => "Couldn't save. Check your connection and try again.",
};
