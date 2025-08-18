import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'dart:async';

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

  @override
  void initState() {
    super.initState();
    _employeesFuture = _fetchEmployeesByDepartment();
    _employeeSearchController.addListener(_filterEmployees);
    _employeeFocusNode.addListener(() {
      setState(() {
        if (_employeeFocusNode.hasFocus && _employeeSearchController.text.isEmpty && _selectedEmployeeName == null) {
          _filteredEmployees = _employees;
        } else if (!_employeeFocusNode.hasFocus) {
          _filteredEmployees = [];
        }
      });
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
    setState(() {
      if (_selectedEmployeeName != null) {
        _filteredEmployees = [];
        return;
      }
      
      if (query.isEmpty && _employeeFocusNode.hasFocus) {
        _filteredEmployees = _employees;
      } else if (query.isNotEmpty) {
        _filteredEmployees = _employees
            .where((employee) =>
                employee['fullName'].toLowerCase().contains(query))
            .toList();
      } else {
        _filteredEmployees = [];
      }
    });
  }

  Future<List<dynamic>> _fetchEmployeesByDepartment() async {
    final url = Uri.parse('http://192.168.1.107:5050/api/tasks/employees');
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
    if (_formKey.currentState!.validate()) {
      if (_selectedEmployeeId == null) {
        setState(() {
          _message = 'الرجاء اختيار الموظف المسؤول.';
        });
        return;
      }

      setState(() {
        _isSaving = true;
        _message = '';
      });
      _formKey.currentState!.save();

      try {
        final url = Uri.parse('http://192.168.1.107:5050/api/tasks');
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
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('تم إضافة المهمة بنجاح.',
                    style: GoogleFonts.almarai())),
          );
          Navigator.pop(context, true);
        } else {
          setState(() {
            _message = responseBody['message'] ?? 'فشل إضافة المهمة.';
          });
        }
      } catch (e) {
        setState(() {
          _message = 'حدث خطأ في الاتصال بالخادم: $e';
        });
      } finally {
        setState(() {
          _isSaving = false;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                              return const Center(child: CircularProgressIndicator());
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
                                  if (_employeeFocusNode.hasFocus && _filteredEmployees.isNotEmpty && _selectedEmployeeName == null)
                                    _buildGlassCard(
                                      child: Container(
                                        constraints: const BoxConstraints(maxHeight: 200),
                                        child: SingleChildScrollView(
                                          child: Wrap(
                                            spacing: 8.0,
                                            runSpacing: 8.0,
                                            children: _filteredEmployees.map((employee) {
                                              return _buildEmployeeTag(
                                                name: employee['fullName'],
                                                isSelected: employee['id'].toString() == _selectedEmployeeId,
                                                onTap: () {
                                                  setState(() {
                                                    _selectedEmployeeId = employee['id'].toString();
                                                    _selectedEmployeeName = employee['fullName'];
                                                    _employeeSearchController.text = employee['fullName'];
                                                    _filteredEmployees = [];
                                                    _employeeFocusNode.unfocus();
                                                  });
                                                },
                                              );
                                            }).toList(),
                                          ),
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

// Separate widget for the typewriter effect
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