import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/widgets/glassmorphism_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';

const dialogChannel = MethodChannel('com.almahriah.app/dialog');

class AddUserPage extends StatefulWidget {
  final User user;
  const AddUserPage({super.key, required this.user});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  double _scrollOffset = 0.0;

  String? _selectedDepartment;
  String? _selectedRole;
  bool _isLoading = false;

  final List<String> departments = [
    'برامج',
    'أخبار',
    'سوشال ميديا',
    'موارد بشرية',
    'استقبال',
  ];

  final List<String> roles = [
    'Admin',
    'Manager',
    'News',
    'HR',
    'Employee',
  ];

  void _showPlatformMessage(String message, {required bool isSuccess}) async {
    final String title = isSuccess ? 'تمت العملية بنجاح' : 'خطأ!';
    final String type = isSuccess ? 'toast' : 'alert';
    
    if (Platform.isIOS) {
      try {
        await dialogChannel.invokeMethod('showNativeDialog', {
          'title': title,
          'message': message,
          'type': type,
        });
      } on PlatformException catch (e) {
        print("Failed to show native dialog: '${e.message}'.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: _buildGlassMessage(message: message, isSuccess: isSuccess),
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _addUser() async {
    setState(() {
      _isLoading = true;
    });
    HapticFeedback.lightImpact();

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    final username = _usernameController.text.contains('@')
        ? _usernameController.text
        : '${_usernameController.text}@almahriah.com';

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.78:5050/api/admin/users'), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}',
        },
        body: json.encode({
          'username': username,
          'password': _passwordController.text,
          'fullName': _fullNameController.text,
          'department': _selectedDepartment,
          'role': _selectedRole,
        }),
      );

      final responseBody = json.decode(response.body);
      bool isSuccess = response.statusCode == 201;

      isSuccess
          ? HapticFeedback.heavyImpact()
          : HapticFeedback.heavyImpact();

      _showPlatformMessage(responseBody['message'] ?? (isSuccess ? 'تم إضافة المستخدم بنجاح!' : 'فشل إضافة المستخدم'), isSuccess: isSuccess);
      
      if (isSuccess) {
        _fullNameController.clear();
        _usernameController.clear();
        _passwordController.clear();
        setState(() {
          _selectedDepartment = null;
          _selectedRole = null;
        });
        _formKey.currentState?.reset();
      }
    } catch (e) {
      _showPlatformMessage('حدث خطأ في الاتصال بالخادم', isSuccess: false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildGlassMessage({required String message, required bool isSuccess}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: isSuccess
                ? Colors.green.shade50.withOpacity(0.5)
                : Colors.red.shade50.withOpacity(0.5),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSuccess
                  ? Colors.green.shade400.withOpacity(0.4)
                  : Colors.red.shade400.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.almarai(
              color: isSuccess ? Colors.green.shade900 : Colors.red.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCleanTextField({
    required TextEditingController controller,
    required String labelText,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      style: GoogleFonts.poppins(color: Colors.black87),
      cursorColor: Colors.blue.shade800,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.poppins(color: Colors.black54),
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      //  Removed `const` to fix the compiler error
      return CupertinoActivityIndicator(radius: 12.0);
    } else {
      return const SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
  }

  Widget _buildSimpleTag({required String text, bool isSelected = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE3F2FD)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: Colors.blue.shade800, width: 1.5)
              : null,
        ),
        child: Text(
          text,
          style: GoogleFonts.almarai(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue.shade900 : Colors.black87,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      //  Replaced `Scaffold` body with `CustomScrollView` for the scrolling effect
      body: NotificationListener<ScrollUpdateNotification>(
        onNotification: (ScrollUpdateNotification notification) {
          setState(() {
            _scrollOffset = notification.metrics.pixels;
          });
          return false;
        },
        child: CustomScrollView(
          slivers: <Widget>[
            //  `SliverAppBar` with glassmorphism effect
            SliverAppBar(
              expandedHeight: 0,
              floating: true,
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              title: Text(
                'إضافة مستخدم جديد',
                style: GoogleFonts.almarai(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 22),
              ),
              centerTitle: true,
              flexibleSpace: FlexibleSpaceBar(
                background: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: _scrollOffset > 0 ? 10 : 0,
                      sigmaY: _scrollOffset > 0 ? 10 : 0,
                    ),
                    child: Container(
                      color: _scrollOffset > 0 ? Colors.white.withOpacity(0.8) : Colors.transparent,
                    ),
                  ),
                ),
              ),
              leading: Builder(
                builder: (BuildContext innerContext) {
                  return IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
                    onPressed: () => Navigator.of(innerContext).pop(),
                  );
                },
              ),
            ),
            //  `SliverToBoxAdapter` to wrap the scrollable content
            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Theme(
                        data: ThemeData(
                          textSelectionTheme: TextSelectionThemeData(
                            cursorColor: Colors.blue.shade800,
                            selectionColor: Colors.blue.shade300,
                            selectionHandleColor: Colors.blue.shade800,
                          ),
                          primaryColor: Colors.blue.shade800,
                          primarySwatch: Colors.blue,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'تعبئة بيانات المستخدم',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.almarai(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'سيتم استخدام هذه البيانات لإضافة حساب جديد.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.almarai(
                                  fontSize: 16,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 30),
                              _buildCleanTextField(
                                controller: _fullNameController,
                                labelText: 'الاسم الكامل',
                              ),
                              const SizedBox(height: 15),
                              _buildCleanTextField(
                                controller: _usernameController,
                                labelText: 'اسم المستخدم (بدون @almahriah.com)',
                              ),
                              const SizedBox(height: 15),
                              _buildCleanTextField(
                                controller: _passwordController,
                                labelText: 'كلمة المرور',
                                isPassword: true,
                              ),
                              const SizedBox(height: 25),
                              Text(
                                'القسم',
                                style: GoogleFonts.almarai(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: departments.map((department) {
                                  return _buildSimpleTag(
                                    text: department,
                                    isSelected: _selectedDepartment == department,
                                    onTap: () {
                                      setState(() {
                                        _selectedDepartment = department;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 25),
                              Text(
                                'الدور',
                                style: GoogleFonts.almarai(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: roles.map((role) {
                                  return _buildSimpleTag(
                                    text: role,
                                    isSelected: _selectedRole == role,
                                    onTap: () {
                                      setState(() {
                                        _selectedRole = role;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 30),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _addUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade800,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 5,
                                  shadowColor: Colors.black.withOpacity(0.2),
                                ),
                                child: _isLoading
                                    ? _buildLoadingIndicator()
                                    : Text(
                                        'إضافة المستخدم',
                                        style: GoogleFonts.almarai(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}