import 'package:equatable/equatable.dart';

class Price extends Equatable {
  const Price({
    required this.currency,
    required this.amountMinor,
  });

  final String currency;
  final int amountMinor;

  @override
  List<Object?> get props => [currency, amountMinor];
}
