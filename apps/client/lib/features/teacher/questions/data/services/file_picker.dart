import 'package:sat_east_client/features/teacher/questions/data/services/file_picker_stub.dart'
    if (dart.library.js_interop) 'package:sat_east_client/features/teacher/questions/data/services/file_picker_web.dart'
    as platform;
import 'package:sat_east_client/features/teacher/questions/domain/services/file_picker_service.dart';

FilePickerService createFilePicker() => platform.createFilePicker();
