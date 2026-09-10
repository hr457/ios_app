import 'package:flutter/material.dart';
import 'dart:math';
import '../utils/app_colors.dart';

class EmiCalculatorPage extends StatefulWidget {
  const EmiCalculatorPage({super.key});

  @override
  State<EmiCalculatorPage> createState() => _EmiCalculatorPageState();
}

class _EmiCalculatorPageState extends State<EmiCalculatorPage> {
  final _amountController = TextEditingController();
  final _interestController = TextEditingController();
  final _tenureController = TextEditingController();

  double _emi = 0.0;
  double _totalInterest = 0.0;
  double _totalPayment = 0.0;

  void _calculate() {
    double p = double.tryParse(_amountController.text) ?? 0.0;
    double r = double.tryParse(_interestController.text) ?? 0.0;
    double n = double.tryParse(_tenureController.text) ?? 0.0;

    if (p > 0 && r > 0 && n > 0) {
      r = r / (12 * 100); // Monthly interest rate
      double emi = (p * r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
      
      setState(() {
        _emi = emi;
        _totalPayment = emi * n;
        _totalInterest = _totalPayment - p;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bodyBg,
      appBar: AppBar(
        title: const Text('EMI Calculator', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: surfaceWhite,
        foregroundColor: textHeading,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildResultCard(),
            const SizedBox(height: 32),
            _buildInputFields(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _calculate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("CALCULATE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: mainGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: primaryBlue.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          const Text("Monthly EMI", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("₹ ${_emi.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900)),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _subResult("Total Interest", "₹ ${_totalInterest.toStringAsFixed(0)}"),
              _subResult("Total Amount", "₹ ${_totalPayment.toStringAsFixed(0)}"),
            ],
          )
        ],
      ),
    );
  }

  Widget _subResult(String label, String val) => Column(
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(val, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    ],
  );

  Widget _buildInputFields() {
    return Column(
      children: [
        _input("Loan Amount", _amountController, Icons.currency_rupee, "e.g. 500000"),
        const SizedBox(height: 20),
        _input("Interest Rate (%)", _interestController, Icons.percent, "e.g. 12.5"),
        const SizedBox(height: 20),
        _input("Tenure (Months)", _tenureController, Icons.calendar_today, "e.g. 36"),
      ],
    );
  }

  Widget _input(String label, TextEditingController ctrl, IconData icon, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: premiumCardDecoration(),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: textMuted, fontWeight: FontWeight.bold),
          hintText: hint,
          prefixIcon: Icon(icon, color: primaryBlue, size: 20),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
