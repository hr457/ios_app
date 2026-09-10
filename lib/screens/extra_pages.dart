import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../data/demo_store.dart';

class CashDepositionPage extends StatelessWidget {
  const CashDepositionPage({super.key});
  @override
  Widget build(BuildContext context) => _SimpleScaffold(
        title: 'Cash Deposition',
        child: Column(
          children: [
            _InfoCard(title: 'Today Collection', value: '₹${DemoStore.collected.toStringAsFixed(0)}', icon: Icons.payments),
            const SizedBox(height: 12),
            _InfoCard(title: 'Pending Deposit', value: '₹${DemoStore.collected.toStringAsFixed(0)}', icon: Icons.account_balance),
            const SizedBox(height: 18),
            TextField(decoration: _input('Deposit Amount')),
            const SizedBox(height: 12),
            TextField(decoration: _input('Bank / Branch')),
            const SizedBox(height: 12),
            TextField(maxLines: 3, decoration: _input('Remarks')),
            const SizedBox(height: 18),
            _primaryButton(context, 'Submit Deposition'),
          ],
        ),
      );
}

class ExpenseManagementPage extends StatelessWidget {
  const ExpenseManagementPage({super.key});
  @override
  Widget build(BuildContext context) => _SimpleScaffold(
        title: 'Expense Management',
        child: Column(
          children: [
            _InfoCard(title: 'This Month Expense', value: '₹0', icon: Icons.receipt_long),
            const SizedBox(height: 18),
            TextField(decoration: _input('Expense Title')),
            const SizedBox(height: 12),
            TextField(keyboardType: TextInputType.number, decoration: _input('Amount')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: _input('Category'),
              items: ['Fuel', 'Food', 'Travel', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (_) {},
            ),
            const SizedBox(height: 18),
            _primaryButton(context, 'Save Expense'),
          ],
        ),
      );
}

class LeaveManagementPage extends StatelessWidget {
  final bool showHistory;
  const LeaveManagementPage({super.key, this.showHistory = false});
  @override
  Widget build(BuildContext context) => _SimpleScaffold(
        title: showHistory ? 'Leave History' : 'Leave Management',
        child: showHistory
            ? Column(children: const [
                _HistoryTile(title: 'Casual Leave', subtitle: 'Pending approval • 01 Jul 2026'),
                _HistoryTile(title: 'Sick Leave', subtitle: 'Approved • 15 Jun 2026'),
              ])
            : Column(
                children: [
                  DropdownButtonFormField<String>(
                    decoration: _input('Leave Type'),
                    items: ['Casual Leave', 'Sick Leave', 'Paid Leave'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (_) {},
                  ),
                  const SizedBox(height: 12),
                  TextField(decoration: _input('From Date')),
                  const SizedBox(height: 12),
                  TextField(decoration: _input('To Date')),
                  const SizedBox(height: 12),
                  TextField(maxLines: 3, decoration: _input('Reason')),
                  const SizedBox(height: 18),
                  _primaryButton(context, 'Apply Leave'),
                ],
              ),
      );
}

class PayrollPage extends StatelessWidget {
  const PayrollPage({super.key});
  @override
  Widget build(BuildContext context) => _SimpleScaffold(
        title: 'Payroll',
        child: Column(
          children: const [
            _InfoCard(title: 'Current Month Salary', value: '₹0', icon: Icons.wallet),
            SizedBox(height: 12),
            _HistoryTile(title: 'Salary Slip', subtitle: 'No salary slip available'),
          ],
        ),
      );
}

class ManagerDetailsPage extends StatelessWidget {
  const ManagerDetailsPage({super.key});
  @override
  Widget build(BuildContext context) => _SimpleScaffold(
        title: 'Manager Details',
        child: Column(
          children: const [
            CircleAvatar(radius: 42, backgroundColor: primaryBlue, child: Icon(Icons.person, size: 45, color: Colors.white)),
            SizedBox(height: 14),
            Text('Branch Manager', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            _HistoryTile(title: 'Name', subtitle: 'Admin'),
            _HistoryTile(title: 'Mobile', subtitle: '7727091111'),
            _HistoryTile(title: 'Email', subtitle: 'care@setiafinance.com'),
          ],
        ),
      );
}

class CustomerManagementPage extends StatelessWidget {
  const CustomerManagementPage({super.key});
  @override
  Widget build(BuildContext context) => _SimpleScaffold(
        title: 'Customer Management',
        child: Column(
          children: [
            TextField(decoration: _input('Search Customer / Mobile / Loan No')),
            const SizedBox(height: 14),
            ...DemoStore.cases.map((e) => _HistoryTile(title: e.customer, subtitle: '${e.mobile} • ${e.loanNo} • ₹${e.pendingAmount.toStringAsFixed(0)}')).toList(),
          ],
        ),
      );
}

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});
  @override
  Widget build(BuildContext context) => _SimpleScaffold(
        title: 'About Us',
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SETIA AUTO FINANCE (P) LTD.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryRed)),
            SizedBox(height: 12),
            Text('SAFL Collection app helps executives manage allocations, visits, collections, receipts and reports.'),
            SizedBox(height: 18),
            _HistoryTile(title: 'Helpline', subtitle: '7727091111'),
            _HistoryTile(title: 'Website', subtitle: 'https://www.setiafinance.com'),
          ],
        ),
      );
}

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});
  @override
  Widget build(BuildContext context) => _SimpleScaffold(
        title: 'Notification',
        child: const Column(
          children: [
            _HistoryTile(title: 'New allocation', subtitle: 'No new allocation received'),
            _HistoryTile(title: 'Payment reminder', subtitle: 'No pending reminder'),
          ],
        ),
      );
}

class _SimpleScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const _SimpleScaffold({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: Text(title), backgroundColor: primaryBlue, foregroundColor: Colors.white),
        body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child),
      );
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _InfoCard({required this.title, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: appCardDecoration(),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: primaryBlue.withOpacity(.12), child: Icon(icon, color: primaryBlue)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _HistoryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  const _HistoryTile({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: appCardDecoration(radius: 16),
        child: ListTile(title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(subtitle)),
      );
}

InputDecoration _input(String label) => InputDecoration(labelText: label, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)));

Widget _primaryButton(BuildContext context, String text) => SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$text saved'))),
        child: Text(text),
      ),
    );
