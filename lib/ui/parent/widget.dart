import 'package:flutter/material.dart';


// ====================
// WIDGETS RÉUTILISABLES
// ====================

class _PresenceItem extends StatelessWidget {
  final String label;
  final bool present;
  const _PresenceItem({required this.label, required this.present});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Icon(
          present ? Icons.check_circle : Icons.cancel,
          color: present ? Colors.blue : Colors.red,
        ),
      ],
    );
  }
}

class StatItem extends StatelessWidget {
  final String value;
  final String label;

  const StatItem({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2.0,
            ),
          ),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _MessageItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  const _MessageItem({required this.icon, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(content),
      ),
    );
  }
}

class ChildCard extends StatelessWidget {
  final String name;
  final String level;
  final List<bool> presence;

  const ChildCard({
    required this.name,
    required this.level,
    required this.presence,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundImage: AssetImage("assets/images/ocean.png"),
              ),
              title: Text(name),
              subtitle: Text(level),
              trailing: const Icon(Icons.arrow_forward),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Présence cette semaine",
                  style: TextStyle(fontWeight: FontWeight.normal),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  presence.length,
                      (index) => _PresenceItem(
                    label: ["L", "M", "M", "J", "V", "S"][index],
                    present: presence[index],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}