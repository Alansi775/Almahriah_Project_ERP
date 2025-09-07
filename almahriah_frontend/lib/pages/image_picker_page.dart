// lib/pages/image_picker_page.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:almahriah_frontend/services/auth_service.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ImagePickerPage extends StatefulWidget {
  final User user;
  const ImagePickerPage({super.key, required this.user});

  @override
  State<ImagePickerPage> createState() => _ImagePickerPageState();
}

class _ImagePickerPageState extends State<ImagePickerPage> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPickerOptions();
    });
  }

  void _showPickerOptions() {
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
                      
                      // خيار المعرض
                      ListTile(
                        leading: const Icon(Icons.photo_library, color: Colors.green),
                        title: Text('من المعرض', style: GoogleFonts.almarai()),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                      
                      // خيار الكاميرا (للموبايل فقط)
                      if (!kIsWeb)
                        ListTile(
                          leading: const Icon(Icons.photo_camera, color: Colors.blue),
                          title: Text('من الكاميرا', style: GoogleFonts.almarai()),
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.camera);
                          },
                        ),
                      
                      ListTile(
                        leading: const Icon(Icons.cancel, color: Colors.red),
                        title: Text('إلغاء', style: GoogleFonts.almarai()),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pop(context, false);
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,  // حجم مناسب للأفاتار
        maxHeight: 800,
        imageQuality: 85, // جودة جيدة
      );

      if (!mounted) return;

      if (pickedFile != null) {
        HapticFeedback.lightImpact();
        
        // إظهار رسالة تحميل
        _showUploadingDialog();
        
        bool success = await AuthService.uploadProfilePicture(
          context, 
          widget.user, 
          pickedFile.path
        );
        
        if (mounted) {
          Navigator.pop(context); // إغلاق dialog التحميل
          Navigator.pop(context, success); // العودة للصفحة الرئيسية
        }
      } else {
        // المستخدم لم يختر صورة
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          Navigator.pop(context, false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog('حدث خطأ أثناء اختيار الصورة: $e');
      }
    }
  }

  void _showUploadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(radius: 20),
              const SizedBox(height: 16),
              Text(
                'جاري رفع الصورة...',
                style: GoogleFonts.almarai(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('خطأ', style: GoogleFonts.almarai(fontWeight: FontWeight.bold)),
          content: Text(message, style: GoogleFonts.almarai()),
          actions: [
            TextButton(
              child: Text('موافق', style: GoogleFonts.almarai()),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, false);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: _isLoading 
          ? Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CupertinoActivityIndicator(radius: 20),
                  const SizedBox(height: 16),
                  Text(
                    'جاري رفع الصورة...',
                    style: GoogleFonts.almarai(),
                  ),
                ],
              ),
            )
          : Container(),
      ),
    );
  }
}