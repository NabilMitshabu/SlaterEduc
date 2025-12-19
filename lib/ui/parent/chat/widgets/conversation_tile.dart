import 'package:flutter/material.dart';
import 'package:slatereduc/services/app_colors.dart';
import '../chat_avatar_helpers.dart';

/// Tile uniforme pour une conversation (liste des chats).
///
/// Contrat:
/// - [title]: nom du correspondant (nom + postnom déjà résolus en amont).
/// - [subtitle]: contenu du dernier message.
/// - [timeLabel]: heure/date formatée.
/// - [unread]: affiche un point rouge si non lu.
class ConversationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String timeLabel;
  final bool unread;
  final String? avatarUrl;
  final String? classe;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ConversationTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.unread,
    this.avatarUrl,
    this.classe,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: buildContactAvatar(
        context,
        name: title,
        avatarUrl: avatarUrl,
        radius: 28,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.text(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                timeLabel,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          if (classe != null && classe!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                classe!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[700]),
        ),
      ),
      trailing: unread
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

