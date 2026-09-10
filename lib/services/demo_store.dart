import 'package:safl/models/customer_case.dart';

class DemoStore {
  DemoStore._();
  static final DemoStore instance = DemoStore._();

  final List<CustomerCase> cases = [];

  Future<void> init() async {
    if (cases.isNotEmpty) return;
    cases.addAll([
      CustomerCase(id: 1, customer: 'Ramesh Sharma', mobile: '9876543210', city: 'Jaipur', address: 'Vaishali Nagar, Jaipur', vehicleNo: 'RJ14AB1234', loanNo: 'SAFL1001', type: 'LIVE', status: 'Pending', dueAmount: 12500, emiDue: 1),
      CustomerCase(id: 2, customer: 'Mukesh Meena', mobile: '9876500001', city: 'Jodhpur', address: 'Paota, Jodhpur', vehicleNo: 'RJ19CD2222', loanNo: 'SAFL1002', type: 'NS', status: 'Visited', dueAmount: 8200, emiDue: 2, remarks: 'Customer not available'),
      CustomerCase(id: 3, customer: 'Suresh Kumar', mobile: '9876500002', city: 'Jaipur', address: 'Mansarovar, Jaipur', vehicleNo: 'RJ14EF3333', loanNo: 'SAFL1003', type: 'LIVE', status: 'PTP', dueAmount: 15300, emiDue: 1, ptpDate: DateTime.now().add(const Duration(days: 3))),
      CustomerCase(id: 4, customer: 'Kailash Singh', mobile: '9876500003', city: 'Kota', address: 'Talwandi, Kota', vehicleNo: 'RJ20GH4444', loanNo: 'SAFL1004', type: 'REPO', status: 'Collected', dueAmount: 5400, collectedAmount: 5400, emiDue: 3),
    ]);
  }

  void addCase(CustomerCase c) => cases.add(c);

  void markVisit(CustomerCase c, String remarks) {
    c.status = 'Visited';
    c.remarks = remarks;
    c.activities.add(CaseActivity(dateTime: DateTime.now(), title: 'Visit Done', description: remarks));
  }

  void collect(CustomerCase c, double amount, String mode, String remarks) {
    c.collectedAmount += amount;
    c.remarks = remarks;
    c.status = c.pendingAmount <= 0 ? 'Collected' : 'Part Payment';
    c.activities.add(CaseActivity(dateTime: DateTime.now(), title: 'Payment Collected', description: '$mode - $remarks', amount: amount));
  }

  void setPtp(CustomerCase c, DateTime date, double amount, String remarks) {
    c.status = 'PTP';
    c.ptpDate = date;
    c.remarks = remarks;
    c.activities.add(CaseActivity(dateTime: DateTime.now(), title: 'PTP Added', description: '₹${amount.toStringAsFixed(0)} on ${date.day}/${date.month}/${date.year}. $remarks', amount: amount));
  }
}
