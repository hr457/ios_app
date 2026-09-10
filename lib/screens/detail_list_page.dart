import 'package:flutter/material.dart';
import '../models/customer_case.dart';
import '../widgets/case_card.dart' as card;
import '../utils/app_colors.dart';

class DetailListPage extends StatefulWidget {
  final String title;
  final List<CustomerCase> cases;
  final VoidCallback onChanged;

  const DetailListPage({
    super.key,
    required this.title,
    required this.cases,
    required this.onChanged,
  });

  @override
  State<DetailListPage> createState() => _DetailListPageState();
}

class _DetailListPageState extends State<DetailListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: widget.cases.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open_rounded, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No data found in ${widget.title}',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.cases.length,
              itemBuilder: (context, index) {
                return card.CaseCard(
                  item: widget.cases[index],
                  onChanged: () {
                    setState(() {});
                    widget.onChanged();
                  },
                );
              },
            ),
    );
  }
}
