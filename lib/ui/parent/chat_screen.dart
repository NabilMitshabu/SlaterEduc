import 'package:flutter/material.dart';
import 'package:slatereduc/services/app_colors.dart';

// Widget du chat fidèle au modèle fourni
class ChatScreen extends StatelessWidget {
  final String name;
  final String avatarUrl;

  const ChatScreen({
    Key? key,
    required this.name,
    required this.avatarUrl,
  }) : super(key: key);

  // Messages d'exemple pour la démo
  List<Map<String, dynamic>> get messages => [
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
  Widget build(BuildContext context) {
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
                      name,
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
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background(context), // texte dynamique
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: const Text(
                  "Aujourd'hui",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  if (msg['type'] == 'text') {
                    return Align(
                      alignment: msg['isMe']
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        constraints: const BoxConstraints(maxWidth: 230),
                        decoration: BoxDecoration(
                          color: msg['isMe']
                              ? const Color(0xFF4B9EFF)
                              : const Color(0xFFE7ECF3),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(msg['isMe'] ? 18 : 0),
                            bottomRight: Radius.circular(msg['isMe'] ? 0 : 18),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: msg['isMe']
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
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
                                color: msg['isMe']
                                    ? Colors.white70
                                    : Colors.black38,
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
                      alignment: msg['isMe']
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
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
                            const Icon(Icons.graphic_eq,
                                color: Colors.black38, size: 28),
                            const SizedBox(width: 6),
                            Text(
                              msg['duration'],
                              style: const TextStyle(
                                  color: Colors.black87, fontSize: 14),
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
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.07),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline, color: Color(0xFF4B9EFF)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Messages...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.mic, color: Color(0xFF4B9EFF)),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF4B9EFF)),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}