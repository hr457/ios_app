import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:safl/models/customer_case.dart';
import 'package:safl/widgets/theme.dart';

String money(num v) => NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0).format(v);

Widget statusChip(String status) {
  final color = status == 'Collected' ? Colors.green : status == 'PTP' ? Colors.orange : status == 'Visited' ? Colors.blue : status == 'Part Payment' ? Colors.purple : primaryRed;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
    child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
  );
}

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  const KpiCard({super.key, required this.title, required this.value, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: cardDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: primaryRed),
            const Spacer(),
            Text(title, style: const TextStyle(color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
        ),
      );
}

class CaseCard extends StatelessWidget {
  final CustomerCase item;
  final VoidCallback onTap;
  const CaseCard({super.key, required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(item.customer, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), statusChip(item.status)]),
            const SizedBox(height: 8),
            Text('${item.loanNo} • ${item.mobile} • ${item.city}'),
            const SizedBox(height: 8),
            Text('Due: ${money(item.dueAmount)} | Paid: ${money(item.collectedAmount)} | EMI: ${item.emiDue}', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (item.remarks.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Remarks: ${item.remarks}')),
            const SizedBox(height: 8),
            const Align(alignment: Alignment.centerRight, child: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)),
          ]),
        ),
      );
}
