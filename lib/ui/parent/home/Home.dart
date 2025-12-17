import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:slatereduc/ui/parent/chat/chat.dart';
import 'package:slatereduc/ui/parent/activity/activity.dart';
import 'package:slatereduc/ui/parent/profil/profil.dart';
import 'package:slatereduc/ui/parent/home/widget.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../notification/NotificationScreen.dart';
import 'package:slatereduc/services/api/parent_service.dart';
import 'package:slatereduc/services/api/presence_service.dart';
import 'package:slatereduc/services/api/notification_service.dart';
import 'package:slatereduc/services/auth/user_identity_helper.dart';
import 'package:slatereduc/services/api/eleve_service.dart';

// Helpers globaux notifications
bool _isUnread(Map<String, dynamic> n) {
  final v = n['is_read'];
  if (v == null) return true;
  if (v is bool) return v == false;
  final s = v.toString().toLowerCase();
  return !(s == 'true' || s == '1');
}

DateTime _parseDate(dynamic v) {
  try {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    final s = v.toString();
    return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
  } catch (_) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}


class HomePage extends StatefulWidget {
  final Map<String, dynamic>? parentData;

  const HomePage({super.key, this.parentData});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final PageController _controller = PageController();
  int _selectedIndex = 0;
  int _currentChildIndex = 0;
  bool _isLoadingAvatar = true;

  List<Map<String, dynamic>> _eleves = [];
  bool _isLoadingEleves = true;
  String? _elevesError;

  final ParentService _parentService = ParentService();
  final PresenceService _presenceService = PresenceService();
  // Service notifications
  final NotificationService _notificationService = NotificationService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoadingNotifications = true;

  // Liste des avatars proposés
  final List<String> _avatarUrls = [
    'https://static.vecteezy.com/system/resources/previews/027/951/137/non_2x/stylish-spectacles-guy-3d-avatar-character-illustrations-png.png',
    'https://img.freepik.com/psd-premium/avatar-3d-lunettes-personnage-pull_1155620-2211.jpg?semt=ais_hybrid&w=740&q=80',
    'https://img.freepik.com/premium-photo/memoji-african-american-man-white-background-emoji_826801-6856.jpg',
    'https://img.freepik.com/premium-photo/memoji-homme-heureux-fond-blanc-emoji_826801-6832.jpg',
    'https://img.freepik.com/photos-gratuite/personnage-dessin-anime-3d_23-2151034079.jpg?semt=ais_hybrid&w=740&q=80',
    'https://img.freepik.com/photos-premium/memoji-belle-fille-femme-fond-blanc-emoji_826801-6879.jpg?semt=ais_hybrid&w=740&q=80',
    'https://img.freepik.com/photos-premium/avatar-dessin-anime-rendu-3d-personnage-cartoon-isole_608116-56.jpg?w=360',
    'https://img.freepik.com/photos-premium/portrait-dessin-anime-adulte-souriant_53876-760918.jpg?semt=ais_hybrid&w=740&q=80',
    'https://img.freepik.com/premium-photo/massage-therapist-digital-avatar-generative-ai_934475-9090.jpg?semt=ais_hybrid&w=740&q=80',
    'https://img.freepik.com/photos-premium/memoji-beau-type-asiatique-homme-chinois-fond-blanc-personnage-dessin-anime-emoji_826801-7436.jpg',
    'https://img.freepik.com/photos-gratuite/portrait-3d-homme-affaires_23-2150793885.jpg?semt=ais_hybrid&w=740&q=80',
    'https://img.freepik.com/photos-gratuite/portrait-3d-homme-affaires_23-2150793883.jpg?semt=ais_hybrid&w=740&q=80',
  ];
  // Avatar sélectionné
  String _selectedAvatarUrl = 'https://static.vecteezy.com/system/resources/previews/027/951/137/non_2x/stylish-spectacles-guy-3d-avatar-character-illustrations-png.png';

  // Nom et prénom du parent
  String _parentFirstName = '';
  String _parentLastName = '';

  Timer? _presenceTimer;
  bool _presenceRefreshInProgress = false;

  // Lance un timer qui recharge les présences périodiquement (quasi temps réel)
  void _startPresenceAutoRefresh() {
    _presenceTimer?.cancel();
    // Refresh toutes les 10 secondes (ajuste si besoin)
    _presenceTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      if (_presenceRefreshInProgress) return;
      if (_eleves.isEmpty) return;
      _presenceRefreshInProgress = true;
      try {
        await _enrichElevesWithPresence();
      } catch (_) {} finally {
        _presenceRefreshInProgress = false;
      }
    });
  }

  void _stopPresenceAutoRefresh() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onPageChanged);
    _loadAvatar();
    _loadEleves();
    _loadNotifications();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // À la reprise, rafraîchir rapidement pour refléter d’éventuelles présences nouvellement envoyées
      _enrichElevesWithPresence();
    }
  }

  Future<void> _loadEleves() async {
    setState(() {
      _isLoadingEleves = true;
      _elevesError = null;
    });

    try {
      // Tentatives pour déterminer l'ID du parent à partir des données reçues
      String? parentId;

      // Cas 1: parentData contient directement l'id ou id_user (ex: on a passé l'objet parent)
      if (widget.parentData != null) {
        final pd = widget.parentData!;
        // debug: afficher la structure reçue
        print('DEBUG: parentData passed to Home: ${pd.toString()}');
        parentId = (pd['id'] ?? pd['id_user'])?.toString();

        // Cas 2: parentData est en fait la réponse de login qui contient un objet 'user'
        if (parentId == null && pd['user'] is Map) {
          parentId = (pd['user']['id'] ?? pd['user']['user_id'])?.toString();
        }

        // Cas 3: parfois la réponse contient directement un objet 'user' (si on a passé user)
        if (parentId == null && pd['id'] == null && pd['username'] != null && pd['email'] != null) {
          // Peut-être que pd est l'objet user lui-même
          parentId = (pd['user_id'] ?? pd['id'])?.toString();
        }
      }

      // debug: afficher l'id déduit
      print('DEBUG: resolved parentId=$parentId');

      // Cas 4: fallback à SharedPreferences (AuthService stocke 'user_id' lors du login)
      if (parentId == null) {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString('user_id');
        print('DEBUG: user_id from prefs=$saved');
        if (saved != null && saved.isNotEmpty) parentId = saved;
      }

      if (parentId == null) {
        // Si on ne trouve toujours pas d'ID parent, on renvoie des données factices minimales pour garder l'app fonctionnelle
        _eleves = [];
      } else {
        final list = await _parentService.getElevesByParentId(parentId);
        _eleves = list;
        // enrichir chaque élève avec la présence de la semaine courante
        await _enrichElevesWithPresence();
        // Charger le nom du parent depuis la liste /parents
        await _loadParentNameFromList(parentId);
        // Démarrer le rafraîchissement automatique des présences
        _startPresenceAutoRefresh();

        // Nouveau: peupler family_user_ids (parent + élèves) pour les notifications
        try {
          final ids = <String>{};
          final me = await UserIdentityHelper.instance.getCurrentIdUser();
          if (me != null && me.isNotEmpty) ids.add(me);
          final eleveService = EleveService();
          for (final e in _eleves) {
            String? idUser = (e['id_user'] ?? e['user_id'])?.toString();
            if (idUser == null || idUser.isEmpty) {
              final String? eid = (e['id'] ?? e['id_eleve'] ?? e['eleve_id'] ?? e['student_id'])?.toString();
              if (eid != null && eid.isNotEmpty) {
                final detailed = await eleveService.fetchEleveById(eid);
                idUser = (detailed['id_user'] ?? detailed['user_id'])?.toString();
              }
            }
            if (idUser != null && idUser.isNotEmpty) ids.add(idUser);
          }
          if (ids.isNotEmpty) {
            await UserIdentityHelper.instance.cacheFamilyUserIds(ids);
            print('DEBUG: cached family_user_ids=${ids.join(', ')}');
          } else {
            print('WARN: unable to resolve any id_user for family');
          }
        } catch (e) {
          print('ERROR: failed to cache family_user_ids: $e');
        }
      }
    } catch (e) {
      _elevesError = e.toString();
      _eleves = [];
      // log de l'erreur
      print('ERROR: Failed to load eleves: $e');
    } finally {
      if (mounted) setState(() {
        _isLoadingEleves = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getAllParents() async {
    final url = '${_parentService.baseUrl}/parents';
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        if (body is List) {
          return List<Map<String, dynamic>>.from(body.map((e) => Map<String, dynamic>.from(e)));
        }
      }
    } catch (e) {
      print('Erreur getAllParents: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> _getConnectedParent() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId;
    if (widget.parentData != null) {
      userId = widget.parentData!['id_user']?.toString();
      if (userId == null && widget.parentData!['id'] != null) {
        userId = widget.parentData!['id'].toString();
      }
      if (userId == null && widget.parentData!['user'] is Map) {
        userId = widget.parentData!['user']['id']?.toString();
      }
    }
    if (userId == null) {
      userId = prefs.getString('user_id');
    }
    final parentsList = await _getAllParents();
    if (userId != null && parentsList.isNotEmpty) {
      final found = parentsList.firstWhere(
        (p) => p['id_user']?.toString() == userId,
        orElse: () => <String, dynamic>{},
      );
      if (found.isNotEmpty) return found;
    }
    return {};
  }

  Future<void> _loadParentNameFromList(String parentId) async {
    try {
      final parent = await _getConnectedParent();
      setState(() {
        _parentFirstName = parent['first_name'] ?? '';
        _parentLastName = parent['last_name'] ?? '';
      });
      print('DEBUG: parent name loaded from service: $_parentFirstName $_parentLastName');
    } catch (e) {
      print('ERROR: Failed to load parent name from service: $e');
    }
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('selected_avatar_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _selectedAvatarUrl = savedUrl;
    }
    setState(() {
      _isLoadingAvatar = false;
    });
  }

  Future<String?> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? uid = prefs.getString('current_user_id') ?? prefs.getString('user_id') ?? prefs.getString('id');
      if ((uid == null || uid.isEmpty) && prefs.containsKey('user')) {
        final raw = prefs.getString('user');
        if (raw != null && raw.isNotEmpty) {
          try {
            final parsed = json.decode(raw);
            if (parsed is Map && parsed['id'] != null) uid = parsed['id'].toString();
          } catch (_) {}
        }
      }
      return uid;
    } catch (_) {
      return null;
    }
  }

  bool _isOutgoingMessageNotif(Map<String, dynamic> n, String myId) {
    final type = (n['notif_type'] ?? '').toString().toUpperCase();
    if (type != 'MESSAGE') return false;
    final sender = (n['sender_id'] ?? n['senderId'] ?? n['from_user_id'] ?? n['fromUserId'] ?? n['id_user'] ?? n['user_id'])?.toString();
    if (sender == null || sender.isEmpty) return false;
    return sender == myId;
  }

  List<Map<String, dynamic>> _filterDisplayNotifications(List<Map<String, dynamic>> list, String? myId) {
    if (myId == null || myId.isEmpty) return list;
    return list.where((n) => !_isOutgoingMessageNotif(n, myId)).toList();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoadingNotifications = true;
    });
    try {
      // Utiliser le service pour récupérer uniquement les notifications entrantes (exclut les messages envoyés par moi)
      final list = await _notificationService.getIncomingNotificationsForCurrentUser();
      if (mounted) setState(() {
        _notifications = list;
      });
    } catch (e) {
      print('ERROR: Failed to load notifications: $e');
      if (mounted) setState(() {
        _notifications = [];
      });
    } finally {
      if (mounted) setState(() {
        _isLoadingNotifications = false;
      });
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationScreen(),
      ),
    );
    await _loadNotifications();
  }

  Future<void> _markNotificationRead(String id) async {
    try {
      await _notificationService.markAsRead(id);
    } catch (_) {}
    await _loadNotifications();
  }

  @override
  void dispose() {
    _controller.removeListener(_onPageChanged);
    _controller.dispose();
    _stopPresenceAutoRefresh();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onPageChanged() {
    setState(() {
      _currentChildIndex = _controller.page?.round() ?? 0;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Fonction pour afficher la sélection d'avatars
  void _showAvatarSelection() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            children: _avatarUrls.map((url) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context, url);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundImage: NetworkImage(url),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
    if (selected != null && selected != _selectedAvatarUrl) {
      setState(() {
        _selectedAvatarUrl = selected;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_avatar_url', selected);
    }
  }

  Future<void> _enrichElevesWithPresence() async {
    try {
      if (_eleves.isEmpty) return;

      // Calculer les jours de la semaine courante (Lundi -> Samedi)
      final today = DateTime.now();
      final monday = today.subtract(Duration(days: today.weekday - 1)); // weekday: Mon=1
      final weekDays = List<DateTime>.generate(6, (i) => DateTime(monday.year, monday.month, monday.day + i));

      // Récupérer toutes les sessions (le service peut ignorer l'idClasse actuellement)
      final sessions = await _presenceService.getSessionsPresence('');

      // Préparer un mapping date -> liste de sessions (par jour)
      final Map<String, List<Map<String, dynamic>>> sessionsByDate = {};
      for (final s in sessions) {
        try {
          final dateRaw = s['date'] ?? s['created_at'];
          if (dateRaw == null) continue;
          final dt = DateTime.parse(dateRaw.toString()).toLocal();
          final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          sessionsByDate.putIfAbsent(key, () => []).add(s);
        } catch (e) {
          // ignore malformed dates
          print('WARN: unable to parse session date: $e');
        }
      }

      // Pour chaque élève récupérer ses présences
      for (final e in _eleves) {
        try {
          String? eleveId = (e['id'] ?? e['id_eleve'] ?? e['eleve_id'] ?? e['student_id'] ?? e['user_id'])?.toString();
          if (eleveId == null || eleveId.isEmpty) {
            if (e.containsKey('id') && e['id'] != null) eleveId = e['id'].toString();
          }

          final presences = (eleveId != null) ? await _presenceService.getPresencesForEleve(eleveId) : <Map<String, dynamic>>[];

          final List<bool?> presenceForWeek = List<bool?>.filled(6, null);
          final List<Color> colorsForWeek = List<Color>.filled(6, Colors.orange);

          for (var i = 0; i < weekDays.length; i++) {
            final d = weekDays[i];
            final dayPresence = presences.firstWhere(
              (p) {
                try {
                  final pd = DateTime.parse(p['created_at']);
                  return pd.day == d.day && pd.month == d.month && pd.year == d.year;
                } catch (_) {
                  return false;
                }
              },
              orElse: () => <String, dynamic>{},
            );
            if (dayPresence.isEmpty) {
              presenceForWeek[i] = null;
              colorsForWeek[i] = Colors.orange;
            } else if (dayPresence['is_present'] == true) {
              presenceForWeek[i] = true;
              colorsForWeek[i] = Colors.blue;
            } else if (dayPresence['is_present'] == false) {
              presenceForWeek[i] = false;
              colorsForWeek[i] = Colors.red;
            } else {
              presenceForWeek[i] = null;
              colorsForWeek[i] = Colors.orange;
            }
          }

          e['presence'] = presenceForWeek;
          e['presenceColors'] = colorsForWeek;
        } catch (err) {
          e['presence'] = [null, null, null, null, null, null];
          e['presenceColors'] = [Colors.orange, Colors.orange, Colors.orange, Colors.orange, Colors.orange, Colors.orange];
        }
      }

      // Mettre à jour l'UI
      if (mounted) setState(() {});
    } catch (e) {
      print('ERROR: _enrichElevesWithPresence failed: $e');
    }
  }

  // Ajout des pages pour chaque onglet du BottomNavigationBar
  List<Widget> get _pages => [
    _HomeTab(
      controller: _controller,
      currentChildIndex: _currentChildIndex,
      username: widget.parentData != null ? (widget.parentData!['first_name'] ?? '') : '',
      firstName: _parentFirstName,
      lastName: _parentLastName,
      avatarUrl: _selectedAvatarUrl,
      onAvatarTap: _showAvatarSelection,
      eleves: _eleves,
      isLoadingEleves: _isLoadingEleves,
      elevesError: _elevesError,
      notifications: _notifications,
      isLoadingNotifications: _isLoadingNotifications,
      onOpenNotifications: _openNotifications,
      onMarkNotificationRead: _markNotificationRead,
    ),
    ChatTab(),
    ActiviteTab(eleves: _eleves),
    ProfilTab(),
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAvatar) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Récupère les couleurs du thème pour la bottom navigation (avec fallbacks)
    final navTheme = Theme.of(context).bottomNavigationBarTheme;
    final navBackground = navTheme.backgroundColor ?? AppColors.surfaceLight;
    final selectedColor = navTheme.selectedItemColor ?? AppColors.primaryBase;
    final unselectedColor = navTheme.unselectedItemColor ?? Colors.grey.shade600;

    return Scaffold(
      body: SafeArea(
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBackground,
          boxShadow: [
            BoxShadow(
              color: AppColors.alpha(Colors.black, 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: "Home",
                  isActive: _selectedIndex == 0,
                  onTap: () => _onItemTapped(0),
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor,
                ),
                _BottomNavItem(
                  icon: Icons.chat_outlined,
                  activeIcon: Icons.chat_rounded,
                  label: "Chat",
                  isActive: _selectedIndex == 1,
                  onTap: () => _onItemTapped(1),
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor,
                ),
                _BottomNavItem(
                  icon: Icons.event_outlined,
                  activeIcon: Icons.event_rounded,
                  label: "Activité",
                  isActive: _selectedIndex == 2,
                  onTap: () => _onItemTapped(2),
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor,
                ),
                _BottomNavItem(
                  icon: Icons.person_outlined,
                  activeIcon: Icons.person_rounded,
                  label: "Profil",
                  isActive: _selectedIndex == 3,
                  onTap: () => _onItemTapped(3),
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color unselectedColor;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.selectedColor,
    required this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final selColor = selectedColor;
    final unselColor = unselectedColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.alpha(selColor, 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? selColor : unselColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? selColor : unselColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final PageController controller;
  final int currentChildIndex;
  final String username;
  final String firstName;
  final String lastName;
  final String avatarUrl;
  final VoidCallback onAvatarTap;
  final List<Map<String, dynamic>> eleves;
  final bool isLoadingEleves;
  final String? elevesError;
  final List<Map<String, dynamic>> notifications;
  final bool isLoadingNotifications;
  final Future<void> Function()? onOpenNotifications;
  final Future<void> Function(String id)? onMarkNotificationRead;

  const _HomeTab({
    required this.controller,
    required this.currentChildIndex,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.avatarUrl,
    required this.onAvatarTap,
    required this.eleves,
    required this.isLoadingEleves,
    required this.elevesError,
    required this.notifications,
    required this.isLoadingNotifications,
    this.onOpenNotifications,
    this.onMarkNotificationRead,
  });

  // Données des statistiques pour chaque enfant
  final List<Map<String, List<Map<String, String>>>> _childrenStats = const [
    {
      "stats": [
        {"value": "83%", "label": "Moyenne Périodique"},
        {"value": "6/50", "label": "Place au classement"},
      ]
    },
    {
      "stats": [
        {"value": "75%", "label": "Moyenne Périodique"},
        {"value": "12/50", "label": "Place au classement"},
      ]
    },
    {
      "stats": [
        {"value": "92%", "label": "Moyenne Périodique"},
        {"value": "3/50", "label": "Place au classement"},
      ]
    },
  ];

  List<Color> _buildPresenceColors(List<dynamic> presence) {
    return presence.map((p) {
      if (p == null) return Colors.orange;
      try {
        final boolVal = p as bool;
        return boolVal ? Colors.blue : Colors.red;
      } catch (_) {
        return Colors.orange;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentStats = _childrenStats[currentChildIndex]["stats"]!;


    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            children: [
              InkWell(
                onTap: onAvatarTap,
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: AppColors.primary(context),
                  child: ClipOval(
                    child: Image.network(
                      avatarUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/images/avatar_default.png',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bonjour,",
                    style: TextStyle(fontSize: 16, color: AppColors.accentColor(context)),
                  ),
                  // Affichage du prénom et nom du parent
                  Text(
                    (firstName + " " + lastName).trim(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                  ),
                ],
              ),
              const Spacer(),
              // Icône notifications : affiche un loader si on charge, sinon badge si notifications non lues
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_none, color: AppColors.text(context)),
                    onPressed: () async {
                      if (onOpenNotifications != null) {
                        await onOpenNotifications!();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  if (isLoadingNotifications)
                    Positioned(
                      right: 6,
                      top: 12,
                      child: SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation(AppColors.primary(context))),
                      ),
                    )
                  else
                    // badge nombre non-lu
                    Builder(builder: (_) {
                      final unread = notifications.where((n) {
                        final v = n['is_read'];
                        if (v == null) return true;
                        if (v is bool) return v == false;
                        final s = v.toString().toLowerCase();
                        return !(s == 'true' || s == '1');
                      }).length;
                      if (unread <= 0) return const SizedBox.shrink();
                      return Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Center(
                            child: Text(
                              unread > 9 ? '9+' : unread.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // CARTE ENFANT
          SizedBox(
            height: 180, // hauteur du PageView
            child: PageView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              children: [
                // Si la liste d'élèves est chargée, on la mappe; sinon on affiche des placeholders
                if (isLoadingEleves)
                  ChildCard(
                    name: "Chargement...",
                    level: "",
                    presence: [false, false, false, false, false, false],
                    presenceColors: _buildPresenceColors([false, false, false, false, false, false]),
                  ),
                if (!isLoadingEleves && eleves.isEmpty)
                  ChildCard(
                    name: "Aucun enfant trouvé",
                    level: "",
                    presence: [false, false, false, false, false, false],
                    presenceColors: _buildPresenceColors([false, false, false, false, false, false]),
                  ),
                if (!isLoadingEleves && eleves.isNotEmpty)
                  for (final e in eleves)
                    ChildCard(
                      name: (e['first_name'] ?? '') + ' ' + (e['last_name'] ?? ''),
                      level: e['classe'] ?? e['level'] ?? 'N/A',
                      presence: (e['presence'] is List)
                        ? List<bool?>.from(e['presence'])
                        : [null, null, null, null, null, null],
                      presenceColors: (e['presenceColors'] is List)
                        ? List<Color>.from(e['presenceColors'])
                        : [Colors.orange, Colors.orange, Colors.orange, Colors.orange, Colors.orange, Colors.orange],
                    ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Center(
            child: SmoothPageIndicator(
              controller: controller,
              count: eleves.isNotEmpty ? eleves.length : 1, // nombre d'enfants
              effect: ExpandingDotsEffect(
                activeDotColor: AppColors.primary(context),
                dotHeight: 8,
                dotWidth: 8,
                expansionFactor: 3,
                spacing: 4,
              ),
            ),
          ),

          const SizedBox(height: 16),


          // STATISTIQUES - QUI CHANGE AVEC L'ENFANT
          Container(
            width: double.infinity, // occupe toute la largeur
            margin: const EdgeInsets.symmetric(horizontal: 12), // marge externe
            padding: const EdgeInsets.all(16), // espace interne
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryBase,
                  AppColors.accentColor(context),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  "Statistiques Périodique",
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final stat in currentStats)
                      StatItem(value: stat["value"]!, label: stat["label"]!),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // SECTION PROGRESSION (Dynamique selon l'enfant sélectionné)
          Builder(builder: (context) {
            // helper to find first non-null key
            dynamic firstNonNull(Map<String, dynamic> m, List<String> keys) {
              for (final k in keys) {
                if (m.containsKey(k) && m[k] != null) return m[k];
              }
              return null;
            }

            final int idx = (eleves.isNotEmpty && currentChildIndex < eleves.length) ? currentChildIndex : 0;
            final Map<String, dynamic> child = (eleves.isNotEmpty && eleves.length > idx) ? eleves[idx] : {};
            final String childName = ((child['first_name'] ?? child['name'] ?? child['full_name'])?.toString() ?? 'L\'élève').toString();

            // Identifiant élève pour filtrer les notifications
            final String? childId = (child['id'] ?? child['id_eleve'] ?? child['eleve_id'] ?? child['student_id'] ?? child['user_id'])?.toString();
            // id_user de l'élève (prioritaire pour le filtrage demandé)
            final String? childUserId = (child['id_user'] ?? child['user_id'])?.toString();

            // Filtrer notifications d'évaluation par enfant via comparaison id_user (exigence)
            final List<Map<String, dynamic>> progNotifsAll = notifications
                .where((n) => (n['notif_type'] ?? '').toString().toUpperCase() == 'EVALUATION')
                .toList();
            final List<Map<String, dynamic>> progNotifs = progNotifsAll.where((n) {
              final String? notifUserId = n['id_user']?.toString();
              if (childUserId != null && notifUserId != null) return notifUserId == childUserId;
              // fallback sur id élève si id_user manquant
              final String? nid = (n['child_id'] ?? n['eleve_id'] ?? n['student_id'] ?? n['user_id'])?.toString();
              return childId == null || nid == null || nid == childId;
            }).toList()
              ..sort((a, b) => _parseDate(b['created_at'] ?? b['date']).compareTo(_parseDate(a['created_at'] ?? a['date'])));

            // Sélectionner la dernière notification (lue ou non)
            final Map<String, dynamic>? latestProg = progNotifs.isNotEmpty ? progNotifs.first : null;

            if (latestProg == null) {
              // Pas de notification: message sur une carte (pas de carte cliquable)
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Progression",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                  ),
                  const SizedBox(height: 12),
                  // Carte message Progression
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background(context),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: AppColors.alpha(Colors.grey, 0.1), blurRadius: 6, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.menu_book, color: AppColors.primary(context)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Aucune notification de progression pour ${childName}.",
                            style: TextStyle(fontSize: 12, color: AppColors.alpha(AppColors.text(context), 0.7)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // SECTION DISCIPLINE (toujours affichée indépendamment de Progression)
                  Text(
                    "Discipline",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Builder(builder: (context) {
                    final List<Map<String, dynamic>> discNotifsAll = notifications
                        .where((n) => (n['notif_type'] ?? '').toString().toUpperCase() == 'PUNITION')
                        .toList();
                    // Filtrer par comparaison id_user (exigence)
                    final List<Map<String, dynamic>> discNotifs = discNotifsAll.where((n) {
                      final String? notifUserId = n['id_user']?.toString();
                      if (childUserId != null && notifUserId != null) return notifUserId == childUserId;
                      // fallback sur id élève si id_user manquant
                      final String? nid = (n['child_id'] ?? n['eleve_id'] ?? n['student_id'] ?? n['user_id'])?.toString();
                      return childId == null || nid == null || nid == childId;
                    }).toList()
                      ..sort((a, b) => _parseDate(b['created_at'] ?? b['date']).compareTo(_parseDate(a['created_at'] ?? a['date'])));

                    final Map<String, dynamic>? latestDisc = discNotifs.isNotEmpty ? discNotifs.first : null;

                    if (latestDisc == null) {
                      // Carte message Discipline
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background(context),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.alpha(Colors.grey, 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.rule, color: AppColors.primary(context)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Aucune notification de discipline pour ${childName}.",
                                style: TextStyle(fontSize: 12, color: AppColors.alpha(AppColors.text(context), 0.7)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final Map<String, dynamic> dn = latestDisc;
                    final String disciplineTitle = (dn['title']?.toString() ?? 'Barème de sanction');
                    final String disciplineDesc = '${childName}: ${(dn['content']?.toString() ?? 'Notification de sanction')}';
                    double disciplineScore = 0.0;
                    try {
                      final raw = dn['percentage'] ?? dn['score'] ?? dn['value'];
                      if (raw != null) {
                        disciplineScore = double.parse(raw.toString());
                        if (disciplineScore > 1) disciplineScore = disciplineScore / 100.0;
                      }
                    } catch (_) {}
                    final String disciplineLabel = (disciplineScore > 0)
                        ? '${(disciplineScore.clamp(0.0, 1.0) * 100).round()}%'
                        : 'N/A';

                    final bool isRead = () {
                      final v = dn['is_read'];
                      if (v == null) return false;
                      if (v is bool) return v;
                      final s = v.toString().toLowerCase();
                      return s == 'true' || s == '1';
                    }();

                    return InkWell(
                      onTap: () async {
                        // Boîte de dialogue avec détails
                        await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(disciplineTitle),
                            content: Text(disciplineDesc),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                        // Marquer comme lue si non-lue
                        final id = dn['id']?.toString();
                        if (!isRead && id != null && id.isNotEmpty) {
                          await onMarkNotificationRead?.call(id);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background(context),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.alpha(Colors.grey, 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.rule, color: AppColors.primary(context)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          disciplineTitle,
                                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text(context)),
                                        ),
                                      ),
                                      // Point rouge uniquement si non-lue
                                      if (!isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    disciplineDesc,
                                    style: TextStyle(fontSize: 12, color: AppColors.alpha(AppColors.text(context), 0.7)),
                                  ),
                                ],
                              ),
                            ),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  height: 45,
                                  width: 45,
                                  child: CircularProgressIndicator(
                                    value: disciplineScore.clamp(0.0, 1.0),
                                    strokeWidth: 5,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation(AppColors.primary(context)),
                                  ),
                                ),
                                Text(
                                  disciplineLabel,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            }

            final Map<String, dynamic> n = latestProg;
            final String progressionTitle = (n['title']?.toString() ?? 'Progression');
            final String progressionDesc = '${childName}: ${(n['content']?.toString() ?? 'Mise à jour de la progression')}';
            double progressionPercent = 0.0;
            try {
              final percRaw = n['percentage'] ?? n['progress'] ?? n['value'];
              if (percRaw != null) {
                progressionPercent = double.parse(percRaw.toString());
                if (progressionPercent > 1) progressionPercent = progressionPercent / 100.0;
              }
            } catch (_) {
              progressionPercent = 0.0;
            }
            final String progressionLabel = (progressionPercent > 0) ? '${(progressionPercent * 100).round()}%' : 'N/A';
            final bool progIsRead = () {
              final v = n['is_read'];
              if (v == null) return false;
              if (v is bool) return v;
              final s = v.toString().toLowerCase();
              return s == 'true' || s == '1';
            }();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Progression",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                ),
                const SizedBox(height: 12),
                // Carte affichée pour la dernière (cliquable, point rouge si non-lue, dialog)
                InkWell(
                  onTap: () async {
                    await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(progressionTitle),
                        content: Text(progressionDesc),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
                        ],
                      ),
                    );
                    final id = n['id']?.toString();
                    if (!progIsRead && id != null && id.isNotEmpty) {
                      await onMarkNotificationRead?.call(id);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background(context),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.alpha(Colors.grey, 0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.menu_book, color: AppColors.primary(context)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      progressionTitle, // motif principal
                                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text(context)),
                                    ),
                                  ),
                                  if (!progIsRead)
                                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                progressionDesc, // nom enfant + description
                                style: TextStyle(fontSize: 12, color: AppColors.alpha(AppColors.text(context), 0.7)),
                              ),
                            ],
                          ),
                        ),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              height: 45,
                              width: 45,
                              child: CircularProgressIndicator(
                                value: progressionPercent.clamp(0.0, 1.0),
                                strokeWidth: 5,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation(AppColors.primary(context)),
                              ),
                            ),
                            Text(
                              progressionLabel,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION DISCIPLINE (dynamique selon l'enfant sélectionné)
                Text(
                  "Discipline",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  // Filtrer notifications de punitions par enfant via comparaison id_user (exigence)
                  final List<Map<String, dynamic>> discNotifsAll = notifications
                      .where((n) => (n['notif_type'] ?? '').toString().toUpperCase() == 'PUNITION')
                      .toList();
                  final List<Map<String, dynamic>> discNotifs = discNotifsAll.where((n) {
                    final String? notifUserId = n['id_user']?.toString();
                    if (childUserId != null && notifUserId != null) return notifUserId == childUserId;
                    // fallback sur id élève si id_user manquant
                    final String? nid = (n['child_id'] ?? n['eleve_id'] ?? n['student_id'] ?? n['user_id'])?.toString();
                    return childId == null || nid == null || nid == childId;
                  }).toList()
                    ..sort((a, b) => _parseDate(b['created_at'] ?? b['date']).compareTo(_parseDate(a['created_at'] ?? a['date'])));

                  final Map<String, dynamic>? latestDisc = discNotifs.isNotEmpty ? discNotifs.first : null;

                  if (latestDisc == null) {
                    // Carte message Discipline (pas de notification)
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background(context),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.alpha(Colors.grey, 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.rule, color: AppColors.primary(context)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Aucune notification de discipline pour ${childName}.",
                              style: TextStyle(fontSize: 12, color: AppColors.alpha(AppColors.text(context), 0.7)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final Map<String, dynamic> dn = latestDisc;
                  final String disciplineTitle = (dn['title']?.toString() ?? 'Barème de sanction');
                  final String disciplineDesc = '${childName}: ${(dn['content']?.toString() ?? 'Notification de sanction')}';
                  double disciplineScore = 0.0;
                  try {
                    final raw = dn['percentage'] ?? dn['score'] ?? dn['value'];
                    if (raw != null) {
                      disciplineScore = double.parse(raw.toString());
                      if (disciplineScore > 1) disciplineScore = disciplineScore / 100.0;
                    }
                  } catch (_) {}
                  final String disciplineLabel = (disciplineScore > 0)
                      ? '${(disciplineScore.clamp(0.0, 1.0) * 100).round()}%'
                      : 'N/A';

                  final bool isRead = () {
                    final v = dn['is_read'];
                    if (v == null) return false;
                    if (v is bool) return v;
                    final s = v.toString().toLowerCase();
                    return s == 'true' || s == '1';
                  }();

                  return InkWell(
                    onTap: () async {
                      await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(disciplineTitle),
                          content: Text(disciplineDesc),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
                          ],
                        ),
                      );
                      final id = dn['id']?.toString();
                      if (!isRead && id != null && id.isNotEmpty) {
                        await onMarkNotificationRead?.call(id);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background(context),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.alpha(Colors.grey, 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.rule, color: AppColors.primary(context)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        disciplineTitle, // motif principal
                                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text(context)),
                                      ),
                                    ),
                                    // Point rouge uniquement si non-lue
                                    if (!isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  disciplineDesc, // nom enfant + description
                                  style: TextStyle(fontSize: 12, color: AppColors.alpha(AppColors.text(context), 0.7)),
                                ),
                              ],
                            ),
                          ),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                height: 45,
                                width: 45,
                                child: CircularProgressIndicator(
                                  value: disciplineScore.clamp(0.0, 1.0),
                                  strokeWidth: 5,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation(AppColors.primary(context)),
                                ),
                              ),
                              Text(
                                disciplineLabel,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
        ],
      ),
    );
  }
}

