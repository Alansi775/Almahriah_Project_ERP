// almahriah_frontend/lib/widgets/action_widgets.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:almahriah_frontend/widgets/glassmorphism_widgets.dart';

Widget buildGlassButton({
  required BuildContext context,
  required String label,
  required IconData icon,
  required VoidCallback onPressed,
  required Color color,
}) {
  return InkWell(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(15),
    child: buildGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.almarai(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}