import 'package:equatable/equatable.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/price.dart';

class CatalogueCourse extends Equatable {
  const CatalogueCourse({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.topicCount,
    required this.price,
  });

  final String id;
  final String slug;
  final String title;
  final String? description;
  final int topicCount;
  final Price? price;

  @override
  List<Object?> get props => [id, slug, title, description, topicCount, price];
}
