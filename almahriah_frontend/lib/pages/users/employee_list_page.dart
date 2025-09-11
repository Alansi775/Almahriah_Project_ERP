// almahriah_frontend/lib/pages/employee_list_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:almahriah_frontend/models/user.dart';

class EmployeeListPage extends StatelessWidget {
  final User user;
  const EmployeeListPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'قائمة الموظفين',
          style: GoogleFonts.almarai(),
        ),
      ),
      body: const Center(
        child: Text(
          'هنا سيتم عرض قائمة بجميع الموظفين',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}