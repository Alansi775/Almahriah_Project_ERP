// almahriah_frontend/lib/pages/add_task_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:almahriah_frontend/widgets/glassmorphism_widgets.dart';

//  Define the MethodChannel to communicate with native iOS code
const platform = MethodChannel('com.almahriah.app/dialog');

class AddTaskPage extends StatefulWidget {
  final User user;
  const AddTaskPage({super.key, required this.user});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedEmployeeId;
  String? _selectedEmployeeName;
  String? _selectedPriority = 'عادي';

  bool _isSaving = false;
  String _message = '';

  late Future<List<dynamic>> _employeesFuture;
  List<dynamic> _employees = [];
  List<dynamic> _filteredEmployees = [];
  final _employeeSearchController = TextEditingController();
  final FocusNode _employeeFocusNode = FocusNode();
  bool _showEmployeeList = false; //  متحكم يدوي في إظهار القائمة

  @override
  void initState() {
    super.initState();
    _employeesFuture = _fetchEmployeesByDepartment();
    _employeeSearchController.addListener(_filterEmployees);
    _employeeFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          if (_employeeFocusNode.hasFocus && _employeeSearchController.text.isEmpty && _selectedEmployeeName == null) {
            _showEmployeeList = true;
            _filteredEmployees = _employees;
          }
          //  لا نغلق القائمة تلقائياً عند فقدان التركيز
        });
      }
    });
  }

  @override
  void dispose() {
    _employeeSearchController.dispose();
    _employeeFocusNode.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _filterEmployees() {
    final query = _employeeSearchController.text.toLowerCase();
    if (mounted) {
      setState(() {
        if (_selectedEmployeeName != null) {
          _showEmployeeList = false;
          _filteredEmployees = [];
          return;
        }

        if (query.isEmpty && _employeeFocusNode.hasFocus) {
          _showEmployeeList = true;
          _filteredEmployees = _employees;
        } else if (query.isNotEmpty) {
          _showEmployeeList = true;
          _filteredEmployees = _employees
              .where((employee) =>
                  employee['fullName'].toLowerCase().contains(query))
              .toList();
        } else {
          _showEmployeeList = false;
          _filteredEmployees = [];
        }
      });
    }
  }

  Future<List<dynamic>> _fetchEmployeesByDepartment() async {
    final url = Uri.parse('http://192.168.1.78:5050/api/tasks/employees');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}',
        },
      );

      if (response.statusCode == 200) {
        final employees = json.decode(response.body);
        setState(() {
          _employees = employees;
          _filteredEmployees = employees;
        });
        return employees;
      } else {
        throw Exception('فشل جلب الموظفين: ${json.decode(response.body)['message']}');
      }
    } catch (e) {
      throw Exception('فشل في الاتصال بالخادم: $e');
    }
  }

  Future<void> _addTask() async {
    HapticFeedback.lightImpact();

    if (_formKey.currentState!.validate()) {
      if (_selectedEmployeeId == null) {
        //  Call native alert for validation error
        _showNativeAlert(
          title: 'خطأ في البيانات',
          message: 'الرجاء اختيار الموظف المسؤول.',
        );
        return;
      }

      setState(() {
        _isSaving = true;
      });

      try {
        final url = Uri.parse('http://192.168.1.78:5050/api/tasks');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.user.token}',
          },
          body: jsonEncode({
            'title': _titleController.text,
            'description': _descriptionController.text,
            'assignedToId': _selectedEmployeeId,
            'priority': _selectedPriority,
          }),
        );

        final responseBody = json.decode(response.body);
        if (response.statusCode == 201) {
          //  Call native toast for success
          _showNativeToast(message: 'تم إضافة المهمة بنجاح.');
          // Added a small delay to allow the toast to show
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pop(context, true);
          });
        } else {
          //  Call native alert for API error
          _showNativeAlert(
            title: 'فشل العملية',
            message: responseBody['message'] ?? 'فشل إضافة المهمة.',
          );
        }
      } catch (e) {
        _showNativeAlert(
          title: 'خطأ في الاتصال',
          message: 'حدث خطأ في الاتصال بالخادم: $e',
        );
      } finally {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  //  New method to call native iOS alerts
  void _showNativeAlert({required String title, required String message}) async {
    try {
      await platform.invokeMethod('showAlert', {'title': title, 'message': message});
    } on PlatformException catch (e) {
      print("Failed to invoke native alert: ${e.message}");
    }
  }

  //  New method to call native iOS toasts
  void _showNativeToast({required String message}) async {
    try {
      await platform.invokeMethod('showToast', {'message': message});
    } on PlatformException catch (e) {
      print("Failed to invoke native toast: ${e.message}");
    }
  }

  Widget _buildGlassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 25,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String labelText,
    int? maxLines = 1,
    String? Function(String?)? validator,
    FocusNode? focusNode,
    Widget? prefixIcon,
    String? hintText,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      focusNode: focusNode,
      readOnly: readOnly,
      style: GoogleFonts.almarai(color: Colors.black87),
      cursorColor: Colors.blue.shade800,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.almarai(color: Colors.black54),
        hintText: hintText,
        hintStyle: GoogleFonts.almarai(color: Colors.black38),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.blue.shade800, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red.shade600, width: 2.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red.shade600, width: 2.0),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        prefixIcon: prefixIcon,
      ),
      validator: validator,
    );
  }

  Widget _buildPriorityTag({
    required String text,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.6) : Colors.white.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.8) : Colors.white.withOpacity(0.2),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Text(
          text,
          style: GoogleFonts.almarai(
            color: isSelected ? Colors.white : Colors.blue.shade900,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  //  عنصر محسن جداً للمتصفح
  Widget _buildBetterEmployeeItem({
    required String name, 
    required bool isSelected, 
    required VoidCallback onTap
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.blue.withOpacity(0.3),
          highlightColor: Colors.blue.withOpacity(0.2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: isSelected 
                ? Colors.blue.shade800.withOpacity(0.9) 
                : Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue.shade800 : Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? Colors.white.withOpacity(0.2) 
                      : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    color: isSelected ? Colors.white : Colors.blue.shade700,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.almarai(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        //  إغلاق القائمة عند الضغط خارجها فقط
        setState(() {
          _showEmployeeList = false;
        });
        FocusScope.of(context).unfocus();
        HapticFeedback.lightImpact();
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(
          'إضافة مهمة جديدة',
          style: GoogleFonts.almarai(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: TextSelectionTheme(
              data: TextSelectionThemeData(
                selectionColor: Colors.blue.shade200.withOpacity(0.7),
                selectionHandleColor: Colors.blue.shade800,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'أدخل تفاصيل المهمة',
                            style: GoogleFonts.almarai(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          _buildFormField(
                            controller: _titleController,
                            labelText: 'عنوان المهمة',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'الرجاء إدخال عنوان المهمة';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
                          _buildFormField(
                            controller: _descriptionController,
                            labelText: 'وصف المهمة',
                            maxLines: 4,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'الرجاء إدخال وصف للمهمة';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
                          FutureBuilder<List<dynamic>>(
                            future: _employeesFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                //  Replaced the default CircularProgressIndicator
                                return const Center(child: CupertinoActivityIndicator(radius: 15));
                              } else if (snapshot.hasError) {
                                return Text(
                                  'خطأ: ${snapshot.error}',
                                  style: GoogleFonts.almarai(color: Colors.red),
                                  textAlign: TextAlign.center,
                                );
                              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return Text(
                                  'لا يوجد موظفون متاحون.',
                                  style: GoogleFonts.almarai(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                );
                              } else {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildEmployeeSearchField(),
                                    const SizedBox(height: 10),
                                    if (_showEmployeeList && _filteredEmployees.isNotEmpty && _selectedEmployeeName == null)
                                      _buildGlassCard(
                                        child: Container(
                                          constraints: const BoxConstraints(maxHeight: 250),
                                          child: ListView.builder(
                                            itemCount: _filteredEmployees.length,
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            itemBuilder: (context, index) {
                                              final employee = _filteredEmployees[index];
                                              return _buildBetterEmployeeItem(
                                                name: employee['fullName'],
                                                isSelected: employee['id'].toString() == _selectedEmployeeId,
                                                onTap: () {
                                                  print('تم الضغط على: ${employee['fullName']}');
                                                  setState(() {
                                                    _selectedEmployeeId = employee['id'].toString();
                                                    _selectedEmployeeName = employee['fullName'];
                                                    _employeeSearchController.text = employee['fullName'];
                                                    _showEmployeeList = false; //  إغلاق يدوي
                                                    _filteredEmployees = [];
                                                  });
                                                  _employeeFocusNode.unfocus();
                                                  HapticFeedback.selectionClick();
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الأولوية',
                                style: GoogleFonts.almarai(
                                  color: Colors.black54,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildPriorityTag(
                                    text: 'عادي',
                                    color: Colors.blue.shade800,
                                    isSelected: _selectedPriority == 'عادي',
                                    onTap: () => setState(() => _selectedPriority = 'عادي'),
                                  ),
                                  _buildPriorityTag(
                                    text: 'مهم',
                                    color: Colors.orange.shade800,
                                    isSelected: _selectedPriority == 'مهم',
                                    onTap: () => setState(() => _selectedPriority = 'مهم'),
                                  ),
                                  _buildPriorityTag(
                                    text: 'عاجل',
                                    color: Colors.red.shade800,
                                    isSelected: _selectedPriority == 'عاجل',
                                    onTap: () => setState(() => _selectedPriority = 'عاجل'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    if (_message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _buildGlassMessage(
                          message: _message,
                          isSuccess: false,
                        ),
                      ),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _addTask,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                        shadowColor: Colors.black.withOpacity(0.2),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'إضافة المهمة',
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
    );
  
    
  }

  Widget _buildGlassMessage({required String message, required bool isSuccess}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(15),
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

  Widget _buildEmployeeTag({required String name, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade900.withOpacity(0.7) : Colors.blue.shade50.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade900 : Colors.blue.shade900.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Text(
          name,
          style: GoogleFonts.almarai(
            color: isSelected ? Colors.white : Colors.blue.shade900,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeChip({required String name, required VoidCallback onDeleted}) {
    return Chip(
      label: Text(name, style: GoogleFonts.almarai(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.blue.shade800,
      avatar: const Icon(Icons.person_rounded, color: Colors.white),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.cancel, color: Colors.white, size: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }

  Widget _buildEmployeeSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اختر الموظف',
          style: GoogleFonts.almarai(
            color: Colors.black54,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            _buildFormField(
              controller: _employeeSearchController,
              labelText: '',
              focusNode: _employeeFocusNode,
              hintText: _selectedEmployeeName != null
                  ? _selectedEmployeeName!
                  : (_employeeFocusNode.hasFocus ? '' : 'ابحث عن موظف...'),
              readOnly: _selectedEmployeeName != null,
            ),
            if (_selectedEmployeeName != null)
              Positioned(
                right: 8,
                top: 8,
                bottom: 8,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: _buildEmployeeChip(
                    name: _selectedEmployeeName!,
                    onDeleted: () {
                      setState(() {
                        _selectedEmployeeId = null;
                        _selectedEmployeeName = null;
                        _employeeSearchController.clear();
                        _showEmployeeList = false; //  إغلاق القائمة
                        _employeeFocusNode.requestFocus();
                      });
                    },
                  ),
                ),
              ),
            if (!_employeeFocusNode.hasFocus && _employeeSearchController.text.isEmpty && _selectedEmployeeName == null)
              Positioned(
                right: 20,
                left: 20,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: _buildTypewriterHint(
                      _employees.map((e) => e['fullName'].toString()).toList(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypewriterHint(List<String> names) {
    return TypewriterHint(
      names: names,
      style: GoogleFonts.almarai(color: Colors.black38),
    );
  }
}

class TypewriterHint extends StatefulWidget {
  final List<String> names;
  final TextStyle style;

  const TypewriterHint({Key? key, required this.names, required this.style}) : super(key: key);

  @override
  State<TypewriterHint> createState() => _TypewriterHintState();
}

class _TypewriterHintState extends State<TypewriterHint> {
  late Timer _timer;
  int _nameIndex = 0;
  String _displayedText = '';
  int _charIndex = 0;
  bool _isTyping = true;

  @override
  void initState() {
    super.initState();
    if (widget.names.isNotEmpty) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        final currentName = widget.names[_nameIndex];
        if (_isTyping) {
          if (_charIndex < currentName.length) {
            _displayedText += currentName[_charIndex];
            _charIndex++;
          } else {
            _isTyping = false;
            _timer.cancel();
            _timer = Timer(const Duration(milliseconds: 1500), () {
              if (mounted) _startAnimation();
            });
          }
        } else {
          if (_displayedText.isNotEmpty) {
            _displayedText = _displayedText.substring(0, _displayedText.length - 1);
          } else {
            _isTyping = true;
            _nameIndex = (_nameIndex + 1) % widget.names.length;
            _charIndex = 0;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText,
      style: widget.style,
    );
  }
}