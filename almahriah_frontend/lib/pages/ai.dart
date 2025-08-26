// ✅ Full, correct, and ready-to-use code for ai.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:almahriah_frontend/models/user.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class AiChatPage extends StatefulWidget {
  final User user;

  const AiChatPage({super.key, required this.user});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _showInitialWelcome = true;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    if (_showInitialWelcome) {
      setState(() {
        _showInitialWelcome = false;
      });
    }

    // Add the user's message to the list
    setState(() {
      _messages.add({
        'text': messageText,
        'isUser': true,
      });
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.52:5050/api/ai/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}',
        },
        body: jsonEncode({
          'prompt': messageText,
          'history': _messages.map((m) => {
            'role': m['isUser'] ? 'user' : 'assistant',
            'content': m['text'],
          }).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _messages.add({
            'text': data['message'],
            'isUser': false,
          });
          _isLoading = false;
        });
      } else {
        setState(() {
          _messages.add({
            'text': 'عذراً، حدث خطأ أثناء الاتصال بالمساعد الذكي.',
            'isUser': false,
          });
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'text': 'عذراً، لا يمكن الاتصال بالخادم. الرجاء المحاولة لاحقاً.',
          'isUser': false,
        });
        _isLoading = false;
      });
    } finally {
      _scrollToBottom();
    }
  }

  // The new, correct widget to handle AI responses with streaming and formatting
  Widget _buildAiMessage(String messageText) {
    return _MessageBubble(
      isUser: false,
      child: _StreamingText(text: messageText, scrollController: _scrollController),
    );
  }

  // The new message bubble widget that handles formatting
  Widget _MessageBubble({required bool isUser, required Widget child}) {
    final color = isUser ? Colors.blue.shade100 : Colors.grey.shade100;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(0),
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 120,
              width: 120,
            ),
            const SizedBox(height: 20),
            Text(
              'مرحباً بك، ${widget.user.fullName}!',
              textAlign: TextAlign.center,
              style: GoogleFonts.marhey( 
                fontSize: 60,
                fontWeight: FontWeight.w400,
                color: Colors.black87,
                shadows: [
                  Shadow(
                    offset: const Offset(2.0, 2.0),
                    blurRadius: 3.0,
                    color: Colors.black.withOpacity(0.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'أنا كهلان، مساعدك الذكي المخصص لموظفي قناة المهرية الفضائية.\nكيف يمكنني مساعدتك اليوم؟',
              textAlign: TextAlign.center,
              style: GoogleFonts.almarai(
                fontSize: 18,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        children: [
          _buildTypingDot(delay: 0),
          _buildTypingDot(delay: 200),
          _buildTypingDot(delay: 400),
        ],
      ),
    );
  }

  Widget _buildTypingDot({required int delay}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade800,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = kIsWeb ? false : Platform.isIOS;
    final isDesktop = kIsWeb || (!isIOS && (Platform.isMacOS || Platform.isWindows || Platform.isLinux));

    return SafeArea( 
      child: Scaffold(
        resizeToAvoidBottomInset: false, 
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            'مساعدك الذكي كهلان',
            style: GoogleFonts.almarai(fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ),
        ),
        body: Center(
          child: SizedBox(
            width: isDesktop ? 800 : double.infinity,
            child: Column(
              children: [
                if (_showInitialWelcome)
                  _buildWelcomeScreen()
                else
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        if (message['isUser']) {
                          return _MessageBubble(
                            isUser: true,
                            child: SelectableText(
                              message['text'],
                              style: GoogleFonts.almarai(
                                color: Colors.blue.shade900,
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          );
                        } else {
                          return _buildAiMessage(message['text']);
                        }
                      },
                    ),
                  ),
                if (_isLoading)
                  _buildTypingIndicator(),
                
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          cursorColor: Colors.blue.shade800,
                          decoration: InputDecoration(
                            hintText: 'اكتب رسالتك هنا...',
                            hintStyle: GoogleFonts.almarai(color: Colors.grey.shade600),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          style: GoogleFonts.almarai(color: Colors.black87),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.shade100,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.send_rounded, color: Colors.blue.shade800),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// New Stateful Widget to handle the streaming effect
class _StreamingText extends StatefulWidget {
  final String text;
  final ScrollController scrollController;

  const _StreamingText({required this.text, required this.scrollController});

  @override
  State<_StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<_StreamingText> {
  late final List<String> _lines;
  final List<String> _displayedLines = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    _lines = widget.text.split('\n');
    _startStreaming();
  }

  void _startStreaming() async {
    for (int i = 0; i < _lines.length; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      
      _displayedLines.add(_lines[i]);
      _listKey.currentState?.insertItem(_displayedLines.length - 1);
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.scrollController.hasClients) {
          widget.scrollController.animateTo(
            widget.scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      initialItemCount: _displayedLines.length,
      itemBuilder: (context, index, animation) {
        final line = _displayedLines[index].trim();
        
        final formattedLine = line.contains('---separator---')
            ? const Divider(height: 20, color: Colors.grey)
            : _buildTextLine(line);

        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            child: formattedLine,
          ),
        );
      },
    );
  }

  // ✅ New helper function to process and format text with bold
  List<TextSpan> _formatTextWithBold(String text) {
    final boldRegex = RegExp(r'\*\*(.*?)\*\*');
    final matches = boldRegex.allMatches(text);
    
    final children = <TextSpan>[];
    int currentPosition = 0;

    for (var match in matches) {
      if (match.start > currentPosition) {
        children.add(TextSpan(text: text.substring(currentPosition, match.start)));
      }
      
      children.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      
      currentPosition = match.end;
    }

    if (currentPosition < text.length) {
      children.add(TextSpan(text: text.substring(currentPosition)));
    }

    return children;
  }
  
  // ✅ The corrected _buildTextLine function
  Widget _buildTextLine(String line) {
    final parts = line.split(': ');
    if (parts.length > 1) {
      final key = parts[0];
      final value = parts.sublist(1).join(': ');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: RichText(
          text: TextSpan(
            style: GoogleFonts.almarai(fontSize: 16, color: Colors.black87, height: 1.5),
            children: [
              TextSpan(
                text: '$key: ',
                style: GoogleFonts.almarai(fontWeight: FontWeight.bold),
              ),
              ..._formatTextWithBold(value),
            ],
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.almarai(fontSize: 16, color: Colors.black87, height: 1.5),
          children: _formatTextWithBold(line),
        ),
      ),
    );
  }
}