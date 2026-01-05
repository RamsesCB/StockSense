class LoanModel {
  final int id;
  final int userId;
  final int productId;
  final DateTime loanDate;
  final DateTime returnDate;
  final String status;

  const LoanModel({
    required this.id,
    required this.userId,
    required this.productId,
    required this.loanDate,
    required this.returnDate,
    required this.status,
  });

  factory LoanModel.fromJson(Map<String, dynamic> json) {
    return LoanModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      productId: json['product_id'] as int,
      loanDate: DateTime.parse(json['loan_date'] as String),
      returnDate: DateTime.parse(json['return_date'] as String),
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'product_id': productId,
      'loan_date': loanDate.toIso8601String(),
      'return_date': returnDate.toIso8601String(),
      'status': status,
    };
  }
}
