import 'package:intl/intl.dart';

class TaskModel {
  final int? id;
  final String caseNo;
  final String remark;
  final DateTime dueDate;
  final String fromUser;
  final String toUser;
  final String status; // 'pending', 'completed'
  final DateTime createdAt;

  TaskModel({
    this.id,
    required this.caseNo,
    required this.remark,
    required this.dueDate,
    required this.fromUser,
    required this.toUser,
    this.status = 'pending',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'],
      caseNo: json['case_no'] ?? json['loan_no'] ?? '',
      remark: json['remark'] ?? json['visit_remark'] ?? '',
      dueDate: DateTime.tryParse(json['due_date'] ?? json['projection_date'] ?? json['ptp_date'] ?? '') ?? DateTime.now(),
      fromUser: json['from_user'] ?? json['tl_name'] ?? json['tc_name'] ?? '',
      toUser: json['to_user'] ?? json['exe_name'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'case_no': caseNo,
      'remark': remark,
      'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
      'from_user': fromUser,
      'to_user': toUser,
      'status': status,
    };
  }
}
