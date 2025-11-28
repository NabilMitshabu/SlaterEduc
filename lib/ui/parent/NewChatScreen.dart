import 'package:flutter/material.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:slatereduc/services/school_service.dart';
import 'package:slatereduc/services/messaging_service.dart';
import 'package:slatereduc/services/local_messaging_service.dart';
import 'chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

class ContactModel {
  final String name;
  final String avatarUrl;
  final String? classe;
  final String? personnelId;
  final String? personnelUserId;
  ContactModel({required this.name, required this.avatarUrl, this.classe, this.personnelId, this.personnelUserId});
}

class NewChatScreen extends StatefulWidget {
  final String? currentStudentId; // optional: id of the student to find classmates' teachers
  const NewChatScreen({Key? key, this.currentStudentId}) : super(key: key);

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final SchoolService _schoolService = SchoolService();
  final MessagingService _messagingService = MessagingService();
  final LocalMessagingService _local_service = LocalMessagingService();
  StreamSubscription<List<Map<String, dynamic>>>? _localConvSub;
  bool _isLoading = true;
  String? _error;
  List<ContactModel> _contacts = [];

  // fallback static contacts
  final List<ContactModel> _fallback = [
    ContactModel(name: "Mr Doeol Mwanakahambo", avatarUrl: "https://randomuser.me/api/portraits/men/31.jpg", classe: 'Classe A'),
    ContactModel(name: "Madame Sofia", avatarUrl: "https://randomuser.me/api/portraits/women/44.jpg", classe: 'Classe B'),
    ContactModel(name: "Jean Pierre", avatarUrl: "https://randomuser.me/api/portraits/men/32.jpg", classe: 'Classe A'),
    ContactModel(name: "Marie Claire", avatarUrl: "https://randomuser.me/api/portraits/women/45.jpg", classe: 'Classe C'),
  ];

  @override
  void initState() {
    super.initState();
    _loadContacts();
    try {
      _localConvSub = _local_service.conversationsStream.listen((_) async {
        if (!mounted) return;
        // refresh contacts when local conversations change (so UI behaves reactively)
        await _loadContacts();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _localConvSub?.cancel();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _contacts = [];
    });

    try {
      final inscriptions = await _schoolService.fetchInscriptions();

      // try fetch coursProfs, but catch failure and fallback
      List<dynamic> coursProfs = [];
      String? coursProfsError;
      try {
        coursProfs = await _schoolService.fetchCoursProfs();
      } catch (e) {
        coursProfsError = e.toString();
      }

      // fetch personnels, users and roles to resolve real names and roles
      final personnels = await _schoolService.fetchPersonnels();
      final users = await _schoolService.fetchUsers();
      final roles = await _schoolService.fetchRoles();

      // build quick lookup maps
      final Map<String, dynamic> personnelsById = {for (var p in personnels) (p['id'] ?? ''): p};
      final Map<String, dynamic> usersById = {for (var u in users) (u['id'] ?? ''): u};
      final Map<String, dynamic> rolesById = {for (var r in roles) (r['id'] ?? ''): r};

      // fetch classes to resolve id -> label when possible
      List<dynamic> classesList = [];
      try {
        classesList = await _schoolService.fetchClasses();
      } catch (_) {}
      final Map<String, String> classesById = {for (var c in classesList) ((c['id'] ?? c['id_classe'] ?? c['idClasse'])?.toString() ?? ''): (c['name'] ?? c['title'] ?? c['label'] ?? c['classe'] ?? c['nom'] ?? '').toString()};

      // find the class id of the current student
      String? studentClasseId;
      if (widget.currentStudentId != null) {
        for (final ins in inscriptions) {
          try {
            if ((ins['id_eleve'] ?? ins['id']) == widget.currentStudentId) {
              studentClasseId = ins['id_classe']?.toString();
              break;
            }
          } catch (_) {}
        }
      }

      final List<ContactModel> results = [];

      if (coursProfs.isNotEmpty) {
        // original flow: use coursProfs to link personnels to classes
        for (final cp in coursProfs) {
          try {
            final idClasse = cp['idClasse'] ?? cp['id_classe'] ?? cp['idClasse'];
            final idPersonnel = (cp['idPersonnel'] ?? cp['id_personnel'] ?? cp['idPersonnel'])?.toString();
            if (idPersonnel == null) continue;
            if (studentClasseId != null && idClasse?.toString() != studentClasseId) continue;

            final personnel = personnelsById[idPersonnel];
            if (personnel == null) continue;

            // resolve user and role to determine if personnel is a professor
            final idUser = (personnel['idUser'] ?? personnel['id_user'] ?? personnel['iduser'])?.toString();
            final user = idUser != null ? usersById[idUser] : null;
            final role = user != null ? rolesById[(user['role_id'] ?? user['roleId'] ?? '')] : null;

            bool isProf = false;
            // check role title
            final roleTitle = role != null ? (role['title'] ?? '').toString().toLowerCase() : '';
            if (roleTitle.contains('prof')) isProf = true;

            // as fallback, check personnel type field for hint
            final rawTypePersonnel = (personnel['idTypepersonnel'] ?? personnel['id_typepersonnel'] ?? personnel['idTypePersonnel']);
            final String? typePersonnel = rawTypePersonnel != null ? rawTypePersonnel.toString().toLowerCase() : null;
            if (!isProf && typePersonnel != null && typePersonnel.contains('prof')) isProf = true;

            if (!isProf) continue; // skip non-prof personnels

            // build a display name from personnel's firstname/lastname
            final first = personnel['firstname'] ?? personnel['first_name'] ?? personnel['firstName'] ?? '';
            final last = personnel['lastname'] ?? personnel['last_name'] ?? personnel['lastName'] ?? '';
            final displayName = ((first?.toString() ?? '') + ' ' + (last?.toString() ?? '')).trim();
            final name = displayName.isNotEmpty ? displayName : (personnel['name'] ?? 'Professeur ${idPersonnel}');

            final personnelUserId = (personnel['idUser'] ?? personnel['id_user'] ?? personnel['iduser'])?.toString();

            // resolve readable classe label if available
            final classeLabel = idClasse != null ? (classesById[idClasse?.toString() ?? ''] ?? idClasse?.toString()) : null;
            results.add(ContactModel(name: name.toString(), avatarUrl: 'https://randomuser.me/api/portraits/lego/1.jpg', classe: classeLabel, personnelId: idPersonnel, personnelUserId: personnelUserId));
          } catch (_) {}
        }
      } else {
        // fallback: coursProfs not available → list all personnels that are profs (can't link to class)
        for (final personnel in personnels) {
          try {
            final idPersonnel = (personnel['id'] ?? '').toString();
            final idUser = (personnel['idUser'] ?? personnel['id_user'] ?? personnel['iduser'])?.toString();
            final user = idUser != null ? usersById[idUser] : null;
            final role = user != null ? rolesById[(user['role_id'] ?? user['roleId'] ?? '')] : null;

            bool isProf = false;
            // check role title
            final roleTitle = role != null ? (role['title'] ?? '').toString().toLowerCase() : '';
            if (roleTitle.contains('prof')) isProf = true;

            // as fallback, check personnel type field for hint
            final rawTypePersonnel = (personnel['idTypepersonnel'] ?? personnel['id_typepersonnel'] ?? personnel['idTypePersonnel']);
            final String? typePersonnel = rawTypePersonnel != null ? rawTypePersonnel.toString().toLowerCase() : null;
            if (!isProf && typePersonnel != null && typePersonnel.contains('prof')) isProf = true;

            if (!isProf) continue; // skip non-prof personnels

            // build a display name from personnel's firstname/lastname
            final first = personnel['firstname'] ?? personnel['first_name'] ?? personnel['firstName'] ?? '';
            final last = personnel['lastname'] ?? personnel['last_name'] ?? personnel['lastName'] ?? '';
            final displayName = ((first?.toString() ?? '') + ' ' + (last?.toString() ?? '')).trim();
            final name = displayName.isNotEmpty ? displayName : (personnel['name'] ?? 'Professeur ${idPersonnel}');

            final personnelUserId = (personnel['idUser'] ?? personnel['id_user'] ?? personnel['iduser'])?.toString();

            // try to resolve a default class for this personnel via classesById if possible (not always available)
            results.add(ContactModel(name: name.toString(), avatarUrl: 'https://randomuser.me/api/portraits/lego/1.jpg', classe: null, personnelId: idPersonnel, personnelUserId: personnelUserId));
          } catch (_) {}
        }

        if (coursProfsError != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Le service coursProfs est indisponible, affichage de tous les professeurs (classe non filtrée). Détail: $coursProfsError')));
        }
      }

      setState(() {
        _contacts = results.isNotEmpty ? results : _fallback;
      });
    } catch (e) {
      setState(() {
        _contacts = _fallback;
        _error = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur en chargeant les contacts: ' + e.toString())));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> _findExistingConversation({String? participantUserId, String? participantPersonnelId, String? parentUserId}) async {
    // Try remote conversations first
    try {
      final convs = await _messagingService.getConversations();
      for (final raw in convs) {
        try {
          final Map<String, dynamic> c = Map<String, dynamic>.from(raw as Map);
          final id = c['id']?.toString();
          // check participants array if present
          if (c.containsKey('participants') && c['participants'] != null) {
            final parts = c['participants'] as List<dynamic>;
            for (final p in parts) {
              if (p == null) continue;
              if (p is String) {
                if ((participantUserId != null && p == participantUserId) || (parentUserId != null && p == parentUserId)) return id;
              } else if (p is Map) {
                final pid = (p['id'] ?? p['user_id'] ?? p['idUser'])?.toString();
                if (pid != null && pid.isNotEmpty) {
                  if ((participantUserId != null && pid == participantUserId) || (parentUserId != null && pid == parentUserId)) return id;
                }
              }
            }
          }
          // check messages for sender/receiver match
          if (c.containsKey('messages') && c['messages'] != null) {
            final msgs = c['messages'] as List<dynamic>;
            for (final m in msgs) {
              final mm = m as Map<String, dynamic>;
              final s = (mm['sender_id'] ?? mm['senderId'] ?? '').toString();
              final r = (mm['receiver_id'] ?? mm['receiverId'] ?? '').toString();
              if ((participantUserId != null && (s == participantUserId || r == participantUserId)) ||
                  (participantPersonnelId != null && (s == participantPersonnelId || r == participantPersonnelId)) ||
                  (parentUserId != null && (s == parentUserId || r == parentUserId))) {
                return id;
              }
            }
          }
          // check meta for remote participant id
          if (c.containsKey('meta') && c['meta'] != null) {
            try {
              final meta = c['meta'] as Map<String, dynamic>;
              final pid = (meta['participant'] ?? meta['participant_id'] ?? meta['user_id'] ?? meta['remote_participant'])?.toString();
              if (pid != null && pid.isNotEmpty) {
                if ((participantUserId != null && pid == participantUserId) || (participantPersonnelId != null && pid == participantPersonnelId)) return id;
              }
            } catch (_) {}
          }
        } catch (_) {}
      }
    } catch (_) {}

    // Try local conversations
    try {
      final localConvs = await _local_service.getConversations();
      for (final raw in localConvs) {
        try {
          final Map<String, dynamic> c = Map<String, dynamic>.from(raw as Map);
          final id = c['id']?.toString();
          // check messages
          if (c.containsKey('messages') && c['messages'] != null) {
            final msgs = c['messages'] as List<dynamic>;
            for (final m in msgs) {
              final mm = m as Map<String, dynamic>;
              final s = (mm['sender_id'] ?? mm['senderId'] ?? '').toString();
              final r = (mm['receiver_id'] ?? mm['receiverId'] ?? '').toString();
              if ((participantUserId != null && (s == participantUserId || r == participantUserId)) ||
                  (participantPersonnelId != null && (s == participantPersonnelId || r == participantPersonnelId)) ||
                  (parentUserId != null && (s == parentUserId || r == parentUserId))) {
                return id;
              }
            }
          }
          // check meta
          if (c.containsKey('meta') && c['meta'] != null) {
            try {
              final meta = c['meta'] as Map<String, dynamic>;
              final pid = (meta['participant'] ?? meta['participant_id'] ?? meta['user_id'] ?? meta['remote_participant'])?.toString();
              if (pid != null && pid.isNotEmpty) {
                if ((participantUserId != null && pid == participantUserId) || (participantPersonnelId != null && pid == participantPersonnelId)) return id;
              }
            } catch (_) {}
          }
        } catch (_) {}
      }
    } catch (_) {}

    return null;
  }

  Future<void> _createConversationAndOpen(ContactModel contact) async {
    // show blocking loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: const CircularProgressIndicator(),
        ),
      ),
    );

    try {
      final title = 'Chat avec ${contact.name}';
      // determine participants: parent (current app user) and selected personnel user id
      final List<String> participants = [];
      // try to find parent user id from shared preferences or elsewhere; for now, if not found we only send personnelUserId
      String? parentUserId;
      try {
        final prefs = await SharedPreferences.getInstance();
        // Try common keys saved at login: 'current_user_id', 'user_id', or full 'user' JSON
        parentUserId = prefs.getString('current_user_id') ?? prefs.getString('user_id') ?? prefs.getString('id');
        if ((parentUserId == null || parentUserId.isEmpty) && prefs.containsKey('user')) {
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
                    final r2 = tryExtract(obj['user']);
                    if (r2 != null) return r2;
                  }
                }
                return null;
              }

              parentUserId = tryExtract(parsed) ?? parentUserId;
             } catch (_) {}
           }
         }
         if ((parentUserId == null || parentUserId.isEmpty)) {
           parentUserId = prefs.getString('id_user') ?? prefs.getString('idUser');
         }
         print('[NewChatScreen] resolved parentUserId=$parentUserId');
       } catch (_) {}
      if (parentUserId != null) participants.add(parentUserId);
      if (contact.personnelUserId != null) participants.add(contact.personnelUserId!);

      // prevent duplicate: try to find existing conversation
      final convIdExisting = await _findExistingConversation(participantUserId: contact.personnelUserId, participantPersonnelId: contact.personnelId, parentUserId: parentUserId);
      Navigator.of(context).pop(); // close loader before navigation
      if (convIdExisting != null && convIdExisting.isNotEmpty) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen(name: contact.name, avatarUrl: contact.avatarUrl, conversationId: convIdExisting, currentUserId: parentUserId, receiverUserId: contact.personnelUserId, receiverPersonnelId: contact.personnelId)));
        return;
      }

      try {
        final convId = await _messagingService.createConversation(title: title, participants: participants.isNotEmpty ? participants : null);
        if (convId.isNotEmpty) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen(name: contact.name, avatarUrl: contact.avatarUrl, conversationId: convId, currentUserId: parentUserId, receiverUserId: contact.personnelUserId, receiverPersonnelId: contact.personnelId)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible de créer la conversation')));
        }
      } catch (e) {
        // if remote creation fails, create a local conversation as fallback
        try {
          final localId = await _local_service.createLocalConversation(title: title, meta: {'remote_id': null});
          await _local_service.mergeAndSaveConversationFromApi({'id': localId, 'title': title, 'messages': [], 'created_at': DateTime.now().toIso8601String(), 'updated_at': DateTime.now().toIso8601String()});
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen(name: contact.name, avatarUrl: contact.avatarUrl, conversationId: localId, currentUserId: parentUserId, receiverUserId: contact.personnelUserId, receiverPersonnelId: contact.personnelId)));
          return;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur création conversation: ' + e.toString())));
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur création conversation: ' + e.toString())));
    }
  }

  Widget _buildContactAvatar(ContactModel contact) {
    final url = contact.avatarUrl;
    // treat common placeholder urls as "no avatar" so we prefer initials
    final isPlaceholder = url.isEmpty || url.contains('randomuser.me') || url.contains('lego');
    if (!isPlaceholder) {
      return CircleAvatar(radius: 20, backgroundImage: NetworkImage(url));
    }
    final initial = (contact.name.isNotEmpty) ? contact.name.trim().substring(0, 1).toUpperCase() : '';
    return CircleAvatar(radius: 20, backgroundColor: AppColors.secondaryColor(context), child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau Chat'),
        backgroundColor: AppColors.backgroundLight,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContacts,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _contacts.isEmpty
                  ? Center(child: Text('Aucun contact trouvé'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: _contacts.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final contact = _contacts[index];
                        return ListTile(
                          onTap: () {
                            // start chat with this contact
                            _createConversationAndOpen(contact);
                          },
                          leading: _buildContactAvatar(contact),
                          title: Text(contact.name),
                          subtitle: contact.classe != null ? Text('Classe: ${contact.classe}') : null,
                        );
                      },
                    ),
    );
  }
}
