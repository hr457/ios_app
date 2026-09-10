class TargetModel {
  final String title;
  final double targetAmount;
  final double achievedAmount;
  final int totalCases;
  final int visitedCases;
  final String month;

  TargetModel({
    required this.title,
    required this.targetAmount,
    required this.achievedAmount,
    required this.totalCases,
    required this.visitedCases,
    required this.month,
  });

  double get percentageAchieved => targetAmount > 0 ? (achievedAmount / targetAmount) * 100 : 0;
  double get pendingAmount => targetAmount - achievedAmount;

  factory TargetModel.fromJson(Map<String, dynamic> json) {
    return TargetModel(
      title: json['title'] ?? 'Monthly Target',
      targetAmount: (json['target_amount'] ?? 0.0).toDouble(),
      achievedAmount: (json['achieved_amount'] ?? 0.0).toDouble(),
      totalCases: json['total_cases'] ?? 0,
      visitedCases: json['visited_cases'] ?? 0,
      month: json['month'] ?? 'Current Month',
    );
  }
}
