typedef BankCancel = void Function();
typedef BankScheduler =
    BankCancel Function(Duration delay, void Function() action);
