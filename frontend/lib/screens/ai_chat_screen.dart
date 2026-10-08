import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../core/services/chat_service.dart';
import '../core/services/auth_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Map<String, dynamic>? _currentUser;
  String _selectedLang = 'EN'; // EN | SI | TA

  // ── Quick suggestions per language ──────────────────────────────────────────
  static const Map<String, List<String>> _suggestions = {
    'EN': [
      'How to book a doctor appointment?',
      'What OPD rooms are available?',
      'Show me available doctors',
      'Check OPD live queue status',
      'How to cancel my appointment?',
      'My medical records',
      'Pill tracker reminders',
      'Emergency helpline numbers',
      'Hospital working hours',
      'How to update my profile?',
    ],
    'SI': [
      'Doctor appointment book කරන්නේ කෙසේද?',
      'Available OPD rooms මොනවාද?',
      'Available doctors ලැයිස්තුව',
      'OPD queue status බලන්න',
      'Appointment cancel කරන්නේ කෙසේද?',
      'Medical records බලන්න',
      'Pill reminder set කරන්නේ කෙසේද?',
      'Emergency helpline numbers',
      'Hospital working hours',
      'Profile update කරන්නේ කෙසේද?',
    ],
    'TA': [
      'மருத்துவர் சந்திப்பு பதிவு செய்வது எப்படி?',
      'கிடைக்கக்கூடிய OPD அறைகள் என்ன?',
      'கிடைக்கக்கூடிய மருத்துவர்கள்',
      'OPD வரிசை நிலை பார்க்க',
      'சந்திப்பை ரத்து செய்வது எப்படி?',
      'மருத்துவ பதிவுகள் பார்க்க',
      'மாத்திரை நினைவூட்டல் அமைக்க',
      'அவசர தொலைபேசி எண்கள்',
      'மருத்துவமனை நேரம்',
      'சுயவிவரம் புதுப்பிக்க',
    ],
  };

  List<String> get _quickSuggestions => _suggestions[_selectedLang] ?? _suggestions['EN']!;

  @override
  void initState() {
    super.initState();
    _loadUserAndHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndHistory() async {
    setState(() => _isLoading = true);
    final user = AuthService.currentUser;
    final history = await _chatService.getHistory();

    setState(() {
      _currentUser = user;
      _messages = history;
      _isLoading = false;
    });

    _scrollToBottom();
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

  Future<void> _sendMessage([String? customText]) async {
    final text = (customText ?? _messageController.text).trim();
    if (text.isEmpty || _isSending) return;

    if (customText == null) {
      _messageController.clear();
    }

    final userMsg = ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: 'user',
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isSending = true;
    });
    _scrollToBottom();

    final botReply = await _chatService.sendMessage(text);

    if (mounted) {
      setState(() {
        if (botReply != null) {
          _messages.add(botReply);
        }
        _isSending = false;
      });
      await _chatService.saveLocalHistory(_messages);
      _scrollToBottom();
    }
  }

  Future<void> _startNewChat() async {
    if (_messages.isEmpty && _messageController.text.isEmpty) return;

    await _chatService.clearHistory();
    setState(() {
      _messages.clear();
      _messageController.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.add_comment_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('New chat session started'),
            ],
          ),
          backgroundColor: Color(0xFF1E3A8A),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearChatHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Clear Chat History'),
          ],
        ),
        content: const Text(
            'Are you sure you want to clear your conversation history? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _chatService.clearHistory();
      setState(() {
        _messages.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat history cleared.'),
            backgroundColor: Color(0xFF1E3A8A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String get _userName {
    final name = _currentUser?['full_name'] as String? ?? 'Patient';
    return name.split(' ').first;
  }

  // ── Language selector UI ────────────────────────────────────────────────────

  Widget _buildTopLanguageBar() {
    const langs = [
      {'code': 'EN', 'label': 'English'},
      {'code': 'SI', 'label': 'සිංහල'},
      {'code': 'TA', 'label': 'தமிழ்'},
    ];

    return Container(
      color: const Color(0xFF1E3A8A),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: langs.map((l) {
            final code = l['code']!;
            final label = l['label']!;
            final selected = _selectedLang == code;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedLang = code),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (selected)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.check_circle_rounded,
                              size: 13, color: Color(0xFF1E3A8A)),
                        ),
                      Text(
                        label,
                        style: TextStyle(
                          color: selected ? const Color(0xFF1E3A8A) : Colors.white,
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          },
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Image.asset(
                  'assets/images/chat_bot_icon.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.smart_toy_rounded,
                      color: Color(0xFF1E3A8A),
                      size: 24),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'MediQ AI Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Online • $_userName',
                          style:
                              const TextStyle(color: Colors.white70, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: Colors.white, size: 22),
            tooltip: 'New Chat',
            onPressed: _startNewChat,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.white, size: 22),
            tooltip: 'Clear Chat',
            onPressed: _messages.isEmpty ? null : _clearChatHistory,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildTopLanguageBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
                : _messages.isEmpty
                    ? _buildWelcomeState()
                    : _buildChatList(),
          ),
          if (_isSending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF1E3A8A)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'MediQ AI is typing...',
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          _buildQuickSuggestionsBar(),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── Welcome screen ──────────────────────────────────────────────────────────

  Widget _buildWelcomeState() {
    final greetings = {
      'EN': 'Hello $_userName! 👋',
      'SI': 'ආයුබෝවන් $_userName! 👋',
      'TA': 'வணக்கம் $_userName! 👋',
    };
    final subtitles = {
      'EN': 'I am your personal MediQ Health Assistant.\nHow can I help you today?',
      'SI': 'මම ඔබේ MediQ AI Health Assistant.\nඅද ඔබට කෙසේ උදව් කළ හැකිද?',
      'TA': 'நான் உங்கள் MediQ AI உதவியாளர்.\nஇன்று எப்படி உதவலாம்?',
    };
    final suggestionHeaders = {
      'EN': 'Suggested Questions:',
      'SI': 'යෝජිත ප්‍රශ්න:',
      'TA': 'பரிந்துரைக்கப்பட்ட கேள்விகள்:',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          // Bot avatar
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(45),
              child: Image.asset(
                'assets/images/chat_bot_icon.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.smart_toy_rounded,
                    color: Color(0xFF1E3A8A),
                    size: 50),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            greetings[_selectedLang] ?? greetings['EN']!,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitles[_selectedLang] ?? subtitles['EN']!,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 16),
          // Capability chips
          _buildCapabilityChips(),
          const SizedBox(height: 20),
          // Suggested questions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: Color(0xFF1E3A8A), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      suggestionHeaders[_selectedLang] ??
                          suggestionHeaders['EN']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickSuggestions.take(6).map((q) {
                    return ActionChip(
                      backgroundColor: Colors.white,
                      surfaceTintColor: Colors.white,
                      elevation: 1,
                      side: BorderSide(color: Colors.blue.shade200),
                      label: Text(
                        q,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1E3A8A),
                            fontWeight: FontWeight.w500),
                      ),
                      onPressed: () => _sendMessage(q),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilityChips() {
    final caps = {
      'EN': ['📅 Appointments', '🏥 OPD Queue', '🚪 Rooms & Doctors', '💊 Medications', '📁 Records', '🚨 Emergency'],
      'SI': ['📅 Appointments', '🏥 OPD Queue', '🚪 Rooms & Doctors', '💊 Medicines', '📁 Records', '🚨 Emergency'],
      'TA': ['📅 சந்திப்பு', '🏥 OPD வரிசை', '🚪 அறைகள் & மருத்துவர்கள்', '💊 மருந்துகள்', '📁 பதிவுகள்', '🚨 அவசரம்'],
    };

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: (caps[_selectedLang] ?? caps['EN']!).map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1E3A8A).withValues(alpha: 0.2)),
          ),
          child: Text(
            c,
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w600),
          ),
        );
      }).toList(),
    );
  }

  // ── Chat list ───────────────────────────────────────────────────────────────

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg.sender == 'user';
        return _buildMessageBubble(msg, isUser);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/chat_bot_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.smart_toy_rounded,
                      color: Color(0xFF1E3A8A),
                      size: 20),
                ),
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF1E3A8A) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isUser
                  ? Text(
                      msg.text.trim().isEmpty ? '...' : msg.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    )
                  : MarkdownBody(
                      data: msg.text.trim().isEmpty ? '...' : msg.text,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                          height: 1.5,
                        ),
                        strong: const TextStyle(
                          color: Color(0xFF1E3A8A),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        em: const TextStyle(
                          color: Color(0xFF475569),
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                        ),
                        listBullet: const TextStyle(
                          color: Color(0xFF1E3A8A),
                          fontSize: 14,
                        ),
                        tableHead: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                        tableBody: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                        ),
                        tableBorder: TableBorder.all(
                          color: Color(0xFFCBD5E1),
                          width: 1,
                        ),
                        tableColumnWidth: const FlexColumnWidth(),
                        tableCellsPadding: const EdgeInsets.all(6),
                        blockquote: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13,
                        ),
                        code: const TextStyle(
                          backgroundColor: Color(0xFFF1F5F9),
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      shrinkWrap: true,
                      softLineBreak: true,
                    ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF3B82F6),
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Quick suggestions horizontal bar ────────────────────────────────────────

  Widget _buildQuickSuggestionsBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _quickSuggestions.length,
        itemBuilder: (context, index) {
          final sug = _quickSuggestions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              backgroundColor: const Color(0xFFF1F5F9),
              side: BorderSide(color: Colors.grey.shade300),
              label: Text(
                sug,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade800),
              ),
              onPressed: () => _sendMessage(sug),
            ),
          );
        },
      ),
    );
  }

  // ── Input bar ───────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    final hints = {
      'EN': 'Ask MediQ AI anything...',
      'SI': 'MediQ AI ට ඕනෑම දෙයක් අසන්න...',
      'TA': 'MediQ AI ஐ எதையும் கேளுங்கள்...',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: hints[_selectedLang] ?? hints['EN']!,
                  hintStyle:
                      TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: const Color(0xFF1E3A8A),
              shape: const CircleBorder(),
              elevation: 2,
              child: IconButton(
                icon: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
