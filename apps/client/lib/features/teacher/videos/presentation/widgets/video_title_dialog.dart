import 'package:flutter/material.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/teacher_video.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/teacher_videos_copy.dart';

class VideoTitleDialog extends StatefulWidget {
  const VideoTitleDialog({required this.title, super.key});
  final String title;
  @override
  State<VideoTitleDialog> createState() => _VideoTitleDialogState();
}

class _VideoTitleDialogState extends State<VideoTitleDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.title);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    if (_form.currentState!.validate()) {
      Navigator.of(context).pop(_title.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(TeacherVideosCopy.rename),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _title,
        autofocus: true,
        maxLength: 120,
        textDirection: TextDirection.ltr,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: TeacherVideosCopy.titleLabel,
        ),
        validator: (v) => TeacherVideo.validTitle(v ?? '')
            ? null
            : TeacherVideosCopy.titleRequired,
        onFieldSubmitted: (_) => _save(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text(TeacherVideosCopy.cancel),
      ),
      FilledButton(onPressed: _save, child: const Text(TeacherVideosCopy.save)),
    ],
  );
}
