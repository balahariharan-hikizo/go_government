class TransactionModel {
  final String id;
  final String title;
  final String subtitle;
  final String date;
  final String amount;
  final bool isCredit;
  final String status;
  final String type;

  TransactionModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.amount,
    this.isCredit = false,
    this.status = 'Completed',
    this.type = 'UPI',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'date': date,
      'amount': amount,
      'isCredit': isCredit,
      'status': status,
      'type': type,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      amount: map['amount']?.toString() ?? '',
      isCredit: map['isCredit'] as bool? ?? false,
      status: map['status']?.toString() ?? 'Completed',
      type: map['type']?.toString() ?? 'UPI',
    );
  }
}
