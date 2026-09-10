import 'package:flutter/material.dart';
import 'package:safl/screens/main_shell.dart';
import 'package:safl/widgets/theme.dart';

class LauncherScreen extends StatelessWidget {
  const LauncherScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('SAFL Apps')),
        body: Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MainShell())),
            child: Container(
              width: 190,
              padding: const EdgeInsets.all(24),
              decoration: cardDecoration(),
              child: const Column(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(radius: 44, backgroundColor: primaryRed, child: Text('S', style: TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold))),
                SizedBox(height: 14),
                Text('SAFL', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryRed)),
                SizedBox(height: 4),
                Text('Collection Visit', textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      );
}
