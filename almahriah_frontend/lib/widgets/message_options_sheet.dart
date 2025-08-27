// lib/widgets/message_options_sheet.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class MessageOptionsSheet extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDeleteForMe;
  final VoidCallback onDeleteForEveryone;

  const MessageOptionsSheet({
    super.key,
    required this.onEdit,
    required this.onDeleteForMe,
    required this.onDeleteForEveryone,
  });

  @override
  Widget build(BuildContext context) {
    HapticFeedback.lightImpact();
    return CupertinoActionSheet(
      title: Text('خيارات الرسالة', style: GoogleFonts.almarai(fontWeight: FontWeight.bold)),
      actions: <CupertinoActionSheetAction>[
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            onEdit();
          },
          child: Text('تعديل', style: GoogleFonts.almarai(color: CupertinoColors.activeBlue)),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            onDeleteForMe();
          },
          child: Text('حذف لدي', style: GoogleFonts.almarai(color: CupertinoColors.systemRed)),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            onDeleteForEveryone();
          },
          child: Text('حذف لدى الجميع', style: GoogleFonts.almarai(color: CupertinoColors.destructiveRed)),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: Text('إلغاء', style: GoogleFonts.almarai(fontWeight: FontWeight.bold)),
      ),
    );
  }
}