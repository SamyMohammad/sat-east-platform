import 'package:sat_east_client/features/catalogue/domain/entities/price.dart';

String formatPrice(Price price) {
  final whole = (price.amountMinor ~/ 100).toString();
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final minor = price.amountMinor % 100;
  final decimals = minor == 0 ? '' : '.${minor.toString().padLeft(2, '0')}';
  return '${price.currency} $grouped$decimals';
}
