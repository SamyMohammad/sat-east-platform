import 'package:equatable/equatable.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/course_unit.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/price.dart';

class CoursePage extends Equatable {
  const CoursePage({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.price,
    required this.units,
  });

  final String id;
  final String slug;
  final String title;
  final String? description;
  final Price? price;
  final List<CourseUnit> units;

  @override
  List<Object?> get props => [id, slug, title, description, price, units];
}
