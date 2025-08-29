// lib/widgets/message_options_sheet.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

const platform = MethodChannel("com.almahriah.app/dialog");

class MessageOptionsSheet extends StatelessWidget {
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleteForMe;
  final VoidCallback? onSelect;

  const MessageOptionsSheet({
    super.key,
    this.onReply,
    this.onEdit,
    this.onDeleteForMe,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    HapticFeedback.lightImpact();

    List<CupertinoActionSheetAction> actions = [];

    if (onSelect != null) {
      actions.add(
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            onSelect!();
          },
          child: Text('تحديد', style: GoogleFonts.almarai(color: CupertinoColors.activeBlue)),
        ),
      );
    }
    
    if (onReply != null) {
      actions.add(
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            onReply!();
          },
          child: Text('رد', style: GoogleFonts.almarai(color: CupertinoColors.activeBlue)),
        ),
      );
    }
    
    if (onEdit != null) {
      actions.add(
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            onEdit!();
          },
          child: Text('تعديل', style: GoogleFonts.almarai(color: CupertinoColors.activeBlue)),
        ),
      );
    }
    
    if (onDeleteForMe != null) {
      actions.add(
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            onDeleteForMe!();
          },
          child: Text('حذف لدي', style: GoogleFonts.almarai(color: CupertinoColors.systemRed)),
        ),
      );
    }

    return CupertinoActionSheet(
      title: Text('خيارات الرسالة', style: GoogleFonts.almarai(fontWeight: FontWeight.bold)),
      actions: actions,
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: Text('إلغاء', style: GoogleFonts.almarai(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ✅ NEW METHOD to handle the long press and show the sheet
  static void showForMessage({
    required BuildContext context,
    required dynamic message,
    required String myUserId,
    required Function(String, dynamic) onAction,
  }) {
    final bool isIOS = !kIsWeb && Platform.isIOS;
    final bool isMyMessage = message['senderId'].toString() == myUserId.toString();

    if (isIOS) {
      HapticFeedback.lightImpact();
      final List<Map<String, String>> actions = [];
      
      actions.add({'title': 'تحديد', 'action': 'select'});
      actions.add({'title': 'رد', 'action': 'reply'});
      
      if (isMyMessage) {
        actions.add({'title': 'تعديل', 'action': 'edit'});
        actions.add({'title': 'حذف لدى الجميع', 'action': 'delete_for_everyone'});
      }
      
      actions.add({'title': 'حذف لدي', 'action': 'delete_for_me'});

      _showNativeActionSheet('خيارات الرسالة', actions, message, onAction);
    } else {
      showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) {
          return MessageOptionsSheet(
            onSelect: () => onAction('select', message),
            onReply: () => onAction('reply', message),
            onEdit: isMyMessage ? () => onAction('edit', message) : null,
            onDeleteForMe: () => onAction('delete_for_me', message),
          );
        },
      );
    }
  }

  // ✅ New private method for native call
  static Future<void> _showNativeActionSheet(
    String title,
    List<Map<String, String>> actions,
    dynamic message,
    Function(String, dynamic) onAction,
  ) async {
    try {
      final String? selectedAction = await platform.invokeMethod('showActionSheet', {
        'title': title,
        'actions': actions,
      });

      if (selectedAction != null) {
        onAction(selectedAction, message);
      }
    } on PlatformException catch (e) {
      print("Failed to show native action sheet: '${e.message}'.");
    }
  }
}