import 'package:flutter/material.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:slatereduc/services/app_localizations.dart';
import 'package:slatereduc/services/messaging_service.dart';
import 'package:slatereduc/models/message_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:slatereduc/services/local_messaging_service.dart';
import 'dart:async';

// Widget du chat fidèle au modèle fourni
class ChatScreen extends StatefulWidget {
  final String name;
  final String avatarUrl;
  final String? conversationId; // optional: when provided, messages are loaded from API
  final String? currentUserId; // optional: used to determine which messages are mine
  final String? receiverUserId; // optional: explicit receiver user id for sending messages
  final String? receiverPersonnelId; // optional: personnel id fallback

  const ChatScreen({
    Key? key,
    required this.name,
    required this.avatarUrl,
    this.conversationId,
    this.currentUserId,
    this.receiverUserId,
    this.receiverPersonnelId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final MessagingService _messagingService = MessagingService();
  final LocalMessagingService _localService = LocalMessagingService();
  StreamSubscription<List<Map<String, dynamic>>>? _localConvSub;
  List<MessageModel> _apiMessages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  final TextEditingController _controller = TextEditingController();

  // Messages d'exemple pour la démo (utilisés si conversationId == null)
  List<Map<String, dynamic>> get _sampleMessages => [
        {
          'isMe': true,
          'type': 'text',
          'message':
              "Bonjour Mme Du Corbeau. Je tiens à vous informer que Neville a eu plusieurs difficultés de discipline en classe",
          'time': '10 h 40'
        },
        {
          'isMe': false,
          'type': 'text',
          'message':
              "Bonjour Mme Du Corbeau. Je tiens à vous informer que Neville a eu plusieurs difficultés de discipline en classe",
          'time': '10 h 45'
        },
        {
          'isMe': false,
          'type': 'audio',
          'duration': '02:40',
          'time': '10 h 46'
        },
      ];

  @override
  void initState() {
    super.initState();
    // ensure we scroll to bottom when messages are loaded initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
    if (widget.conversationId != null) {
      _loadMessages();
      // subscribe to local conversation changes to update messages reactively
      try {
        _localConvSub = _localService.conversationsStream.listen((convs) async {
          if (!mounted) return;
          // if this conversation exists locally, load local messages to update UI
          try {
            final local = await _localService.getLocalMessages(widget.conversationId ?? '');
            if (local.isNotEmpty) {
              setState(() {
                _apiMessages = local.map((m) => _mapLocalToMessageModel(m)).toList();
              });
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
            }
          } catch (_) {}
        });
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _localConvSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // Scroll the ListView to bottom safely
  void _scrollToBottom() async {
    try {
      await Future.delayed(const Duration(milliseconds: 80));
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(max, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    } catch (_) {}
  }

  // helper to convert a local message map to MessageModel
  MessageModel _mapLocalToMessageModel(Map<String, dynamic> m) {
    final id = m['id']?.toString() ?? (m['local_id']?.toString() ?? '');
    final content = m['content']?.toString() ?? '';
    final senderId = m['sender_id']?.toString() ?? m['senderId']?.toString() ?? '';
    final receiverId = m['receiver_id']?.toString() ?? m['receiverId']?.toString() ?? '';
    final idConv = m['id_conversation']?.toString() ?? m['idConversation']?.toString() ?? widget.conversationId ?? '';
    final createdAt = DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now();
    final updatedAt = DateTime.tryParse(m['updated_at']?.toString() ?? '') ?? createdAt;
    return MessageModel(id: id, content: content, senderId: senderId, receiverId: receiverId, idConversation: idConv, createdAt: createdAt, updatedAt: updatedAt);
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final messages =
          await _messagingService.getMessagesByConversationId(widget.conversationId!);
      setState(() {
        _apiMessages = messages;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      // also merge into local storage for offline persistence
      try {
        final conv = {
          'id': widget.conversationId,
          'title': widget.name,
          'messages': messages.map((m) => m.toJson()).toList(),
          'created_at': messages.isNotEmpty ? messages.first.createdAt.toIso8601String() : DateTime.now().toIso8601String(),
          'updated_at': messages.isNotEmpty ? messages.last.updatedAt.toIso8601String() : DateTime.now().toIso8601String(),
        };
        await _localService.mergeAndSaveConversationFromApi(conv);
      } catch (_) {}
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      // fallback: try load local messages for this conversation
      try {
        final local = await _localService.getLocalMessages(widget.conversationId ?? '');
        if (local.isNotEmpty) {
          setState(() {
            _apiMessages = local.map((m) => _mapLocalToMessageModel(m)).toList();
          });
        }
      } catch (_) {}
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).translate('error_loading_messages') + ': ' + e.toString())));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    // Determine senderId: prefer passed currentUserId, otherwise try SharedPreferences
    String? senderId = widget.currentUserId;
    if (senderId == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        // Try common keys saved at login: 'current_user_id', 'user_id', or full 'user' JSON
        senderId = prefs.getString('current_user_id') ?? prefs.getString('user_id') ?? prefs.getString('id');
        if ((senderId == null || senderId.isEmpty) && prefs.containsKey('user')) {
          final raw = prefs.getString('user');
          if (raw != null && raw.isNotEmpty) {
            try {
              final parsed = json.decode(raw);
              // parsed can be Map or nested object; search common id fields
              String? tryExtract(dynamic obj) {
                if (obj == null) return null;
                if (obj is String) return null;
                if (obj is Map) {
                  final keys = ['id', 'user_id', 'idUser', 'id_user', 'id_eleve', 'idEleve'];
                  for (final k in keys) {
                    if (obj.containsKey(k) && obj[k] != null) return obj[k].toString();
                  }
                  // check nested 'data' or 'user'
                  if (obj.containsKey('data')) {
                    final r = tryExtract(obj['data']);
                    if (r != null) return r;
                  }
                  if (obj.containsKey('user')) {
                    final r = tryExtract(obj['user']);
                    if (r != null) return r;
                  }
                }
                return null;
              }

              senderId = tryExtract(parsed) ?? senderId;
            } catch (_) {}
          }
        }
        // Additional fallback: check other common keys
        if ((senderId == null || senderId.isEmpty)) {
          senderId = prefs.getString('id_user') ?? prefs.getString('idUser');
        }
        // Debug log to help trace why 'no sender id' appears
        print('[ChatScreen] resolved senderId=$senderId');
      } catch (_) {}
    }
    if (senderId == null || senderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).translate('error_no_sender_id'))));
      return;
    }

    // Prefer explicit receiverUserId passed to the screen (user id), otherwise guess from messages
    final guessedReceiver = _apiMessages.isNotEmpty ? (_apiMessages.first.senderId == senderId ? _apiMessages.first.receiverId : _apiMessages.first.senderId) : null;
    final primaryReceiverId = widget.receiverUserId ?? guessedReceiver;
    final fallbackReceiverId = widget.receiverPersonnelId;

    String? receiverId = primaryReceiverId ?? fallbackReceiverId;

    if (receiverId == null || receiverId.isEmpty || receiverId == 'other') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).translate('error_no_receiver_id'))));
      return;
    }

    // Optimistic update
    final optimisticLocalId = DateTime.now().toIso8601String();
    final optimistic = MessageModel(
      id: optimisticLocalId,
      content: content,
      senderId: senderId,
      receiverId: receiverId,
      idConversation: widget.conversationId ?? '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() {
      _apiMessages.add(optimistic);
      _controller.clear();
      _isSending = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    if (widget.conversationId != null) {
      try {
        final sent = await _messagingService.sendMessage(
          content: content,
          senderId: senderId,
          receiverId: receiverId,
          idConversation: widget.conversationId!,
        );
        // refresh to get server-generated ids/timestamps
        await _loadMessages();
        // if message was sent, reconcile local optimistic message
        try {
          await _localService.updateLocalMessage(widget.conversationId!, optimisticLocalId, sent.toJson());
        } catch (_) {}
      } catch (e) {
        final err = e.toString();
        // si 422 et qu'on a un fallback (personnel id) différent du premier envoi, retenter
        if (err.contains('422') && fallbackReceiverId != null && fallbackReceiverId.isNotEmpty && fallbackReceiverId != primaryReceiverId) {
          try {
            await _messagingService.sendMessage(
              content: content,
              senderId: senderId,
              receiverId: fallbackReceiverId,
              idConversation: widget.conversationId!,
            );
            await _loadMessages();
            setState(() {
              _isSending = false;
            });
            return;
          } catch (e2) {
            // continue to error handling below
          }
        }
        // remove optimistic message from UI (we will add a persisted local message instead)
        setState(() {
          _apiMessages.removeWhere((m) => m.id == optimistic.id);
        });

        // persist locally so the message 'reste'
        try {
          final localMsg = {
            'local_id': optimisticLocalId,
            'content': content,
            'sender_id': senderId,
            'receiver_id': receiverId,
            'id_conversation': widget.conversationId ?? 'local-unknown',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };
          await _localService.addLocalMessage(widget.conversationId ?? 'local-unknown', localMsg);
          // also ensure conversation exists locally
          final convs = await _localService.getConversations();
          final exists = convs.any((c) => c['id'] == widget.conversationId);
          if (!exists) {
            await _localService.createLocalConversation(title: widget.name, meta: {'remote_id': widget.conversationId});
          }
          // reload local messages into UI
          final local = await _localService.getLocalMessages(widget.conversationId ?? 'local-unknown');
          setState(() {
            _apiMessages = local.map((m) => _mapLocalToMessageModel(m)).toList();
          });
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).translate('error_sending_message') + ': ' + e.toString())),
        );
      } finally {
        setState(() {
          _isSending = false;
        });
      }
    } else {
      // if no conversationId, keep optimistic message only and save locally as new local conversation
      try {
        final localConvId = await _localService.createLocalConversation(title: widget.name, meta: {});
        final localMsg = {
          'local_id': optimisticLocalId,
          'content': content,
          'sender_id': senderId,
          'receiver_id': receiverId,
          'id_conversation': localConvId,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        await _localService.addLocalMessage(localConvId, localMsg);
        // navigate to new local conversation
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen(name: widget.name, avatarUrl: widget.avatarUrl, conversationId: localConvId, currentUserId: senderId, receiverUserId: receiverId, receiverPersonnelId: fallbackReceiverId)));
      } catch (_) {}

      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final messagesToShow = widget.conversationId != null
        ? _apiMessages
        : null; // null indicates use sample messages

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(0),
              bottomRight: Radius.circular(0),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.text(context)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      widget.name,
                      style: TextStyle(
                        color: AppColors.text(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 48),

              ],
            ),
          ),
        ),
      ),

      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7F9FB),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(35),
            topRight: Radius.circular(35),
          ),
        ),
        child: Column(
          children: [
            if (_error != null)
              Container(
                width: double.infinity,
                color: Colors.red.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Erreur: ${_error}',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background(context),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      loc.translate('today'),
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (_isLoading)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else
                  Expanded(
                    child: Builder(builder: (context) {
                      // estimated height of input area (tweakable)
                      final double inputBarHeight = 68;
                      final bool keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
                      // when keyboard is open, we don't add system bottom padding to the list inset
                      final double bottomInset = inputBarHeight + 12 + (keyboardOpen ? 0 : MediaQuery.of(context).padding.bottom);
                      return ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset),
                        itemCount: messagesToShow != null ? messagesToShow.length : _sampleMessages.length,
                        itemBuilder: (context, index) {
                          if (messagesToShow != null) {
                            final msg = messagesToShow[index];
                            final isMe = widget.currentUserId != null && msg.senderId == widget.currentUserId;
                            return _buildTextOrAudioMessage(msgContent: msg.content, isMe: isMe, time: _formatTime(msg.createdAt));
                          }

                          final msg = _sampleMessages[index];
                          if (msg['type'] == 'text') {
                            return Align(
                              alignment: msg['isMe'] ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                constraints: const BoxConstraints(maxWidth: 230),
                                decoration: BoxDecoration(
                                  color: msg['isMe'] ? const Color(0xFF4B9EFF) : const Color(0xFFE7ECF3),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(msg['isMe'] ? 18 : 0),
                                    bottomRight: Radius.circular(msg['isMe'] ? 0 : 18),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: msg['isMe'] ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      msg['message'],
                                      style: TextStyle(
                                        color: msg['isMe'] ? Colors.white : Colors.black87,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      msg['time'],
                                      style: TextStyle(
                                        color: msg['isMe'] ? Colors.white70 : Colors.black38,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else if (msg['type'] == 'audio') {
                            return Align(
                              alignment: msg['isMe'] ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7ECF3),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(18),
                                    topRight: Radius.circular(18),
                                    bottomLeft: Radius.circular(0),
                                    bottomRight: Radius.circular(18),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.graphic_eq, color: Colors.black38, size: 28),
                                    const SizedBox(width: 6),
                                    Text(
                                      msg['duration'],
                                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.white,
                                        ),
                                        onPressed: () {},
                                        iconSize: 28,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    }),
                  ),
          ],
        ),
      ),

      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        curve: Curves.easeOut,
        child: SafeArea(
          top: false,
          // only apply bottom SafeArea padding when keyboard is NOT open
          bottom: MediaQuery.of(context).viewInsets.bottom == 0,
          child: Builder(builder: (context) {
            final bool keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
            return Container(
              margin: EdgeInsets.fromLTRB(12, 0, 12, keyboardOpen ? 6 : 12),
               padding: const EdgeInsets.symmetric(horizontal: 16),
               decoration: BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.circular(24),
                 boxShadow: [
                   BoxShadow(
                     color: AppColors.alpha(Colors.grey, 0.07),
                     blurRadius: 4,
                     offset: const Offset(0, 2),
                   ),
                 ],
               ),
               child: Row(
                 children: [
                   const Icon(Icons.add_circle_outline, color: Color(0xFF4B9EFF)),
                   const SizedBox(width: 10),
                   Expanded(
                     child: TextField(
                       controller: _controller,
                       decoration: InputDecoration(
                         hintText: loc.translate('messages') + '...',
                         border: InputBorder.none,
                       ),
                     ),
                   ),
                   IconButton(
                     icon: const Icon(Icons.mic, color: Color(0xFF4B9EFF)),
                     onPressed: () {},
                   ),
                   IconButton(
                     icon: _isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send, color: Color(0xFF4B9EFF)),
                     onPressed: _isSending ? null : _sendMessage,
                   ),
                 ],
               ),
             );
          }),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    return '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildTextOrAudioMessage({required String msgContent, required bool isMe, required String time}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 230),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF4B9EFF) : const Color(0xFFE7ECF3),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msgContent,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              time,
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.black38,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
