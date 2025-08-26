// lib/widgets/dashboard_widgets.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:almahriah_frontend/services/auth_service.dart';
import 'package:almahriah_frontend/pages/login_page.dart';
import 'package:almahriah_frontend/custom_page_route.dart';
import 'package:flutter/services.dart';

// يمكن استدعاء هذا الـ Widget من أي مكان
Widget buildStatTile(String title, String value, IconData icon, Color color) {
  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
    ),
    child: Container(
      // استخدام FittedBox لضمان أن المحتوى سيتلاءم مع الحجم
      child: FittedBox(
        fit: BoxFit.scaleDown, // تصغير المحتوى ليتلاءم
        alignment: Alignment.center, // ✅ تم التعديل: توسيط المحتوى
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // ✅ تم التعديل: لتوسيط الأيقونة والنص
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 32, // تكبير حجم الأيقونة
              ),
              const SizedBox(height: 12), // زيادة المسافة
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 26, // تكبير حجم الأرقام
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center, // ✅ تم الإضافة: لتوسيط النص
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: 100,
                child: Text(
                  title,
                  style: GoogleFonts.almarai(
                    fontSize: 14, // تكبير حجم العنوان
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  textAlign: TextAlign.center, // ✅ تم الإضافة: لتوسيط النص
                ),
              ),
            ],
          ),
        ),
      ),
      decoration: BoxDecoration(
        // استخدام الألوان الأصلية مع درجة شفافية أقل
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
    ),
  );
}

// يمكن استدعاء هذا الـ Widget من أي مكان
Widget buildDrawerItem(
  BuildContext context,
  IconData icon,
  String title,
  Widget? page, {
  VoidCallback? onTap,
  bool isLogout = false,
}) {
  return ListTile(
    leading: Icon(icon, color: isLogout ? Colors.red : Colors.blue.shade800),
    title: Text(
      title,
      style: GoogleFonts.almarai(fontWeight: FontWeight.w600),
    ),
    onTap: () {
      HapticFeedback.heavyImpact(); // ✅ تم إضافة الاهتزاز هنا ليتم تنفيذه دائمًا عند النقر
      if (onTap != null) {
        onTap();
      } else if (page != null) {
        Navigator.pop(context); // Close the drawer first
        Navigator.push(
          context,
          CustomPageRoute(child: page),
        );
      }
    },
  );
}

// يمكن استدعاء هذا الـ Widget من أي مكان
Widget buildSectionTitle(String title) {
  return Text(
    title,
    style: GoogleFonts.almarai(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    ),
    textAlign: TextAlign.center,
  );
}