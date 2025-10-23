import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:slatereduc/ui/parent/chat.dart';
import 'package:slatereduc/ui/parent/activity.dart';
import 'package:slatereduc/ui/parent/profil.dart';
import 'package:slatereduc/ui/parent/widget.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'NotificationScreen.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _controller = PageController();
  int _selectedIndex = 0;
  int _currentChildIndex = 0;
  bool _isLoadingAvatar = true;

  // Liste des avatars proposés
  final List<String> _avatarUrls = [
    'https://static.vecteezy.com/system/resources/previews/027/951/137/non_2x/stylish-spectacles-guy-3d-avatar-character-illustrations-png.png',
    'https://img.freepik.com/psd-premium/avatar-3d-lunettes-personnage-pull_1155620-2211.jpg?semt=ais_hybrid&w=740&q=80',
    'https://img.freepik.com/premium-photo/memoji-african-american-man-white-background-emoji_826801-6856.jpg',
    'https://img.freepik.com/photos-premium/memoji-homme-heureux-fond-blanc-emoji_826801-6832.jpg',
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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onPageChanged);
    _loadAvatar();
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
      username: '',
      avatarUrl: _selectedAvatarUrl,
      onAvatarTap: _showAvatarSelection,
    ),
    ChatTab(),
    ActiviteTab(),
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
  final String avatarUrl;
  final VoidCallback onAvatarTap;

  const _HomeTab({required this.controller, required this.currentChildIndex, required this.username, required this.avatarUrl, required this.onAvatarTap});

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
                  Text(
                    username,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text(context)),
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
                ChildCard(
                  name: "Ocean Ntambwe",
                  level: "5ème Primaire",
                  presence: [true, true, false, true, false, false],
                ),
                ChildCard(
                  name: "Luna Kabila",
                  level: "3ème Primaire",
                  presence: [true, true, true, true, true, false],
                ),
                ChildCard(
                  name: "Eliot Mvemba",
                  level: "2ème Primaire",
                  presence: [true, false, true, true, false, false],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Center(
            child: SmoothPageIndicator(
              controller: controller,
              count: 3, // nombre d'enfants
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
