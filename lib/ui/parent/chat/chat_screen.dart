import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:slatereduc/services/app_localizations.dart';
import 'package:slatereduc/services/api/messaging_service.dart';
import 'package:slatereduc/services/api/local_messaging_service.dart';
import 'package:slatereduc/models/message_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slatereduc/ui/widgets/correspondent_name_widget.dart';

import 'NewChatScreen.dart';
import 'chat_avatar_helpers.dart';

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

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final MessagingService _messagingService = MessagingService();
  final LocalMessagingService _localService = LocalMessagingService();
  StreamSubscription<List<Map<String, dynamic>>>? _localConvSub;
  List<MessageModel> _apiMessages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isSending = false;
  bool _isRecording = false;
  bool _voiceAvailable = true;
  String? _error;
  final TextEditingController _controller = TextEditingController();
  // resolved receiver id derived from messages or shared prefs when widget.receiverUserId is not provided
  String? _resolvedReceiverId;
  String? _recordedFilePath;
  DateFormat? _dateHeaderFormatter;

  final AudioRecorder _recorder = AudioRecorder();
  Timer? _recordTimer;
  Duration _recordDuration = Duration.zero;
  bool _recordCancelled = false;
  double _slideOffset = 0;
  Offset? _longPressStartPosition;
  Duration? _pendingVoiceDuration;

  AnimationController? _micHoldController;
  String? _resolvedTitle;
  String? _resolvedAvatarUrl;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _micHoldController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _dateHeaderFormatter = DateFormat.yMMMMd('fr_FR');
    // ensure we scroll to bottom when messages are loaded initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
    if (widget.conversationId != null) {
      _loadMessages().then((_) async {
        await _markConversationSeenNow();
      });
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
    } else {
      // If no conversation and no explicit receiver provided, prompt user to pick a contact
      if ((widget.receiverUserId == null || widget.receiverUserId!.isEmpty) && (widget.receiverPersonnelId == null || widget.receiverPersonnelId!.isEmpty)) {
        // Delay navigation until after build frame
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            final result = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(builder: (_) => NewChatScreen()));
            if (result != null) {
              final convId = result['conversationId']?.toString();
              final name = result['name']?.toString() ?? widget.name;
              final avatar = result['avatarUrl']?.toString() ?? widget.avatarUrl;
              final currentUserId = result['currentUserId']?.toString();
              final receiverUserId = result['receiverUserId']?.toString();
              final receiverPersonnelId = result['receiverPersonnelId']?.toString();
              // Replace current ChatScreen with a configured one
              if (mounted) {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen(
                  name: name,
                  avatarUrl: avatar,
                  conversationId: convId,
                  currentUserId: currentUserId,
                  receiverUserId: receiverUserId,
                  receiverPersonnelId: receiverPersonnelId,
                )));
              }
            }
          } catch (_) {}
        });
      }
    }
    // Resolve display title and avatar to match NewChatScreen and Chat list
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _resolveDisplayTitle();
      await _resolveAvatarUrl();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _micHoldController?.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
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
      // try to infer the receiver id from messages / prefs so later sendMessage has a receiver
      try {
        await _resolveReceiverFromMessages(messages);
      } catch (_) {}
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

  // Try to resolve the current user id from widget or SharedPreferences (reused by receiver inference)
  Future<String?> _resolveCurrentUserId() async {
    String? senderId = widget.currentUserId;
    if (senderId != null && senderId.isNotEmpty) return senderId;
    try {
      final prefs = await SharedPreferences.getInstance();
      senderId = prefs.getString('current_user_id') ?? prefs.getString('user_id') ?? prefs.getString('id');
      if ((senderId == null || senderId.isEmpty) && prefs.containsKey('user')) {
        final raw = prefs.getString('user');
        if (raw != null && raw.isNotEmpty) {
          try {
            final parsed = json.decode(raw);
            String? tryExtract(dynamic obj) {
              if (obj == null) return null;
              if (obj is String) return null;
              if (obj is Map) {
                final keys = ['id', 'user_id', 'idUser', 'id_user', 'id_eleve', 'idEleve'];
                for (final k in keys) {
                  if (obj.containsKey(k) && obj[k] != null) return obj[k].toString();
                }
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
      if ((senderId == null || senderId.isEmpty)) {
        senderId = prefs.getString('id_user') ?? prefs.getString('idUser');
      }
    } catch (_) {}
    return senderId;
  }

  // Infer the receiver id from a list of messages and available current user id.
  Future<void> _resolveReceiverFromMessages(List<MessageModel> messages) async {
    // keep explicit prop if provided
    if (widget.receiverUserId != null && widget.receiverUserId!.isNotEmpty) {
      setState(() {
        _resolvedReceiverId = widget.receiverUserId;
      });
      return;
    }

    final participants = <String>{};
    for (final m in messages) {
      if (m.senderId.isNotEmpty) participants.add(m.senderId);
      if (m.receiverId.isNotEmpty) participants.add(m.receiverId);
    }
    participants.removeWhere((e) => e.isEmpty);
    if (participants.isEmpty) return;

    final current = await _resolveCurrentUserId();
    String? pick;
    if (current != null && current.isNotEmpty) {
      if (participants.length == 1) {
        // only one id present -> cannot determine the other participant reliably
        pick = null;
      } else {
        for (final p in participants) {
          if (p != current) {
            pick = p;
            break;
          }
        }
      }
    } else {
      // no current id known: choose any participant that appears as a sender/receiver not equal to the first
      if (participants.length >= 2) pick = participants.elementAt(1);
    }

    if (pick != null && pick.isNotEmpty) {
      setState(() {
        _resolvedReceiverId = pick;
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

    // Prefer explicit receiverUserId passed to the screen, otherwise use resolved receiver derived from messages or fallback
    final guessedReceiver = _apiMessages.isNotEmpty ? (_apiMessages.first.senderId == senderId ? _apiMessages.first.receiverId : _apiMessages.first.senderId) : null;
    final primaryReceiverId = widget.receiverUserId ?? _resolvedReceiverId ?? guessedReceiver;
    final fallbackReceiverId = widget.receiverPersonnelId;

    String? receiverId = primaryReceiverId ?? fallbackReceiverId;

    if (receiverId == null || receiverId.isEmpty || receiverId == 'other') {
      // Debug info: log candidates
      print('[ChatScreen] error no receiver id - candidates: widget.receiverUserId=${widget.receiverUserId}, widget.receiverPersonnelId=${widget.receiverPersonnelId}, _resolvedReceiverId=$_resolvedReceiverId, guessedReceiver=$guessedReceiver');
      final detailed = 'Aucun destinataire résolu. Candidates: userId=${widget.receiverUserId ?? 'null'}, personnelId=${widget.receiverPersonnelId ?? 'null'}, resolved=${_resolvedReceiverId ?? 'null'}, guessed=${guessedReceiver ?? 'null'}';
      // Try to prompt the user to select a contact
      try {
        final result = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(builder: (_) => NewChatScreen()));
        if (result == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detailed)));
          return;
        }

        final convId = result['conversationId']?.toString();
        final pickedReceiverUserId = result['receiverUserId']?.toString();
        final pickedReceiverPersonnelId = result['receiverPersonnelId']?.toString();

        if (convId != null && convId.isNotEmpty) {
          // Replace with conversation-backed ChatScreen where send will happen
          if (mounted) {
            final resolvedCur = widget.currentUserId ?? await _resolveCurrentUserId();
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen(
              name: result['name']?.toString() ?? widget.name,
              avatarUrl: result['avatarUrl']?.toString() ?? widget.avatarUrl,
              conversationId: convId,
              currentUserId: resolvedCur,
              receiverUserId: pickedReceiverUserId,
              receiverPersonnelId: pickedReceiverPersonnelId,
            )));
          }
          return;
        }

        // otherwise use picked receiver id (if any) and continue sending
        if ((pickedReceiverUserId != null && pickedReceiverUserId.isNotEmpty) || (pickedReceiverPersonnelId != null && pickedReceiverPersonnelId.isNotEmpty)) {
          receiverId = pickedReceiverUserId ?? pickedReceiverPersonnelId;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detailed)));
          return;
        }
      } catch (e) {
        print('[ChatScreen] error prompting for receiver: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detailed)));
        return;
      }
    }

    // At this point receiverId should be non-null/non-empty; create a non-null local reference
    final String finalReceiverId = receiverId!;

    // Optimistic update
    final optimisticLocalId = DateTime.now().toIso8601String();
    final optimistic = MessageModel(
      id: optimisticLocalId,
      content: content,
      senderId: senderId,
      receiverId: finalReceiverId,
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
          receiverId: finalReceiverId,
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
            // crée de façon idempotente par paire (évite doublons "avec messages" vs "sans message")
            final sender = senderId;
            final receiver = receiverId;
            final participants = <String>[];
            if (sender.isNotEmpty) participants.add(sender);
            if (receiver.isNotEmpty) participants.add(receiver);
            await _localService.createOrReuseLocalConversationForParticipants(
              title: widget.name,
              meta: {'remote_id': widget.conversationId},
              participants: participants,
            );
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
      // New flow: if no conversationId, try to create/find remote conversation (idempotent) then send using client_message_id
      try {
        // resolve parent user id
        String? parentUserId = await _resolveCurrentUserId();
        final participants = <String>[];
        if (parentUserId != null && parentUserId.isNotEmpty) participants.add(parentUserId);
        // prefer receiverUserId (user account) over personnel id
        if (widget.receiverUserId != null && widget.receiverUserId!.isNotEmpty) {
          participants.add(widget.receiverUserId!);
        } else if (widget.receiverPersonnelId != null && widget.receiverPersonnelId!.isNotEmpty) {
          participants.add(widget.receiverPersonnelId!);
        } else {
          // receiverId is expected to be non-null/non-empty here
          participants.add(finalReceiverId);
        }

        // generate idempotency key and client message id
        final idempotencyKey = DateTime.now().toIso8601String() + '-' + senderId; // lightweight unique key; can be replaced by uuid
        final clientMessageId = DateTime.now().millisecondsSinceEpoch.toString() + '-' + senderId;

        // try to find or create remote conversation
        String convId = '';
        try {
          convId = await _messagingService.createOrFindConversation(title: widget.name, participants: participants, idempotencyKey: idempotencyKey);
        } catch (_) {
          convId = '';
        }

        if (convId.isNotEmpty) {
          // persist optimistic message locally under convId with clientMessageId
          final localMsg = {
            'local_id': optimisticLocalId,
            'client_message_id': clientMessageId,
            'content': content,
            'sender_id': senderId,
            'receiver_id': receiverId,
            'id_conversation': convId,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'status': 'pending',
          };
          try {
            // ensure conversation exists locally
            await _localService.mergeAndSaveConversationFromApi({'id': convId, 'title': widget.name, 'messages': [], 'created_at': DateTime.now().toIso8601String(), 'updated_at': DateTime.now().toIso8601String(), 'meta': {'remote_id': convId}});
            await _localService.addLocalMessage(convId, localMsg);
          } catch (_) {}

          // navigate to conversation screen with convId, replacing current screen so future sends use remote conv
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen(name: widget.name, avatarUrl: widget.avatarUrl, conversationId: convId, currentUserId: senderId, receiverUserId: receiverId, receiverPersonnelId: fallbackReceiverId)));

          // send the message on the background (no need to await fully for UI responsiveness)
          try {
            final sent = await _messagingService.sendMessage(content: content, senderId: senderId, receiverId: finalReceiverId, idConversation: convId, clientMessageId: clientMessageId);
            // update local message with server response
            try {
              await _localService.updateLocalMessage(convId, optimisticLocalId, sent.toJson());
            } catch (_) {}
          } catch (e) {
            // on send failure, leave message as pending in local storage and show snackbar
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).translate('error_sending_message') + ': ' + e.toString())));
          }
        } else {
          // fallback: create a local conversation and persist message (existing behavior)
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
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen(name: widget.name, avatarUrl: widget.avatarUrl, conversationId: localConvId, currentUserId: senderId, receiverUserId: receiverId, receiverPersonnelId: fallbackReceiverId)));
        }
      } catch (e) {
        // if something unexpected happens, fallback to previous local-only behavior
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
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen(name: widget.name, avatarUrl: widget.avatarUrl, conversationId: localConvId, currentUserId: senderId, receiverUserId: receiverId, receiverPersonnelId: fallbackReceiverId)));
        } catch (_) {}
      }

      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _startVoiceMessageFlow() async {
    if (_isRecording) {
      await _stopRecordingAndSend();
      return;
    }
    // TODO: integrate real audio recorder; for now toggle state and notify user
    setState(() {
      _isRecording = true;
      _recordedFilePath = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enregistrement vocal en cours...')));
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;
    setState(() {
      _isRecording = false;
    });
    // Placeholder: in a real implementation, assign the actual recorded file path
    if (_recordedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enregistrement vocal indisponible (implémentation manquante).')));
      return;
    }
    if (widget.conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Créez d\'abord une conversation pour envoyer un vocal.')));
      return;
    }
    final senderId = await _resolveCurrentUserId();
    final receiverId = widget.receiverUserId ?? _resolvedReceiverId ?? widget.receiverPersonnelId;
    if (senderId == null || senderId.isEmpty || receiverId == null || receiverId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d\'envoyer: identifiants manquants.')));
      return;
    }
    final file = File(_recordedFilePath!);
    try {
      setState(() {
        _isSending = true;
      });
      final sent = await _messagingService.sendVoiceMessage(
        voiceFile: file,
        senderId: senderId,
        receiverId: receiverId,
        idConversation: widget.conversationId!,
        duration: _recordDuration,
        clientMessageId: DateTime.now().millisecondsSinceEpoch.toString() + '-' + senderId,
        content: '',
      );
      setState(() {
        _apiMessages.add(sent);
      });
      await _localService.addLocalMessage(widget.conversationId!, sent.toJson());
      await _loadMessages();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur envoi vocal: $e')));
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<bool> _ensureRecorderReady() async {
    if (!_voiceAvailable) {
      _notifyVoiceUnavailable();
      return false;
    }
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accès au micro refusé.')));
        return false;
      }
      return true;
    } on MissingPluginException catch (_) {
      setState(() => _voiceAvailable = false);
      _notifyVoiceUnavailable();
      return false;
    } on PlatformException catch (_) {
      _notifyVoiceUnavailable();
      return false;
    }
  }

  Future<String?> _startRecording() async {
    if (!await _ensureRecorderReady()) return null;
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final config = RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100, bitRate: 128000);
    await _recorder.start(config, path: filePath);
    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
      _recordCancelled = false;
      _slideOffset = 0;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _recordDuration += const Duration(seconds: 1);
      });
    });
    return filePath;
  }

  Future<void> _stopRecording({bool cancelled = false}) async {
    _recordTimer?.cancel();
    if (!_isRecording) return;
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _recordCancelled = cancelled;
      _recordedFilePath = cancelled ? null : (path ?? _recordedFilePath);
    });
  }

  Future<void> _handleMicPress() async {
    final path = await _startRecording();
    if (path == null) return;
    setState(() {
      _recordedFilePath = path;
    });
  }

  Future<void> _handleMicRelease({bool? cancelled}) async {
    final shouldCancel = cancelled ?? _recordCancelled;
    await _stopRecording(cancelled: shouldCancel);
    if (shouldCancel || _recordedFilePath == null) {
      setState(() {
        _pendingVoiceDuration = null;
      });
      return;
    }
    setState(() {
      _pendingVoiceDuration = _recordDuration;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vocal prêt. Appuyez sur envoyer.')));
  }

  Future<void> _onMicButtonPressed() async {
    if (_isSending) return;
    if (_isRecording) {
      await _handleMicRelease(cancelled: false);
      return;
    }
    await _handleMicPress();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).translate('voice_recording_started'))),
    );
  }

  Future<void> _sendPreparedVoice() async {
    if (_recordedFilePath == null || _pendingVoiceDuration == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun vocal prêt à envoyer.')));
      return;
    }
    if (widget.conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Créez d\'abord une conversation.')));
      return;
    }
    final senderId = await _resolveCurrentUserId();
    final receiverId = widget.receiverUserId ?? _resolvedReceiverId ?? widget.receiverPersonnelId;
    if (senderId == null || senderId.isEmpty || receiverId == null || receiverId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d\'envoyer le vocal.')));
      return;
    }
    setState(() {
      _isSending = true;
    });
    try {
      final sent = await _messagingService.sendVoiceMessage(
        voiceFile: File(_recordedFilePath!),
        senderId: senderId,
        receiverId: receiverId,
        idConversation: widget.conversationId!,
        duration: _pendingVoiceDuration,
        clientMessageId: DateTime.now().millisecondsSinceEpoch.toString() + '-' + senderId,
        content: '',
      );
      setState(() {
        _apiMessages.add(sent);
        _recordedFilePath = null;
        _pendingVoiceDuration = null;
      });
      await _localService.addLocalMessage(widget.conversationId!, sent.toJson());
      await _loadMessages();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur envoi vocal: $e')));
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Widget _buildInputBar(AppLocalizations loc) {
    final bool micEnabled = _voiceAvailable && !_isSending;
    final bool voiceReady = (_recordedFilePath != null && _pendingVoiceDuration != null);
    final String textValue = _controller.text.trim();
    final bool canSendText = textValue.isNotEmpty && !_isSending;
    final bool canSendVoice = voiceReady && !_isSending;
    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.of(context).viewInsets.bottom == 0 ? 12 : 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.alpha(Colors.grey, 0.07), blurRadius: 4, offset: const Offset(0, 2)),
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
            icon: Icon(
              !_voiceAvailable
                  ? Icons.mic_off
                  : (_isRecording ? Icons.stop_circle : Icons.mic),
              color: !_voiceAvailable ? Colors.grey : Colors.redAccent,
            ),
            onPressed: micEnabled ? _onMicButtonPressed : (_voiceAvailable ? null : _notifyVoiceUnavailableInline),
            tooltip: !_voiceAvailable
                ? 'Enregistrement vocal indisponible'
                : (_isRecording ? loc.translate('stop_recording') : loc.translate('start_voice')),
          ),
          IconButton(
            icon: _isSending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.send, color: (canSendText || canSendVoice) ? const Color(0xFF4B9EFF) : Colors.grey),
            onPressed: !(canSendText || canSendVoice)
                ? null
                : () async {
                    if (canSendText) {
                      await _sendMessage();
                    } else if (canSendVoice) {
                      await _sendPreparedVoice();
                    }
                  },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final titleToShow = (_resolvedTitle?.isNotEmpty == true) ? _resolvedTitle! : widget.name;
    final messagesToShow = widget.conversationId != null ? _apiMessages : null;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: SafeArea(
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.text(context)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(child: Center(child: CorrespondentNameWidget(
                userId: widget.receiverUserId,
                fallbackName: widget.name,
                bold: true,
                fontSize: 18,
              ))),
              const SizedBox(width: 48),
            ],
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
                      final List<_ChatListEntry> entries = _buildEntries(messagesToShow ?? _apiMessages);
                      return ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          if (entry.isHeader) {
                            return Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.background(context),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(entry.label ?? '', style: const TextStyle(color: Colors.grey)),
                              ),
                            );
                          }
                          final msg = entry.message!;
                          final isMe = widget.currentUserId != null && msg.senderId == widget.currentUserId;
                          return _buildTextOrAudioMessage(
                            msgContent: msg.content,
                            isMe: isMe,
                            time: _formatTime(msg.createdAt),
                            voiceUrl: msg.voiceUrl,
                            voiceDuration: msg.voiceDuration,
                            loc: loc,
                            msg: msg,
                          );
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
          child: _buildInputBar(loc),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    return '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildAudioBubble({required bool isMe, required MessageModel msg, required AppLocalizations loc}) {
    final duration = msg.voiceDuration ?? Duration.zero;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    final formattedDuration = '${minutes}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF4B9EFF) : const Color(0xFFE7ECF3),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 0),
          bottomRight: Radius.circular(isMe ? 0 : 18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_arrow,
            color: isMe ? Colors.white : const Color(0xFF4B9EFF),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              loc.translate('voice_message'),
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formattedDuration,
            style: TextStyle(
              color: isMe ? Colors.white70 : Colors.black38,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextOrAudioMessage({required String msgContent, required bool isMe, required String time, String? voiceUrl, Duration? voiceDuration, required AppLocalizations loc, required MessageModel msg}) {
    if (voiceUrl != null && voiceUrl.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAudioBubble(isMe: isMe, msg: msg, loc: loc),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 2),
            child: Text(time, style: TextStyle(color: isMe ? Colors.white70 : Colors.black38, fontSize: 11, fontStyle: FontStyle.italic)),
          ),
        ],
      );
    }
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

  List<_ChatListEntry> _buildEntries(List<MessageModel> messages) {
    final List<_ChatListEntry> entries = [];
    DateTime? currentDay;
    for (final msg in messages..sort((a, b) => a.createdAt.compareTo(b.createdAt))) {
      final day = DateTime(msg.createdAt.year, msg.createdAt.month, msg.createdAt.day);
      if (currentDay == null || currentDay != day) {
        currentDay = day;
        entries.add(_ChatListEntry.header(_formatHeader(day)));
      }
      entries.add(_ChatListEntry.message(msg));
    }
    return entries;
  }

  String _formatHeader(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(day.year, day.month, day.day);
    if (target == today) return AppLocalizations.of(context).translate('today');
    if (target == yesterday) return AppLocalizations.of(context).translate('yesterday');
    return _dateHeaderFormatter?.format(day) ?? DateFormat.yMMMMd('fr_FR').format(day);
  }

  void _notifyVoiceUnavailable() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enregistrement vocal indisponible sur cet appareil.')));
  }

  void _notifyVoiceUnavailableInline() {
    _notifyVoiceUnavailable();
  }

  Future<void> _markConversationSeenNow() async {
    if (widget.conversationId == null || widget.conversationId!.isEmpty) return;
    try {
      final convs = await _localService.getConversations();
      final idx = convs.indexWhere((c) => (c['id']?.toString() ?? '') == widget.conversationId);
      if (idx >= 0) {
        final updated = Map<String, dynamic>.from(convs[idx]);
        final meta = Map<String, dynamic>.from((updated['meta'] as Map?) ?? {});
        meta['seen_at'] = DateTime.now().toIso8601String();
        updated['meta'] = meta;
        convs[idx] = updated;
        await _localService.saveConversations(convs);
      }
    } catch (_) {}
  }

  Future<void> _resolveDisplayTitle() async {
    try {
      // nom par défaut : celui passé à l'écran (souvent le nom choisi dans NewChatScreen)
      String name = widget.name;
      if (widget.conversationId != null && widget.conversationId!.isNotEmpty) {
        final convs = await _localService.getConversations();
        final idx = convs.indexWhere((c) => (c['id']?.toString() ?? '') == widget.conversationId);
        if (idx >= 0) {
          final conv = Map<String, dynamic>.from(convs[idx]);

          // On résout toujours le correspondant (et jamais le titre brut de la conversation)
          final currentUserId = await _resolveCurrentUserId();
          final correspondent = resolveCorrespondentFromConversation(conv, currentUserId: currentUserId);
          if (correspondent.name.trim().isNotEmpty) {
            name = correspondent.name;
          }

          // si on peut, on met à jour _resolvedReceiverId pour l'envoi
          _resolvedReceiverId = widget.receiverUserId ?? correspondent.otherUserId ?? _resolvedReceiverId;
        }
      }
      _resolvedTitle = name;
    } catch (_) {
      _resolvedTitle = widget.name;
    }
  }

  Future<void> _resolveAvatarUrl() async {
    _resolvedAvatarUrl = widget.avatarUrl;
  }

  // on ne force plus d'avatar dans l'AppBar : uniquement le nom du correspondant
  Widget _buildAppBarTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(color: AppColors.text(context), fontWeight: FontWeight.bold, fontSize: 18),
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ChatListEntry {
  final MessageModel? message;
  final String? label;
  final bool isHeader;
  _ChatListEntry._(this.message, this.label, this.isHeader);
  factory _ChatListEntry.header(String label) => _ChatListEntry._(null, label, true);
  factory _ChatListEntry.message(MessageModel message) => _ChatListEntry._(message, null, false);
}
