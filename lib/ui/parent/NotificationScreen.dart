import 'package:flutter/material.dart';
import 'package:slatereduc/services/app_colors.dart';

class NotificationScreen extends StatelessWidget {
  final List<Map<String, String>> notifications = [
    {
      "title": "Nouvelle note disponible",
      "subtitle": "La moyenne de votre enfant a été mise à jour.",
      "date": "08/10/2025"
    },
    {
      "title": "Absence enregistrée",
      "subtitle": "Océan Ntambwe a été absent le 07/10/2025.",
      "date": "07/10/2025"
    },
    {
      "title": "Message de l’enseignant",
      "subtitle": "Veuillez consulter le nouveau message dans le chat.",
      "date": "06/10/2025"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Notifications",
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView.separated(
        itemCount: notifications.length,
        separatorBuilder: (context, index) => Divider(indent: 70, endIndent: 15, thickness: 0.5),
        itemBuilder: (context, index) {
          final notif = notifications[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary(context).withOpacity(0.1),
              child: Icon(Icons.notifications, color: AppColors.primary(context)),
            ),
            title: Text(
              notif["title"]!,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            subtitle: Text(
              notif["subtitle"]!,
              style: TextStyle(color: AppColors.text(context).withOpacity(0.7)),
            ),
            trailing: Text(
              notif["date"]!,
              style: TextStyle(fontSize: 12, color: AppColors.text(context).withOpacity(0.5)),
            ),
          );
        },
      ),
    );
  }
}

