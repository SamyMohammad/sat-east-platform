import 'package:flutter/material.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/videos/domain/entities/teacher_video.dart';
import 'package:sat_east_client/features/teacher/videos/domain/video_duration.dart';
import 'package:sat_east_client/features/teacher/videos/domain/youtube_id.dart';
import 'package:sat_east_client/features/teacher/videos/presentation/teacher_videos_copy.dart';

typedef YoutubeVideoDraft = ({String title, String input, int durationS});

class AddYoutubeDialog extends StatefulWidget {
  const AddYoutubeDialog({super.key});
  @override
  State<AddYoutubeDialog> createState() => _AddYoutubeDialogState();
}

class _AddYoutubeDialogState extends State<AddYoutubeDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _input = TextEditingController();
  final _duration = TextEditingController();
  @override
  void dispose() {
    _title.dispose();
    _input.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop<YoutubeVideoDraft>((
      title: _title.text.trim(),
      input: _input.text.trim(),
      durationS: parseVideoDuration(_duration.text)!,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(TeacherVideosCopy.addYoutube),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: BookletSize.dialogWidth),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: BookletSpace.s3,
            children: [
              TextFormField(
                key: const ValueKey('youtube-title'),
                controller: _title,
                autofocus: true,
                maxLength: 120,
                textDirection: detectTextDirection(_title.text),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: TeacherVideosCopy.titleLabel,
                ),
                validator: (v) => TeacherVideo.validTitle(v ?? '')
                    ? null
                    : TeacherVideosCopy.titleRequired,
              ),
              TextFormField(
                key: const ValueKey('youtube-input'),
                controller: _input,
                decoration: const InputDecoration(
                  labelText: TeacherVideosCopy.youtubeLabel,
                ),
                validator: (v) => parseYoutubeId(v ?? '') == null
                    ? TeacherVideosCopy.youtubeRequired
                    : null,
              ),
              TextFormField(
                key: const ValueKey('youtube-duration'),
                controller: _duration,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: TeacherVideosCopy.durationLabel,
                ),
                validator: (v) => parseVideoDuration(v ?? '') == null
                    ? TeacherVideosCopy.durationRequired
                    : null,
                onFieldSubmitted: (_) => _save(),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text(TeacherVideosCopy.cancel),
      ),
      FilledButton(onPressed: _save, child: const Text(TeacherVideosCopy.add)),
    ],
  );
}
