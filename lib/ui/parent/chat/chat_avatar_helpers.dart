import 'package:flutter/material.dart';
import 'package:slatereduc/services/app_colors.dart';

class ChatCorrespondent {
  final String name;
  final String? avatarUrl;
  final String? otherUserId;
  final String? otherPersonnelId;

  ChatCorrespondent({
    required this.name,
    this.avatarUrl,
    this.otherUserId,
    this.otherPersonnelId,
  });
}

Widget buildContactAvatar(BuildContext context, {required String name, String? avatarUrl, double radius = 20}) {
  final url = avatarUrl ?? '';
  final isPlaceholder = url.isEmpty || url.contains('randomuser.me') || url.contains('lego');
  if (!isPlaceholder) {
    return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
  }
  final initial = name.isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : '';
  return CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.secondaryColor(context),
    child: Text(
      initial,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
  );
}

bool isConversationUnread(Map<String, dynamic> conv, {required String? currentUserId}) {
  try {
    final meta = (conv['meta'] as Map?)?.cast<String, dynamic>();
    final seenAtStr = meta?['seen_at']?.toString();
    DateTime? seenAt;
    if (seenAtStr != null && seenAtStr.isNotEmpty) {
      seenAt = DateTime.tryParse(seenAtStr);
    }
    final msgs = conv['messages'] as List?;
    if (msgs == null || msgs.isEmpty) return false;
    for (final raw in msgs) {
      if (raw == null) continue;
      if (raw is! Map) continue;
      final m = raw.cast<String, dynamic>();
      final senderId = (m['sender_id'] ?? m['senderId'])?.toString();
      if (senderId == null || senderId.isEmpty) continue;
      final isFromMe = currentUserId != null && currentUserId.isNotEmpty && senderId == currentUserId;
      if (isFromMe) continue;
      final tsStr = (m['updated_at'] ?? m['created_at'])?.toString();
      final ts = tsStr != null && tsStr.isNotEmpty ? DateTime.tryParse(tsStr) : null;
      if (seenAt == null) {
        // jamais vu -> au moins un message entrant => non-lu
        return true;
      }
      if (ts != null && ts.isAfter(seenAt)) {
        return true;
      }
    }
  } catch (_) {}
  return false;
}

