import 'package:sat_east_client/features/catalogue/data/models/catalogue_json.dart';
import 'package:sat_east_client/features/catalogue/domain/entities/price.dart';

Price? priceFromJson(Object? value) {
  if (value == null) return null;
  final json = jsonObject(value);
  return Price(
    currency: jsonString(json, 'currency'),
    amountMinor: jsonCount(json, 'amount_minor'),
  );
}
