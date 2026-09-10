import 'package:flutter/material.dart';

// --- Premium FinCollection Blue Palette ---
const Color primaryBlue = Color(0xFF2D5CFE);
const Color accentBlue = Color(0xFFE9EFFF);
const Color infoBlue = Color(0xFF3B82F6);

const Color darkBg = Color(0xFF0F172A);
const Color bodyBg = Color(0xFFF8FAFC);
const Color surfaceWhite = Colors.white;

const Color textHeading = Color(0xFF1E293B);
const Color textBody = Color(0xFF475569);
const Color textMuted = Color(0xFF94A3B8);

const Color successGreen = Color(0xFF10B981);
const Color primaryRed = Color(0xFFEF4444);
const Color warningOrange = Color(0xFFF59E0B);

// Compatibility names (Mapping back to previous names to avoid breaking code)
const Color primaryRedCompat = primaryRed;
const Color secondaryRedCompat = warningOrange;
const Color primaryGreen = successGreen;
const Color primaryOrange = warningOrange;

// Decorations
const double kGlassRadius = 32.0;

BoxDecoration premiumCardDecoration({Color? color, double radius = kGlassRadius}) {
  return BoxDecoration(
    color: (color ?? surfaceWhite).withValues(alpha: 0.12), // iOS 26 Ultra-translucency
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.25), // Hairline glass border
      width: 1.2,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.015),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

final BoxDecoration sleekCard = premiumCardDecoration();

const LinearGradient mainGradient = LinearGradient(
  colors: [Color(0xFF2D5CFE), Color(0xFF1E40AF)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient premiumGradient = mainGradient;
