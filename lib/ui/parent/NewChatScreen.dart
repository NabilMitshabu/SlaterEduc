import 'package:flutter/material.dart';
import 'package:slatereduc/services/app_colors.dart';

class ContactModel {
  final String name;
  final String avatarUrl;
  ContactModel({required this.name, required this.avatarUrl});
}

class NewChatScreen extends StatelessWidget {
  final List<ContactModel> contacts = [
    ContactModel(name: "Mr Doeol Mwanakahambo", avatarUrl: "https://randomuser.me/api/portraits/men/31.jpg"),
    ContactModel(name: "Madame Sofia", avatarUrl: "https://randomuser.me/api/portraits/women/44.jpg"),
    ContactModel(name: "Jean Pierre", avatarUrl: "https://randomuser.me/api/portraits/men/32.jpg"),
    ContactModel(name: "Marie Claire", avatarUrl: "https://randomuser.me/api/portraits/women/45.jpg"),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Nouveau chat",
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView.separated(
        itemCount: contacts.length,
        separatorBuilder: (context, index) => const Divider(indent: 70, endIndent: 15, thickness: 0.5),
        itemBuilder: (context, index) {
          final contact = contacts[index];
          return ListTile(
            leading: CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(contact.avatarUrl),
            ),
            title: Text(
              contact.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.text(context),
              ),
            ),
            onTap: () {
              // Ici, on peut démarrer un nouveau chat avec ce contact
              Navigator.pop(context, contact);
            },
          );
        },
      ),
    );
  }
}

