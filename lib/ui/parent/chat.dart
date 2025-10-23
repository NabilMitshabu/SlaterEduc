import 'package:flutter/material.dart';
import 'NewChatScreen.dart';
import 'chat_screen.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:slatereduc/services/app_localizations.dart';

class MessageModel {
  final String name;
  final String message;
  final String time;
  final bool isUnread;
  final String avatarUrl;

  MessageModel({
    required this.name,
    required this.message,
    required this.time,
    required this.isUnread,
    required this.avatarUrl,
  });
}

class ChatTab extends StatelessWidget {
  final List<MessageModel> messages = [
    MessageModel(
      name: "Mr Doeol Mwanakahambo",
      message:
      "Bonjour Mme Du Corbeau. Je tiens à vous informer que Neville a eu plusieurs difficultés de discipline en classe",
      time: "5 min",
      isUnread: true,
      avatarUrl: "https://randomuser.me/api/portraits/men/31.jpg",
    ),
    MessageModel(
      name: "Madame Sofia",
      message:
      "Bonjour Mme Du Corbeau. Je tiens à vous informer que Neville a eu plusieurs difficultés de discipline en classe cette semaine. Une rencontre est souhaitable afin d’en discuter.",
      time: "10 min",
      isUnread: false,
      avatarUrl: "https://randomuser.me/api/portraits/women/44.jpg",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        //backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true, // titre centré
        title: Text(
          loc.translate('messages'),
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: AppColors.text(context)),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: messages.length,
        separatorBuilder: (context, index) => const Divider(
          indent: 70,
          endIndent: 15,
          thickness: 0.5,
        ),
        itemBuilder: (context, index) {
          final msg = messages[index];
          return ListTile(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(msg.avatarUrl),
                ),
                if (msg.isUnread)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent[400],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              msg.name,
              style: TextStyle(
                fontWeight: msg.isUnread ? FontWeight.bold : FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              msg.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: msg.isUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: Text(
              msg.time,
              style: TextStyle(
                fontSize: 12,
                color: msg.isUnread ? Colors.blue : Colors.grey,
                fontWeight: msg.isUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    name: msg.name,
                    avatarUrl: msg.avatarUrl,
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final contact = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewChatScreen(),
            ),
          );
          if (contact != null) {
            // Ici, vous pouvez démarrer un nouveau chat avec le contact sélectionné
            final message = loc.translate('new_chat_with').replaceAll('{name}', contact.name);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        },
        backgroundColor: AppColors.secondaryColor(context),
        child: Icon(Icons.message, color: AppColors.onPrimary(context)),
      ),
    );
  }
}
