import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:slatereduc/services/app_localizations.dart';
import 'historique_punitions.dart';
import 'resultat.dart';
import 'historique_paiement.dart';
import 'package:slatereduc/services/presence_service.dart';


class ActiviteDetailsScreen extends StatefulWidget {
  final String nom;
  final String classe;
  final String imagePath;
  final String? eleveId; // nouvel identifiant optionnel pour récupérer les présences

  const ActiviteDetailsScreen({
    super.key,
    required this.nom,
    required this.classe,
    required this.imagePath,
    this.eleveId,
  });

  @override
  State<ActiviteDetailsScreen> createState() => _ActiviteDetailsScreenState();
}

class _ActiviteDetailsScreenState extends State<ActiviteDetailsScreen> {
  DateTime today = DateTime.now();
  bool showCalendar = false;

  final PresenceService _presenceService = PresenceService();
  // mapping yyyy-MM-dd -> bool? (true=present, false=absent, null=non pointé)
  final Map<String, bool?> _presenceByDate = {};
  // ensemble des dates (yyyy-MM-dd) où il y a une session
  final Set<String> _sessionDates = {};

  @override
  void initState() {
    super.initState();
    print('DEBUG: ActiviteDetailsScreen.initState eleveId=${widget.eleveId}');
    _loadPresencesForEleve();
  }

  Future<void> _loadPresencesForEleve() async {
    try {
      final eleveId = widget.eleveId;
      if (eleveId == null || eleveId.isEmpty) return;

      print('DEBUG: _loadPresencesForEleve start for eleveId=$eleveId');

      // 1) tenter de récupérer l'inscription pour obtenir id_classe
      String? idClasse;
      try {
        // Utiliser le service pour récupérer les inscriptions (inclut le header d'auth si présent)
        final inscriptions = await _presenceService.getInscriptions();
        print('DEBUG: inscriptions.count=${inscriptions.length}');
        // inscriptions est une List<Map<String, dynamic>> ; rechercher l'entrée correspondante
        final found = inscriptions.firstWhere(
          (it) => (it['id_eleve']?.toString() ?? it['eleve_id']?.toString() ?? it['id']?.toString()) == eleveId,
          orElse: () => <String, dynamic>{},
        );
        print('DEBUG: inscription found=$found');
        if (found.isNotEmpty) {
          idClasse = (found['id_classe'] ?? found['idClasse'] ?? found['classe_id'])?.toString();
          print('DEBUG: derived idClasse=$idClasse');
        }
      } catch (e) {
        print('WARN: failed to fetch inscriptions via service: $e');
      }

      // Récupérer sessions et présences
      final sessions = await _presenceService.getSessionsPresence(idClasse ?? '');
      final presences = await _presenceService.getPresencesForEleve(eleveId);

      print('DEBUG: sessions.count=${sessions.length} presences.count=${presences.length}');
      if (sessions.isNotEmpty) print('DEBUG: sessions sample=${sessions.take(3).toList()}');
      if (presences.isNotEmpty) print('DEBUG: presences sample=${presences.take(3).toList()}');

      // mapping date -> sessions
      final Map<String, List<Map<String, dynamic>>> sessionsByDate = {};
      for (final s in sessions) {
        try {
          final dateRaw = s['date'] ?? s['created_at'];
          if (dateRaw == null) continue;
          final dt = DateTime.parse(dateRaw.toString()).toLocal();
          final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          sessionsByDate.putIfAbsent(key, () => []).add(s);
        } catch (e) {
          // ignore malformed dates
        }
      }
      // remplir l'ensemble des dates où il y a au moins une session
      _sessionDates.clear();
      _sessionDates.addAll(sessionsByDate.keys);

      // Pour le mois courant on peut pré-remplir avec null
      final firstOfMonth = DateTime(today.year, today.month, 1);
      final lastOfMonth = DateTime(today.year, today.month + 1, 0);
      for (var d = firstOfMonth; !d.isAfter(lastOfMonth); d = d.add(const Duration(days: 1))) {
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        _presenceByDate[key] = null;
      }

      // Remplir en parcourant les présences de l'élève — logique similaire à Home.dart
      // Pour chaque présence, tenter de parser son `created_at` (ou `createdAt`) et assigner true/false
      for (final p in presences) {
        try {
          final dateRaw = p['created_at'] ?? p['createdAt'] ?? p['date'] ?? p['updated_at'];
          if (dateRaw == null) continue;
          final dt = DateTime.parse(dateRaw.toString()).toLocal();
          final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          final isPresent = p['is_present'] == true || p['isPresent'] == true || p['present'] == true;
          // Affecter directement (remplace la valeur null pré-remplie)
          _presenceByDate[key] = isPresent;
        } catch (e) {
          // ignore individual parse errors
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      print('ERROR: load presences failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime monday = today.subtract(Duration(days: today.weekday - 1));
    // Générer la semaine (lundi à samedi)
    List<DateTime> weekdays =
    List.generate(6, (i) => monday.add(Duration(days: i)));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bouton retour
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            // Photo + infos de l’élève
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage(widget.imagePath),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.nom,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.classe,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),

            // Alerte si aucun eleveId n'a été passé
            if (widget.eleveId == null || widget.eleveId!.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.yellow.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.yellow.shade700)),
                  child: const Text('Aucun identifiant d\'élève fourni — impossible de charger les présences', style: TextStyle(color: Colors.black87)),
                ),
              ),

            const SizedBox(height: 20),

            // Mois + petit calendrier horizontal
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      showCalendar = !showCalendar;
                    });
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Colors.blue),
                      const SizedBox(width: 5),
                      Text(
                        DateFormat("MMMM yyyy").format(today),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Icon(
                        showCalendar ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Ligne horizontale avec lundi → vendredi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: weekdays.map((day) {
                    bool isSelected = DateFormat("yyyy-MM-dd").format(day) ==
                        DateFormat("yyyy-MM-dd").format(today);
                    final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                    final presence = _presenceByDate.containsKey(key) ? _presenceByDate[key] : null;
                    Color? dotColor;
                    // Suivre la logique Home.dart : colorer selon présence — null = non pointé (orange)
                    if (presence == null) {
                      dotColor = Colors.orange;
                    } else {
                      dotColor = presence ? Colors.blue : Colors.red;
                    }

                    return _buildDayBox(
                      DateFormat("E", "fr_FR").format(day), // ex: Lun, Mar
                      DateFormat("dd").format(day), // ex: 09
                      isSelected,
                      dotColor,
                    );
                   }).toList(),
                 ),

                // Calendrier complet (masqué/affiché)
                if (showCalendar)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: _buildMonthGrid(),
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // Solde de frais
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).translate('fees_balance'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward, color: Colors.blue),
                      tooltip: AppLocalizations.of(context).translate('history_payment'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HistoriquePaiementScreen()),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text("250"),
                    Text("900"),
                  ],
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: 250 / 900,
                  color: Colors.blue,
                  backgroundColor: Colors.grey[300],
                ),
              ],
            ),

            const SizedBox(height: 30),

            // ---- Ligne + Texte "PREMIER DEMESTRE" + Ligne ----
            Row(
              children: [
                const Expanded(child: Divider(thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    AppLocalizations.of(context).translate('first_semester'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const Expanded(child: Divider(thickness: 1)),
              ],
            ),

            const SizedBox(height: 20),

            // Bloc des statistiques
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      Column(
                        children: [
                          Text("87%", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                          Text("POURCENTAGE"),
                        ],
                      ),
                      Column(
                        children: [
                          Text("01", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                          Text("PLACE"),
                        ],
                      ),
                      Column(
                        children: [
                          Text("E", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                          Text("MENTION"),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ResultatCompletScreen()),
                      );
                    },
                    child: Text(AppLocalizations.of(context).translate('result_complete')),
                  )
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Discipline
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context).translate('discipline'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.gavel, color: Colors.blue, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context).translate('penalty_scale'), style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(AppLocalizations.of(context).translateWithArgs('student_discipline_note', {'name': 'NTAMBWE'})),
                          ],
                        ),
                      ),
                      Text("75%", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoriquePunitionsScreen()),
                );
              },
              child: Text(AppLocalizations.of(context).translate('history_activities')),
            ),

            // Debug: indicateur de sessions / présences trouvées
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(horizontal: 0),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sessions trouvées: ${_sessionDates.length}'),
                  Text('Présences connues: ${_presenceByDate.values.where((v) => v != null).length}'),
                ],
              ),
            ),

            // Debug: liste détaillée des sessions et statuts
            if (_sessionDates.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Détails sessions :', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      for (final key in _sessionDates.toList()..sort())
                        Padding(

                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            '$key → ${_presenceByDate.containsKey(key) ? (_presenceByDate[key] == null ? 'Non pointé' : (_presenceByDate[key]! ? 'Présent' : 'Absent')) : 'Aucune info'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- Widget pour afficher un jour (comme sur l'image) ---
  Widget _buildDayBox(String day, String date, bool isSelected, [Color? presenceColor]) {
    // Si une présence est disponible pour ce jour, colorier toute la case selon la présence.
    // Sinon, si le jour est sélectionné, utiliser la couleur par défaut (bleu) comme avant.
    final Color bgColor = presenceColor ?? (isSelected ? Colors.blue : Colors.white);
    final bool isBgColored = presenceColor != null || isSelected;
    final Color txtColor = isBgColored ? Colors.white : Colors.blue;
    final Color borderColor = isBgColored ? bgColor : Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Text(day, style: TextStyle(color: txtColor)),
          const SizedBox(height: 4),
          Text(date, style: TextStyle(color: txtColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          // plus de petit point : la case entière indique le statut
        ],
      ),
    );
  }

  // --- Grille du mois montrant chaque jour et un point de présence si applicable ---
  Widget _buildMonthGrid() {
    final firstOfMonth = DateTime(today.year, today.month, 1);
    final lastOfMonth = DateTime(today.year, today.month + 1, 0);
    final int daysInMonth = lastOfMonth.day;

    // calculer le décalage (weekday retourne 1 pour lundi)
    final int startWeekday = firstOfMonth.weekday; // 1..7 (Mon..Sun)

    // construire une liste de DateTime? pour chaque case (7 colonnes x nombre de semaines)
    final List<DateTime?> cells = [];
    // ajouter des cases vides avant le 1er jour
    for (int i = 1; i < startWeekday; i++) cells.add(null);
    // ajouter tous les jours du mois
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(today.year, today.month, d));
    }
    // ajouter des null pour remplir la dernière semaine
    while (cells.length % 7 != 0) cells.add(null);

    final int weeks = cells.length ~/ 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // en-tête des jours de la semaine
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['Lun','Mar','Mer','Jeu','Ven','Sam','Dim'].map((d) => Expanded(
            child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold))),
          )).toList(),
        ),
        const SizedBox(height: 8),
        // semaines
        for (int w = 0; w < weeks; w++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: List.generate(7, (i) {
                final idx = w * 7 + i;
                final cellDate = cells[idx];
                if (cellDate == null) {
                  return Expanded(child: Container());
                }

                final key = '${cellDate.year}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.day.toString().padLeft(2, '0')}';
                final presence = _presenceByDate.containsKey(key) ? _presenceByDate[key] : null;
                Color? dotColor;
                // Même logique : si pas de présence enregistrée => orange, sinon bleu/rouge
                if (presence == null) {
                  dotColor = Colors.orange;
                } else {
                  dotColor = presence ? Colors.blue : Colors.red;
                }

                final isSelected = DateFormat('yyyy-MM-dd').format(cellDate) == DateFormat('yyyy-MM-dd').format(today);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        today = cellDate;
                      });
                    },
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          // Si la case est sélectionnée, utiliser presence color si disponible
                          decoration: BoxDecoration(
                            color: dotColor, // dotColor est déterminé plus haut (orange/blue/red)
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isSelected ? Colors.black : dotColor),
                            boxShadow: isSelected ? [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))] : null,
                          ),
                          child: Column(
                            children: [
                              Text(DateFormat('d').format(cellDate), style: const TextStyle(color: Colors.white)),
                              const SizedBox(height: 6),
                              // la couleur de la case indique maintenant le statut, pas de petit point
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
