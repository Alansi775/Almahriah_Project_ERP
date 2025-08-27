// lib/widgets/edit_message_dialog.dart

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

  @override
  Widget build(BuildContext context) {
    final TextEditingController editController = TextEditingController(text: initialContent);

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
  }
}