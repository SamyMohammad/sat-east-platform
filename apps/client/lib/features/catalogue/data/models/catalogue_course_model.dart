import 'package:sat_east_client/features/catalogue/data/models/catalogue_json.dart';
import 'package:sat_east_client/features/catalogue/data/models/price_model.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/catalogue_course.dart';

CatalogueCourse catalogueCourseFromJson(Map<String, Object?> json) =>
    CatalogueCourse(
      id: jsonString(json, 'id'),
      slug: jsonString(json, 'slug'),
      title: jsonString(json, 'title'),
      description: jsonDescription(json),
      topicCount: jsonCount(json, 'topic_count'),
      price: priceFromJson(json['price']),
    );
