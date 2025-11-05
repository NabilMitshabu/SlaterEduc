import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import 'package:slatereduc/services/app_colors.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isLogin = true;
  String? _errorMessage;

  late final AnimationController _iconController;
  late final Animation<double> _iconAnimation;

  Timer? _iconTimer;
  int _iconIndex = 0;

  final List<IconData> _scenarioIcons = [
    Icons.school,
    Icons.menu_book,
    Icons.chat_bubble_outline,
    Icons.account_circle,
  ];

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _iconAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      _iconTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
        if (mounted) {
          setState(() {
            _iconIndex = (_iconIndex + 1) % _scenarioIcons.length;
          });
        }
      });
    });
  }

  Future<void> _handleLogin() async {
    if (nameController.text.isEmpty || passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Veuillez remplir tous les champs');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authService.login(
        nameController.text.trim(),
        passwordController.text,
      );
      if (mounted) {
        // On passe la réponse complète au route /home pour qu'il puisse récupérer l'ID du parent
        GoRouter.of(context).go('/home', extra: response);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgot() async {
    final raw = nameController.text.trim();
    if (raw.isEmpty) {
      setState(() => _errorMessage = 'Veuillez entrer votre numéro de téléphone');
      return;
    }

    final phone = raw.replaceAll(RegExp(r'[^\d+]'), '');
    final phonePattern = RegExp(r'^\+?\d{8,15}$');
    if (!phonePattern.hasMatch(phone)) {
      setState(() => _errorMessage = 'Numéro de téléphone invalide (ex: +243...)');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.forgotPassword(phone);
      setState(() {
        _errorMessage = "Un message de réinitialisation a été envoyé.";
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _iconController.dispose();
    _iconTimer?.cancel();
    nameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // léger fond derrière l'icône basé sur la couleur primaire
                    color: AppColors.alpha(AppColors.primary(context), 0.06),
                  ),
                  padding: const EdgeInsets.all(28),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: ScaleTransition(
                      key: ValueKey<int>(_iconIndex),
                      scale: _iconAnimation,
                      child: Builder(
                          builder: (context) {
                            // Couleurs thématiques pour la "scène" d'icônes
                            final beginColor = AppColors.scenarioColor((_iconIndex - 1 + _scenarioIcons.length) % _scenarioIcons.length);
                            final endColor = AppColors.scenarioColor(_iconIndex);

                            return TweenAnimationBuilder<Color?>(
                              tween: ColorTween(begin: beginColor, end: endColor),
                              duration: const Duration(milliseconds: 600),
                              builder: (context, color, child) {
                                return Icon(
                                  _scenarioIcons[_iconIndex],
                                  size: 82,
                                  color: color ?? endColor,
                                );
                              },
                            );

                          }
                      ),
                    ),
                  ),
                ),
              ),

              Text(
                _isLogin
                    ? "Connectez-vous pour garder un œil sur vos enfants"
                    : "Mot de passe oublié",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin
                    ? "Suivez résultats, paiements et activités de vos enfants en toute simplicité."
                    : "Entrez votre numéro de téléphone pour réinitialiser votre mot de passe.",
                style: TextStyle(color: AppColors.alpha(AppColors.text(context), 0.7), fontSize: 14),
              ),
              const SizedBox(height: 40),

              // Onglets Login | Forgot
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.alpha(AppColors.text(context), 0.04),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isLogin = true;
                          _errorMessage = null;
                        }),
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _isLogin ? AppColors.primary(context) : Colors.transparent,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(
                            "Se connecter",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isLogin ? AppColors.background(context) : AppColors.alpha(AppColors.text(context), 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isLogin = false;
                          _errorMessage = null;
                        }),
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: !_isLogin ? AppColors.primary(context) : Colors.transparent,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(
                            "Réinitialiser",
                            style: TextStyle(
                              color: !_isLogin ? AppColors.background(context) : AppColors.alpha(AppColors.text(context), 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: AppColors.errorColor(context)),
                  ),
                ),

              // Champ username ou téléphone
              Container(
                decoration: BoxDecoration(
                  color: AppColors.alpha(AppColors.text(context), 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: nameController,
                  keyboardType: _isLogin ? TextInputType.text : TextInputType.phone,
                  style: TextStyle(color: AppColors.text(context)),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      _isLogin ? Icons.person_outline : Icons.phone_outlined,
                      color: AppColors.primary(context),
                    ),
                    hintText: _isLogin ? "Nom d'utilisateur" : "Numéro de téléphone",
                    hintStyle: TextStyle(color: AppColors.alpha(AppColors.text(context), 0.6)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (_isLogin)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.alpha(AppColors.text(context), 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: AppColors.text(context)),
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: AppColors.primary(context),
                      ),
                      hintText: "Mot de passe",
                      hintStyle: TextStyle(color: AppColors.alpha(AppColors.text(context), 0.6)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.alpha(AppColors.text(context), 0.6),
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                    foregroundColor: AppColors.background(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isLoading
                      ? null
                      : _isLogin
                      ? _handleLogin
                      : _handleForgot,
                  child: _isLoading
                      ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                      : Text(
                    _isLogin ? "Se connecter" : "Réinitialiser",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}