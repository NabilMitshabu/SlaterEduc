import 'dart:async';

import 'package:flutter/material.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:slatereduc/services/app_localizations.dart';
import 'package:slatereduc/services/api/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _error;

  Timer? _autoTimer;
  bool _refreshing = false;

  String _formatShortDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final s = raw.toString();
      if (s.isEmpty) return '';
      DateTime? d = DateTime.tryParse(s);
      if (d == null && s.length >= 19) {
        // tenter YYYY-MM-DDTHH:MM:SS.sssZ -> garder 19 premiers caractères si nécessaire
        d = DateTime.tryParse(s.substring(0, 19));
      }
      if (d == null) return s; // fallback: afficher tel quel
      // format court: dd/MM HH:mm
      final dd = d.day.toString().padLeft(2, '0');
      final mm = d.month.toString().padLeft(2, '0');
      final hh = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      return '$dd/$mm $hh:$min';
    } catch (_) {
      return raw.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      if (_refreshing) return;
      _refreshing = true;
      try {
        await _load(silent: true);
      } catch (_) {} finally {
        _refreshing = false;
      }
    });
  }

  void _stopAutoRefresh() {
    _autoTimer?.cancel();
    _autoTimer = null;
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      // Charger les notifications entrantes pour la famille (parent + enfants)
      final list = await _notificationService.getIncomingNotificationsForCurrentUser(
        onlyMessages: false,
        preferServer: true, // préférer serveur pour récupérer parent + enfants via user_id
      );
      setState(() {
        _notifications = list;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _notifications = [];
      });
    } finally {
      if (!silent) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> notif) async {
    final id = notif['id']?.toString();
    if (id == null || id.isEmpty) return;
    final ok = await _notificationService.markAsRead(id);
    if (ok) {
      setState(() {
        notif['is_read'] = true;
      });
    }
  }

  Map<String, dynamic> _metaFor(Map<String, dynamic> notif, BuildContext context) {
    final type = (notif['notif_type'] ?? '').toString().toUpperCase();
    Color color = AppColors.primary(context);
    IconData icon = Icons.notifications;
    String label = type.isEmpty ? 'INFO' : type;
    switch (type) {
      case 'PUNITION':
        color = Colors.redAccent;
        icon = Icons.rule;
        label = 'PUNITION';
        break;
      case 'EVALUATION':
        color = Colors.blueAccent;
        icon = Icons.school;
        label = 'EVALUATION';
        break;
      case 'MESSAGE':
        color = Colors.green;
        icon = Icons.message;
        label = 'MESSAGE';
        break;
      case 'ABSENCE':
      case 'PRESENCE':
        color = Colors.orangeAccent;
        icon = Icons.event_busy;
        label = type;
        break;
      default:
        color = AppColors.primary(context);
        icon = Icons.notifications;
        label = type.isEmpty ? 'INFO' : type;
    }
    return {'color': color, 'icon': icon, 'label': label};
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.onPrimary(context),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          loc.translate('notifications'),
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () async {
              final ok = await _notificationService.markAllAsRead();
              if (ok) {
                setState(() {
                  for (final n in _notifications) {
                    n['is_read'] = true;
                  }
                });
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: TextStyle(color: AppColors.text(context)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _notifications.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    final isRead = () {
                      final v = notif['is_read'];
                      if (v == null) return false;
                      if (v is bool) return v;
                      final s = v.toString().toLowerCase();
                      return s == 'true' || s == '1';
                    }();
                    final title = (notif['title'] ?? notif['notif_type'] ?? 'Notification').toString();
                    final subtitle = (notif['content'] ?? notif['message'] ?? '').toString();
                    final dateLabel = _formatShortDate(notif['created_at'] ?? notif['date']);
                    final meta = _metaFor(notif, context);
                    final Color metaColor = meta['color'] as Color;
                    final IconData metaIcon = meta['icon'] as IconData;
                    final String metaLabel = meta['label'] as String;

                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        await _markAsRead(notif);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: isRead
                              ? AppColors.alpha(AppColors.text(context), 0.035)
                              : AppColors.alpha(metaColor, 0.055),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.alpha(Colors.black, 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(color: AppColors.alpha(metaColor, 0.18), width: 0.5),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Bande colorée
                            Container(
                              width: 3,
                              height: 48,
                              decoration: BoxDecoration(
                                color: metaColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Icône
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.alpha(metaColor, 0.12),
                              child: Icon(metaIcon, color: metaColor, size: 18),
                            ),
                            const SizedBox(width: 10),
                            // Contenu
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                            color: AppColors.text(context),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (!isRead) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // Chip type
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.alpha(metaColor, 0.11),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      metaLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: metaColor,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      height: 1.2,
                                      fontSize: 12,
                                      color: AppColors.alpha(AppColors.text(context), 0.75),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        dateLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.alpha(AppColors.text(context), 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )),
    );
  }
}
