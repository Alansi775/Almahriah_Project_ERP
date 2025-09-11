// lib/services/profile_utils.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/services.dart';
import 'package:almahriah_frontend/services/auth_service.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

const platform = MethodChannel('com.almahriah.app/dialog');

// دالة لمعالجة اختيار ورفع الصورة
Future<void> handleProfileImagePicker(BuildContext context, User user) async {
  final ImagePicker picker = ImagePicker();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'اختر صورة الملف الشخصي',
                      style: GoogleFonts.almarai(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      leading: const Icon(Icons.photo_library, color: Colors.green),
                      title: Text('من المعرض', style: GoogleFonts.almarai()),
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndCropImage(context, user, ImageSource.gallery);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_camera, color: Colors.blue),
                      title: Text('من الكاميرا', style: GoogleFonts.almarai()),
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndCropImage(context, user, ImageSource.camera);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.cancel, color: Colors.red),
                      title: Text('إلغاء', style: GoogleFonts.almarai()),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// دالة خاصة لاختيار واقتصاص الصورة
Future<void> _pickAndCropImage(BuildContext context, User user, ImageSource source) async {
  try {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source);
    
    if (pickedFile != null) {
      HapticFeedback.lightImpact();
      
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1.0, ratioY: 1.0),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'تعديل الصورة',
            toolbarColor: Colors.blue.shade800,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'تعديل الصورة',
            doneButtonTitle: 'حفظ',
            cancelButtonTitle: 'إلغاء',
            minimumAspectRatio: 1.0,
            aspectRatioLockEnabled: true,
          ),
        ],
      );

      if (croppedFile != null) {
        _showUploadingDialog(context);
        
        bool success = await AuthService.uploadProfilePicture(
          context, 
          user, 
          croppedFile.path
        );

        if (context.mounted) {
          Navigator.pop(context);
        }
        
        if (success) {
           _showAlert(context, 'نجاح', 'تم تحديث صورة الملف الشخصي.');
        } else {
           _showAlert(context, 'خطأ', 'فشل رفع الصورة.');
        }
      }
    }
  } catch (e) {
    print('حدث خطأ أثناء اختيار الصورة: $e');
    _showAlert(context, 'خطأ', 'حدث خطأ غير متوقع: $e');
  }
}

// 🆕 دالة لتحديث صورة المستخدم من الخادم
Future<String?> updateProfilePictureFromApi(String userId, String token, {required String role}) async {
  try {
    String endpoint;
    // 🚀 تم تحديث الشرط ليشمل جميع الأدوار
    if (role == 'Admin') {
      endpoint = 'api/admin/users/$userId';
    } else {
      // هذه النقطة تعمل لأي دور غير "Admin"
      endpoint = 'api/employee/profile/me';
    }

    final response = await http.get(
      Uri.parse('http://192.168.1.78:5050/$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final userData = json.decode(response.body);
      final prefs = await SharedPreferences.getInstance();

      final String? profilePictureUrl = userData['profilePictureUrl'];
      final String? fullImageUrl = profilePictureUrl != null
          ? 'http://192.168.1.78:5050$profilePictureUrl'
          : null;

      // 💾 حفظ المسار الكامل في SharedPreferences
      userData['profilePictureUrl'] = fullImageUrl;
      await prefs.setString('user', json.encode(userData));

      return fullImageUrl;
    } else {
      print('Failed to fetch user data: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('Error updating user profile picture: $e');
    return null;
  }
}


// ✅ تم تعديل دالة handleProfileImageDelete
Future<bool> handleProfileImageDelete(BuildContext context, User user) async {
  try {
    final bool? confirm = await platform.invokeMethod(
      'showConfirmationAlert',
      {
        'title': 'تأكيد الحذف',
        'message': 'هل أنت متأكد أنك تريد حذف صورة الملف الشخصي؟',
      },
    );

    if (confirm == true) {
      _showUploadingDialog(context);
      bool success = await AuthService.deleteProfilePicture(context, user);
      if (context.mounted) {
        Navigator.pop(context);
      }
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        final userJson = prefs.getString('user');
        if (userJson != null) {
          final userData = json.decode(userJson);
          userData['profilePictureUrl'] = null;
          await prefs.setString('user', json.encode(userData));
        }
      }
      return success;
    }
    return false;
  } on PlatformException catch (e) {
    print("Failed to invoke method: '${e.message}'.");
    if (context.mounted) {
      _showAlert(context, 'خطأ', 'حدث خطأ أثناء الاتصال بالواجهة الأصلية: ${e.message}');
    }
    return false;
  }
}


// دالة عرض رسالة التحميل
void _showUploadingDialog(BuildContext context) {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(radius: 20),
              const SizedBox(height: 16),
              Text(
                'جاري معالجة الصورة...',
                style: GoogleFonts.almarai(),
              ),
            ],
          ),
        );
      },
    );
  } else {
    // For Android, Web, etc.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF3498DB)),
              const SizedBox(height: 16),
              Text(
                'جاري معالجة الصورة...',
                style: GoogleFonts.almarai(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// دالة عامة لعرض رسائل التنبيه
void _showAlert(BuildContext context, String title, String message) {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    // iOS Native Alert
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(title, style: GoogleFonts.almarai(fontWeight: FontWeight.bold)),
          content: Text(message, style: GoogleFonts.almarai()),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('موافق', style: TextStyle(color: CupertinoColors.activeBlue)),
            ),
          ],
        );
      },
    );
  } else {
    // Android/Web Elegant Alert
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: GoogleFonts.almarai(fontWeight: FontWeight.bold)),
          content: Text(message, style: GoogleFonts.almarai()),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'موافق',
                style: GoogleFonts.almarai(color: const Color(0xFF3498DB), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}