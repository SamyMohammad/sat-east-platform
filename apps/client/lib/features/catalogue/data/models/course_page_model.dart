import 'package:sat_east_client/features/catalogue/data/models/catalogue_json.dart';
import 'package:sat_east_client/features/catalogue/data/models/price_model.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/course_page.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/course_unit.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/syllabus_topic.dart';

CoursePage coursePageFromJson(Map<String, Object?> json) => CoursePage(
  id: jsonString(json, 'id'),
  slug: jsonString(json, 'slug'),
  title: jsonString(json, 'title'),
  description: jsonDescription(json),
  price: priceFromJson(json['price']),
  units: jsonList(json['units'], _unitFromJson),
);

CourseUnit _unitFromJson(Map<String, Object?> json) => CourseUnit(
  title: jsonString(json, 'title'),
  topics: jsonList(json['topics'], _topicFromJson),
);

SyllabusTopic _topicFromJson(Map<String, Object?> json) {
  final free = json['is_free_preview'];
  if (free is! bool) throw const FormatException('is_free_preview');
  return SyllabusTopic(
    slug: jsonString(json, 'slug'),
    title: jsonString(json, 'title'),
    isFreePreview: free,
    subtopicCount: jsonCount(json, 'subtopic_count'),
  );
}
