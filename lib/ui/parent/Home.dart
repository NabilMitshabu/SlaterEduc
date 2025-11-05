import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:slatereduc/ui/parent/chat.dart';
import 'package:slatereduc/ui/parent/activity.dart';
import 'package:slatereduc/ui/parent/profil.dart';
import 'package:slatereduc/ui/parent/widget.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'NotificationScreen.dart';
import 'package:slatereduc/services/parent_service.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic>? parentData;

  const HomePage({super.key, this.parentData});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _controller = PageController();
  int _selectedIndex = 0;
  int _currentChildIndex = 0;
  bool _isLoadingAvatar = true;

  List<Map<String, dynamic>> _eleves = [];
  bool _isLoadingEleves = true;
  String? _elevesError;

  final ParentService _parentService = ParentService();

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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onPageChanged);
    _loadAvatar();
    _loadEleves();
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
        // Charger le nom du parent depuis la liste /parents
        await _loadParentNameFromList(parentId);
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

  @override
  void dispose() {
    _controller.removeListener(_onPageChanged);
    _controller.dispose();
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

// Le reste de votre code reste exactement inchangé...
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

  @override
  Widget build(BuildContext context) {
    final currentStats = _childrenStats[currentChildIndex]["stats"]!;

    // Suppression du log répétitif
    // print('Affichage nom parent : $firstName $lastName');

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
              IconButton(
                icon: Icon(Icons.notifications_none, color: AppColors.text(context)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationScreen(),
                    ),
                  );
                },
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
                  ),
                if (!isLoadingEleves && eleves.isEmpty)
                  ChildCard(
                    name: "Aucun enfant trouvé",
                    level: "",
                    presence: [false, false, false, false, false, false],
                  ),
                if (!isLoadingEleves && eleves.isNotEmpty)
                  for (final e in eleves)
                    ChildCard(
                      name: (e['first_name'] ?? '') + ' ' + (e['last_name'] ?? ''),
                      level: e['classe'] ?? e['level'] ?? 'N/A',
                      presence: [true, true, false, true, false, false],
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

          // SECTION PROGRESSION
          Text(
            "Progression",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 12),
          Container(
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
                      Text(
                        "Moyenne Mathématique",
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text(context)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "L'élève Océan Ntambwe doit améliorer sa moyenne",
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
                        value: 0.3, // 30%
                        strokeWidth: 5,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary(context)),
                      ),
                    ),
                    Text(
                      "30%",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // SECTION DISCIPLINE
          Text(
            "Discipline",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 12),
          Container(
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
                      Text(
                        "Barème de sanction",
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text(context)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "L'élève Mulsagwa a déjà enregistré 3 absences sur 4 sans justification",
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
                        value: 0.75, // 75%
                        strokeWidth: 5,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary(context)),
                      ),
                    ),
                    Text(
                      "75%",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

