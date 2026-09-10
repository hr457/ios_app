import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import 'main_page.dart';

class AppLauncherPage extends StatelessWidget {
  const AppLauncherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SAFL Apps')),
      body: Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const MainPage())),
          child: Container(
            width: 220,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.12),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white,
                  backgroundImage: const AssetImage('assets/logo/setialogo.jfif'),
                  onBackgroundImageError: (_, __) {},
                ),
                const SizedBox(height: 14),
                const Text(
                  'SAFL',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryRed,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Collection Visit', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
