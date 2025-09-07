// lib/widgets/edit_message_dialog.dart

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EditMessageDialog extends StatelessWidget {
  final String initialContent;
  final Function(String) onSave;

  const EditMessageDialog({
    super.key,
    required this.initialContent,
    required this.onSave,
  });

  bool get _isIOS => !kIsWeb && Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    final TextEditingController editController = TextEditingController(text: initialContent);

    //  Conditionally render the dialog based on the platform
    if (_isIOS) {
      // 📱 iOS - Use the native-like Cupertino dialog
      return CupertinoAlertDialog(
        title: Text(
          'تعديل الرسالة',
          style: GoogleFonts.almarai(),
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: CupertinoTextField(
            controller: editController,
            autofocus: true,
            style: GoogleFonts.almarai(),
            minLines: 1,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            decoration: BoxDecoration(
              color: CupertinoColors.lightBackgroundGray,
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: GoogleFonts.almarai(color: CupertinoColors.systemRed),
            ),
          ),
          CupertinoDialogAction(
            onPressed: () {
              if (editController.text.trim().isNotEmpty) {
                onSave(editController.text.trim());
              }
              Navigator.pop(context);
            },
            child: Text(
              'حفظ',
              style: GoogleFonts.almarai(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    } else {
      // 🌐 Android & Web - Use a customized Material dialog
      return AlertDialog(
        title: Text(
          'تعديل الرسالة',
          style: GoogleFonts.almarai(fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
        ),
        backgroundColor: Colors.white,
        content: TextField(
          controller: editController,
          autofocus: true,
          cursorColor: const Color(0xFF2C3E50), // Dark blue for cursor
          style: GoogleFonts.almarai(color: Colors.black),
          minLines: 1,
          maxLines: 5,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[200], // Dark gray background
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide.none,
            ),
            hintText: 'اكتب رسالتك...',
            hintStyle: GoogleFonts.almarai(color: Colors.grey[600]),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: GoogleFonts.almarai(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (editController.text.trim().isNotEmpty) {
                onSave(editController.text.trim());
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C3E50), // Dark blue save button
            ),
            child: Text(
              'حفظ',
              style: GoogleFonts.almarai(color: Colors.white),
            ),
          ),
        ],
      );
    }
  }
}