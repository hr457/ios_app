import '../models/customer_case.dart';

class DemoStore {
  static final List<CustomerCase> cases = [
    CustomerCase(
      id: 1,
      customer: 'Ramesh Sharma',
      mobile: '9876543210',
      city: 'Jaipur',
      address: 'Vaishali Nagar, Jaipur',
      loanNo: 'SAFL001',
      vehicleNo: 'RJ14 AB 1234',
      type: 'LIVE',
      status: 'Pending',
      dueAmount: 12500,
      collectedAmount: 0,
      emiDue: 1,
      remarks: '',
      ptpDate: null,
      activities: [],
    ),
    CustomerCase(
      id: 2,
      customer: 'Mukesh Meena',
      mobile: '9876500001',
      city: 'Jodhpur',
      address: 'Paota, Jodhpur',
      loanNo: 'SAFL002',
      vehicleNo: 'RJ19 CD 2211',
      type: 'NS',
      status: 'Visited',
      dueAmount: 8200,
      collectedAmount: 0,
      emiDue: 2,
      remarks: 'Customer not available',
      ptpDate: null,
      activities: [],
    ),
    CustomerCase(
      id: 3,
      customer: 'Suresh Kumar',
      mobile: '9876500002',
      city: 'Jaipur',
      address: 'Mansarovar, Jaipur',
      loanNo: 'SAFL003',
      vehicleNo: 'RJ14 EF 8899',
      type: 'LIVE',
      status: 'PTP',
      dueAmount: 15300,
      collectedAmount: 0,
      emiDue: 1,
      remarks: 'Will pay this week',
      ptpDate: DateTime.now().add(const Duration(days: 2)),
      activities: [],
    ),
    CustomerCase(
      id: 4,
      customer: 'Kailash Singh',
      mobile: '9876500003',
      city: 'Kota',
      address: 'Talwandi, Kota',
      loanNo: 'SAFL004',
      vehicleNo: 'RJ20 GH 5454',
      type: 'REPO',
      status: 'Collected',
      dueAmount: 5400,
      collectedAmount: 5400,
      emiDue: 3,
      remarks: 'Full collection done',
      ptpDate: null,
      activities: [],
    ),
  ];

  static int get totalCases => cases.length;

  static int get visited =>
      cases.where((e) => ['Visited', 'Collected', 'PTP'].contains(e.status)).length;

  static int get pending => cases.where((e) => e.status == 'Pending').length;

  static int get ptp => cases.where((e) => e.status == 'PTP').length;

  static int get collectedCount =>
      cases.where((e) => e.status == 'Collected').length;

  static double get totalDue =>
      cases.fold(0, (previousValue, e) => previousValue + e.pendingAmount);

  static double get collected =>
      cases.fold(0, (previousValue, e) => previousValue + e.collectedAmount);

  static void addCase(CustomerCase item) => cases.add(item);
}