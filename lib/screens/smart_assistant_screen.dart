import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/smart_assistant_service.dart';
import '../theme/theme.dart';
import '../components/wolf_input_field.dart';

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class SmartAssistantScreen extends StatefulWidget {
  const SmartAssistantScreen({super.key});

  @override
  State<SmartAssistantScreen> createState() => _SmartAssistantScreenState();
}

class _SmartAssistantScreenState extends State<SmartAssistantScreen> {
  final _controller = TextEditingController();
  final _assistantService = SmartAssistantService();
  final List<ChatMessage> _messages = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        text: 'مرحباً بك! أنا المساعد الذكي لنظام زئاب.\nكيف يمكنني مساعدتك اليوم؟',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _controller.clear();
      _loading = true;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;

    if (user != null) {
      try {
        final response = await _assistantService.ask(text, user);
        setState(() {
          _messages.add(ChatMessage(text: response, isUser: false));
        });
      } catch (e) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: 'حدث خطأ أثناء معالجة طلبك.',
              isUser: false,
            ),
          );
        });
      }
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('المساعد الذكي', style: theme.textTheme.headlineMedium),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg, theme);
              },
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, ThemeData theme) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: msg.isUser ? ZaWolfColors.primaryCyan.withValues(alpha: 0.2) : ZaWolfColors.surface01,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: msg.isUser ? const Radius.circular(0) : const Radius.circular(16),
            bottomLeft: !msg.isUser ? const Radius.circular(0) : const Radius.circular(16),
          ),
          border: Border.all(
            color: msg.isUser ? ZaWolfColors.primaryCyan.withValues(alpha: 0.5) : ZaWolfColors.surface02,
          ),
        ),
        child: Text(
          msg.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white,
          ),
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: const BoxDecoration(
        color: ZaWolfColors.surface01,
        border: Border(
          top: BorderSide(color: ZaWolfColors.surface03),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: WolfInputField(
              controller: _controller,
              labelText: '', // Required parameter
              hintText: 'اسأل عن رصيد إجازاتك، مهامك...',
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(
              color: ZaWolfColors.primaryCyan,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.black),
              onPressed: _loading ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
