import 'package:flutter/material.dart';
import 'package:slatereduc/services/app_colors.dart';
import 'package:slatereduc/services/app_localizations.dart';
import 'package:slatereduc/services/api/evaluation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slatereduc/services/api/school_service.dart';
import 'dart:async';
import 'dart:convert';

class ResultatCompletScreen extends StatefulWidget {
  const ResultatCompletScreen({super.key});

  @override
  State<ResultatCompletScreen> createState() => _ResultatCompletScreenState();
}

class _ResultatCompletScreenState extends State<ResultatCompletScreen> {
  int selectedIndex = 0;

  final Map<String, List<Map<String, dynamic>>> resultatsParPeriode = {
  // fallback minimal (vide) — l'affichage principal consommera `_dynamicResultatsParPeriode` rempli depuis les APIs
  'Chargement': [],
};

  // données dynamiques
  final EvaluationService _evaluationService = EvaluationService();
  final SchoolService _schoolService = SchoolService();
  bool _isLoadingData = true;
  String? _loadError;
  List<dynamic> _periodes = [];
  List<dynamic> _courses = [];
  List<dynamic> _evaluationTypes = [];
  List<dynamic> _evaluations = [];
  List<dynamic> _evaluationEleves = [];
  List<dynamic> _coursProfPeriods = [];
  List<dynamic> _coursProfs = [];
  String? _currentStudentId;
  String? _studentClasseId;
  Map<String, List<Map<String, dynamic>>> _dynamicResultatsParPeriode = {};
  // Enable debug logs to inspect matching between evaluations and evaluation_eleves
  // Passe à `true` pour voir les sorties dans la console (utile pour debug local).
  final bool _debugLog = true;

  // Format une date ISO/texte pour ne garder que jour/mois/année (jj/MM/aaaa).
  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final s = raw is String ? raw : raw.toString();
      if (s.isEmpty) return '';
      // Essayer un parsing standard
      DateTime? d = DateTime.tryParse(s);
      if (d == null) {
        // Quelques backoffs : prendre les 10 premiers caractères s'il s'agit d'un ISO long
        if (s.length >= 10) {
          final maybeDate = s.substring(0, 10);
          d = DateTime.tryParse(maybeDate);
        }
      }
      if (d == null) {
        // tenter de récupérer jj-mm-aaaa ou autre format simple avec séparateurs
        final sep = s.contains('/') ? '/' : (s.contains('-') ? '-' : null);
        if (sep != null) {
          final parts = s.split(sep).map((e) => e.trim()).toList();
          if (parts.length >= 3) {
            // essayer d'identifier l'ordre (yyyy-mm-dd ou dd-mm-yyyy)
            if (parts[0].length == 4) {
              // yyyy/mm/dd
              final y = int.tryParse(parts[0]);
              final m = int.tryParse(parts[1]);
              final day = int.tryParse(parts[2]);
              if (y != null && m != null && day != null) d = DateTime(y, m, day);
            } else {
              // dd/mm/yyyy
              final day = int.tryParse(parts[0]);
              final m = int.tryParse(parts[1]);
              final y = int.tryParse(parts[2]);
              if (y != null && m != null && day != null) d = DateTime(y, m, day);
            }
          }
        }
      }
      if (d == null) return '';
      final dd = d.day.toString().padLeft(2, '0');
      final mm = d.month.toString().padLeft(2, '0');
      final yyyy = d.year.toString();
      return '$dd/$mm/$yyyy';
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingData = true;
      _loadError = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      // try several common keys for student id (from activity selection)
      _currentStudentId = prefs.getString('current_student_id')
          ?? prefs.getString('currentStudentId')
          ?? prefs.getString('id_eleve')
          ?? prefs.getString('idEleve')
          ?? prefs.getString('selected_student_id')
          ?? prefs.getString('selectedStudentId')
          ?? prefs.getString('selected_student');
      // also accept a stored student object
      if ((_currentStudentId == null || _currentStudentId!.isEmpty) && prefs.containsKey('student')) {
        try {
          final raw = prefs.getString('student');
          if (raw != null && raw.isNotEmpty) {
            final parsed = json.decode(raw);
            if (parsed is Map && parsed.containsKey('id')) _currentStudentId = parsed['id']?.toString();
          }
        } catch (_) {}
      }

      // fetch lists
      final periodes = await _evaluationService.fetchPeriodes();
      final courses = await _evaluationService.fetchCourses();
      final types = await _evaluationService.fetchEvaluationTypes();
      final evaluations = await _evaluationService.fetchEvaluations();
      final coursProfPeriods = await _evaluationService.fetchCoursProfPeriods();
      final coursProfs = await _evaluationService.fetchCoursProfs();
      final evalEleves = await _evaluationService.fetchEvaluationEleves();

      _periodes = periodes;
      _courses = courses;
      _evaluationTypes = types;
      _evaluations = evaluations;
      _evaluationEleves = evalEleves;
      _coursProfPeriods = coursProfPeriods;
      _coursProfs = coursProfs;

      // Si aucune préférence n'a fourni l'ID de l'élève, essayer un fallback depuis evaluationEleves
      if ((_currentStudentId == null || _currentStudentId!.isEmpty) && _evaluationEleves.isNotEmpty) {
        try {
          final first = _evaluationEleves.first;
          final cand = (first['id_eleve'] ?? first['idEleve'] ?? first['student_id'] ?? first['eleve_id'] ?? first['id'])?.toString();
          if (cand != null && cand.isNotEmpty) _currentStudentId = cand;
        } catch (_) {}
      }

      // also try fetch inscriptions to determine student's class
      List<dynamic> inscriptions = [];
      try {
        inscriptions = await _schoolService.fetchInscriptions();
      } catch (_) {}

      // determine current student's class id if possible
      String? studentClasseId;
      if (_currentStudentId != null) {
        try {
          for (final ins in inscriptions) {
            final idEleve = (ins['id_eleve'] ?? ins['idEleve'] ?? ins['id'])?.toString() ?? '';
            if (idEleve == _currentStudentId) {
              studentClasseId = (ins['id_classe'] ?? ins['idClasse'] ?? ins['id_classe'])?.toString() ?? '';
              break;
            }
          }
        } catch (_) {}
      }

      // pass studentClasseId into dynamic builder via a private field
      _currentStudentId = _currentStudentId; // keep existing
      // store class id in a temp map
      // we'll use studentClasseId local in _buildDynamicResultats via field
      _studentClasseId = studentClasseId;

      // build dynamic map
      _buildDynamicResultats();
    } catch (e) {
      _loadError = e.toString();
    } finally {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  void _buildDynamicResultats() {
    _dynamicResultatsParPeriode = {};

    // recherches auxiliaires
    final coursesById = {for (var c in _courses) ((c['id'] ?? c['id_cours'] ?? c['idCours'])?.toString() ?? ''): c};
    // construire les intervalles de périodes pour inférer la période à partir de la date d'évaluation
    final Map<String, List<DateTime?>> periodeDateRanges = {};
    for (final p in _periodes) {
      try {
        final pid = (p['id'] ?? '')?.toString() ?? '';
        final startStr = (p['startDate'] ?? p['start_date'] ?? p['created_at'])?.toString();
        final endStr = (p['endDate'] ?? p['end_date'] ?? p['updated_at'])?.toString();
        final start = startStr != null ? DateTime.tryParse(startStr) : null;
        final end = endStr != null ? DateTime.tryParse(endStr) : null;
        periodeDateRanges[pid] = [start, end];
      } catch (_) {}
    }
    // counts loaded (no verbose debug prints in production)
    // build mapping periodeId -> set of courseIds
    final Map<String, Set<String>> periodeToCourseIds = {};
    // build mapping coursProfId -> coursId so we can resolve relations that reference idCoursProf
    final Map<String, String> coursProfIdToCoursId = {};
    for (final cp in _coursProfs) {
      try {
        final cpId = (cp['id'] ?? cp['idCoursProf'] ?? cp['id_cours_prof'] ?? '')?.toString() ?? '';
        final cid = (cp['idCours'] ?? cp['id_cours'] ?? cp['idCours'])?.toString() ?? '';
        if (cpId.isNotEmpty && cid.isNotEmpty) coursProfIdToCoursId[cpId] = cid;
      } catch (_) {}
    }

    // index coursProfPeriods by id for quick lookup
    final Map<String, Map<String, dynamic>> coursProfPeriodById = {};
    for (final rel in _coursProfPeriods) {
      try {
        final relId = (rel['id'] ?? rel['idCoursProfPeriod'] ?? '')?.toString() ?? '';
        if (relId.isNotEmpty) coursProfPeriodById[relId] = rel as Map<String, dynamic>;
      } catch (_) {}
    }
    // index sizes prepared

    for (final rel in _coursProfPeriods) {
      try {
        final pid = (rel['id_periode'] ?? rel['idPeriode'] ?? rel['periode_id'] ?? rel['id_periode'])?.toString() ?? '';
        final courseProfId = (rel['idCoursProf'] ?? rel['id_cours_prof'] ?? rel['id_coursprof'] ?? rel['idCoursProf'])?.toString() ?? '';
        // sometimes relation might point to cours_prof table; try to extract course id from relation record if present
        final courseId = (rel['id_cours'] ?? rel['idCours'] ?? rel['id_cours_ref'] ?? rel['cours_id'])?.toString() ?? '';
        // if courseId empty but we have a courseProfId, try to resolve through coursProfs mapping
        String cid = courseId.isNotEmpty ? courseId : courseProfId;
        if (cid.isNotEmpty && coursProfIdToCoursId.containsKey(cid)) {
          cid = coursProfIdToCoursId[cid]!;
        }
        if (pid.isEmpty || cid.isEmpty) continue;
        periodeToCourseIds.putIfAbsent(pid, () => <String>{}).add(cid);
      } catch (_) {}
    }

    // build mapping classId -> set of courseIds from coursProfs
    final Map<String, Set<String>> classToCourseIds = {};
    for (final cp in _coursProfs) {
      try {
        final classId = (cp['idClasse'] ?? cp['id_classe'] ?? cp['idClasse'])?.toString() ?? '';
        final courseId = (cp['idCours'] ?? cp['id_cours'] ?? cp['id_cours'])?.toString() ?? '';
        if (classId.isEmpty || courseId.isEmpty) continue;
        classToCourseIds.putIfAbsent(classId, () => <String>{}).add(courseId);
      } catch (_) {}
    }

    // decide which periods to iterate: real periodes or a single 'ALL' period when ignoring filter
    final List<dynamic> periodsToIterate = _periodes;

    for (final p in periodsToIterate) {
      final pid = (p['id'] ?? '').toString();
      final title = (p['title'] ?? p['name'] ?? p['label'] ?? (pid == 'ALL' ? 'Toutes les périodes' : 'Période')).toString();

      final Map<String, Map<String, dynamic>> coursesAgg = {};

      // Determine allowed courses for this period, optionally filtered by student's class
      Set<String> allowedCourseIds = {};
      if (pid == 'ALL') {
        // In ignore mode, start with all courses (class filtering below will still apply)
        allowedCourseIds = coursesById.keys.toSet();
      } else if (periodeToCourseIds.isNotEmpty) {
        allowedCourseIds = Set<String>.from(periodeToCourseIds[pid] ?? <String>{});
      } else {
        // if no periode->course mapping, default to all courses
        allowedCourseIds = coursesById.keys.toSet();
      }

      // If we have class->course mapping and a student class, intersect to only keep class courses
      if (_studentClasseId != null && _studentClasseId!.isNotEmpty) {
        final classCourses = classToCourseIds[_studentClasseId!] ?? <String>{};
        if (classCourses.isNotEmpty) {
          allowedCourseIds = allowedCourseIds.intersection(classCourses);
        }
      }

      // initialize coursesAgg with allowed courses so we show courses even without evaluations
      for (final cid in allowedCourseIds) {
        final course = coursesById[cid];
        final courseName = course != null ? (course['title'] ?? course['name'] ?? '').toString() : 'Cours ${cid}';
        coursesAgg[cid] = {'cours': courseName, 'evaluations': <Map<String, dynamic>>[], 'pointsAgg': <double>[]};
      }

      // find evaluations for this periode (filter by periode->course relation if available)
      for (final ev in _evaluations) {
        try {
          // Resolve evaluation's period id (try direct fields first)
          String evPeriodeId = (ev['id_periode'] ?? ev['idPeriode'] ?? ev['periode_id'] ?? ev['idPeriode'])?.toString() ?? '';

          // Resolve course id: try direct fields, otherwise follow idCoursProfPeriod -> coursProfPeriod -> coursProf -> cours
          String courseId = (ev['id_cours'] ?? ev['idCours'] ?? ev['course_id'] ?? ev['id_course'])?.toString() ?? '';

          if (courseId.isEmpty) {
            final linkId = (ev['idCoursProfPeriod'] ?? ev['id_cours_prof_period'] ?? ev['idCoursProfPeriod'] ?? ev['id_coursprofperiod'])?.toString() ?? '';
            if (linkId.isNotEmpty && coursProfPeriodById.containsKey(linkId)) {
              final rel = coursProfPeriodById[linkId]!;
              // rel may directly contain a course id
              courseId = (rel['id_cours'] ?? rel['idCours'] ?? rel['course_id'])?.toString() ?? '';
              // or rel may reference a coursProf entry
              if (courseId.isEmpty) {
                final cpId = (rel['idCoursProf'] ?? rel['id_cours_prof'] ?? rel['id_coursprof'] ?? rel['idCoursProf'])?.toString() ?? '';
                if (cpId.isNotEmpty && coursProfIdToCoursId.containsKey(cpId)) {
                  courseId = coursProfIdToCoursId[cpId]!;
                }
              }
              // if evaluation didn't include period id directly, try to read it from the relation
              if (evPeriodeId.isEmpty) {
                evPeriodeId = (rel['id_periode'] ?? rel['idPeriode'] ?? rel['periode_id'])?.toString() ?? '';
              }
            }
          } else {
            // if we resolved courseId but period not set, attempt to use link if present
            if (evPeriodeId.isEmpty) {
              final linkId = (ev['idCoursProfPeriod'] ?? ev['id_cours_prof_period'] ?? ev['idCoursProfPeriod'] ?? ev['id_coursprofperiod'])?.toString() ?? '';
              if (linkId.isNotEmpty && coursProfPeriodById.containsKey(linkId)) {
                final rel = coursProfPeriodById[linkId]!;
                evPeriodeId = (rel['id_periode'] ?? rel['idPeriode'] ?? rel['periode_id'])?.toString() ?? '';
              }
            }
          }

          // If evaluation doesn't include a periode id, try to infer it from the evaluation date using periode start/end ranges
          if (evPeriodeId.isEmpty) {
            final evDateStr = (ev['created_at'] ?? ev['date'] ?? ev['updated_at'])?.toString() ?? '';
            final evDate = evDateStr.isNotEmpty ? DateTime.tryParse(evDateStr) : null;
            if (evDate != null) {
              for (final entry in periodeDateRanges.entries) {
                final start = entry.value[0];
                final end = entry.value[1];
                if (start != null && end != null) {
                  if (!evDate.isBefore(start) && !evDate.isAfter(end)) {
                    evPeriodeId = entry.key;
                    break;
                  }
                }
              }
            }
          }
          // If evaluation has an explicit periode id and it doesn't match current periode, skip it.
          if (pid != 'ALL' && evPeriodeId.isNotEmpty && evPeriodeId != pid) {
            continue;
          }

          // Resolve final course id (in case courseId is a coursProf id or a coursProfPeriod id)
          String resolvedCourseId = courseId;
          if (resolvedCourseId.isEmpty) {
            // nothing to resolve
          } else if (coursProfIdToCoursId.containsKey(resolvedCourseId)) {
            resolvedCourseId = coursProfIdToCoursId[resolvedCourseId]!;
            // mapped coursProfId -> courseId
          } else if (coursProfPeriodById.containsKey(resolvedCourseId)) {
            final rel2 = coursProfPeriodById[resolvedCourseId]!;
            final relCourse = (rel2['id_cours'] ?? rel2['idCours'] ?? rel2['course_id'])?.toString() ?? '';
            if (relCourse.isNotEmpty) resolvedCourseId = relCourse;
            else {
              final relCp = (rel2['idCoursProf'] ?? rel2['id_cours_prof'] ?? rel2['id_coursprof'])?.toString() ?? '';
              if (relCp.isNotEmpty && coursProfIdToCoursId.containsKey(relCp)) resolvedCourseId = coursProfIdToCoursId[relCp]!;
            }
            // mapped coursProfPeriod -> courseId
          }

          if (resolvedCourseId.isEmpty) {
            // cannot resolve course for this evaluation -> skip
            continue;
          }
          // skip evaluations whose course is not in allowedCourseIds (compare with resolvedCourseId)
          if (!allowedCourseIds.contains(resolvedCourseId)) {
            // If course not in allowed set, add it as fallback so evaluations are visible (tolerate incomplete relations)
            allowedCourseIds.add(resolvedCourseId);
            final fallbackCourse = coursesById[resolvedCourseId];
            final fallbackName = fallbackCourse != null ? (fallbackCourse['title'] ?? fallbackCourse['name'] ?? '').toString() : 'Cours ${resolvedCourseId}';
            coursesAgg.putIfAbsent(resolvedCourseId, () => {'cours': fallbackName, 'evaluations': <Map<String, dynamic>>[], 'pointsAgg': <double>[]});
          }

          final course = coursesById[resolvedCourseId];
          final courseName = course != null ? (course['title'] ?? course['name'] ?? '').toString() : 'Cours ${resolvedCourseId}';

          // compute student points for this evaluation
          // Normalise l'ID d'évaluation (plusieurs noms possibles dans l'API)
          final evId = (ev['id'] ?? ev['idEvaluation'] ?? ev['id_evaluation'] ?? ev['evaluation_id'] ?? ev['idEval'])?.toString() ?? '';
          final List<dynamic> matches = _evaluationEleves.where((ee) {
            try {
              final idEval = (ee['id_evaluation'] ?? ee['idEvaluation'] ?? ee['evaluation_id'] ?? ee['id'])?.toString() ?? '';
              final idEleve = (ee['id_eleve'] ?? ee['idEleve'] ?? ee['student_id'] ?? ee['id'])?.toString() ?? '';
              return idEval.isNotEmpty && idEval == evId && idEleve == _currentStudentId;
            } catch (_) {
              return false;
            }
          }).toList();

          String pointsStr = '-';
          if (matches.isNotEmpty) {
            // prendre la première correspondance (devrait être unique) et formater
            final m = matches.first;
            final pt = m['point'] ?? m['points'] ?? m['note'];
            if (_debugLog) {
              // ignore: avoid_print
              print('[RESULTAT DEBUG] trouvé correspondance evId=$evId élève=${_currentStudentId} pt=$pt');
            }
            if (pt != null) {
              // essayer de récupérer la pondération de l'évaluation actuelle (déjà extraite plus bas)
              final rawP = ev['ponderation'] ?? ev['ponderation_value'] ?? ev['ponderationValue'] ?? ev['weight'] ?? ev['poids'] ?? ev['ponderation_rate'];
              final pondVal = rawP != null ? double.tryParse(rawP.toString()) : null;
              try {
                final numVal = double.tryParse(pt.toString());
                if (numVal != null) {
                  final denom = pondVal != null ? (pondVal.truncateToDouble() == pondVal ? pondVal.toInt().toString() : pondVal.toString()) : '20';
                  pointsStr = '${numVal.toStringAsFixed(numVal.truncateToDouble() == numVal ? 0 : 2)}/$denom';
                } else {
                  // si la note n'est pas numérique, l'afficher brute ; tenter d'ajouter la pondération si disponible
                  final denom = pondVal != null ? (pondVal.truncateToDouble() == pondVal ? pondVal.toInt().toString() : pondVal.toString()) : '20';
                  pointsStr = '${pt.toString()}/$denom';
                }
              } catch (_) {
                final denom = pondVal != null ? (pondVal.truncateToDouble() == pondVal ? pondVal.toInt().toString() : pondVal.toString()) : '20';
                pointsStr = '${pt.toString()}/$denom';
              }
            }
          } else {
            if (_debugLog) {
              // ignore: avoid_print
              print('[RESULTAT DEBUG] PAS de correspondance pour evId=$evId élève=${_currentStudentId} count_evaluationEleves=${_evaluationEleves.length}');
              try {
                // ignore: avoid_print
                print('[RESULTAT DEBUG] évaluation examinée: ${ev}');
                if (_evaluationEleves.isNotEmpty) {
                  final sample = _evaluationEleves.take(3).map((e) => e is Map ? Map.fromEntries(e.entries.take(6)) : e).toList();
                  // ignore: avoid_print
                  print('[RESULTAT DEBUG] échantillon evaluation_eleves (3 premiers): $sample');
                }
              } catch (_) {}
            }
          }

          // Extraire la pondération (plusieurs clés possibles dans l'API)
          final rawP = ev['ponderation'] ?? ev['ponderation_value'] ?? ev['ponderationValue'] ?? ev['weight'] ?? ev['poids'] ?? ev['ponderation_rate'];
          String ponderation = '-';
          try {
            if (rawP != null) {
              final numP = double.tryParse(rawP.toString());
              if (numP != null) {
                ponderation = numP.truncateToDouble() == numP ? numP.toInt().toString() : numP.toString();
              } else {
                ponderation = rawP.toString();
              }
            }
          } catch (_) {
            ponderation = rawP?.toString() ?? '-';
          }

          // evaluation type and date
          final typeId = (ev['id_type'] ?? ev['id_type_evaluation'] ?? ev['idTypeEvaluation'] ?? ev['idType'] ?? ev['idTypeEvaluation'] ?? ev['idTypeEvaluation'])?.toString() ?? '';
          final typeName = _evaluationTypes.firstWhere((t) => ((t['id'] ?? t['id_type'] ?? '')?.toString() ?? '') == typeId, orElse: () => null)?['name'] ?? '';
          final rawDate = (ev['date'] ?? ev['created_at'] ?? ev['date_evaluation'])?.toString();
          final date = _formatDate(rawDate);

          if (!coursesAgg.containsKey(resolvedCourseId)) {
            coursesAgg[resolvedCourseId] = {'cours': courseName, 'evaluations': <Map<String, dynamic>>[], 'pointsAgg': <double>[]};
          }

          coursesAgg[resolvedCourseId]!['evaluations'].add({'type': typeName ?? '', 'date': date, 'points': pointsStr, 'ponderation': ponderation});
           if (pointsStr != '-' && pointsStr.contains('/')) {
             final left = pointsStr.split('/').first;
             final val = double.tryParse(left) ?? 0.0;
             coursesAgg[resolvedCourseId]!['pointsAgg'].add(val);
           }
        } catch (_) {}
      }

      final List<Map<String, dynamic>> rows = [];
      coursesAgg.forEach((cid, data) {
        final avgPoints = (data['pointsAgg'] as List<double>);
        String pointsLabel = '-';
        if (avgPoints.isNotEmpty) {
          final avg = avgPoints.reduce((a, b) => a + b) / avgPoints.length;
          pointsLabel = '${avg.toStringAsFixed((avg % 1) == 0 ? 0 : 2)}/20';
        }
        rows.add({'cours': data['cours'], 'points': pointsLabel, 'evaluations': data['evaluations']});
      });

      _dynamicResultatsParPeriode[title] = rows;
    }
  }

  /// Retourne une structure (période -> liste de cours) pour un élève donné.
  /// Chaque entrée de cours contient : 'cours' (nom), 'points' (moyenne ou '-') et 'evaluations' (liste).
  Future<Map<String, List<Map<String, dynamic>>>> fetchResultatsForStudent(String studentId) async {
    // Si les données ne sont pas encore chargées, charge-les.
    if (!_isLoadingData && (_periodes.isEmpty && _courses.isEmpty && _evaluations.isEmpty)) {
      await _loadData();
    } else if (_isLoadingData) {
      // Attendre la fin du chargement en boucle courte
      while (_isLoadingData) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    // Utilise une implémentation pure basée sur les listes déjà chargées pour ne pas muter l'état.
    return _computeResultatsForStudent(studentId);
  }

  Map<String, List<Map<String, dynamic>>> _computeResultatsForStudent(String studentId) {
    final Map<String, List<Map<String, dynamic>>> result = {};

    final coursesById = {for (var c in _courses) ((c['id'] ?? c['id_cours'] ?? c['idCours'])?.toString() ?? ''): c};
    final Map<String, String> coursProfIdToCoursId = {};
    for (final cp in _coursProfs) {
      try {
        final cpId = (cp['id'] ?? cp['idCoursProf'] ?? cp['id_cours_prof'] ?? '')?.toString() ?? '';
        final cid = (cp['idCours'] ?? cp['id_cours'] ?? cp['idCours'])?.toString() ?? '';
        if (cpId.isNotEmpty && cid.isNotEmpty) coursProfIdToCoursId[cpId] = cid;
      } catch (_) {}
    }

    final Map<String, Map<String, dynamic>> coursProfPeriodById = {};
    for (final rel in _coursProfPeriods) {
      try {
        final relId = (rel['id'] ?? rel['idCoursProfPeriod'] ?? '')?.toString() ?? '';
        if (relId.isNotEmpty) coursProfPeriodById[relId] = rel as Map<String, dynamic>;
      } catch (_) {}
    }

    // build periode date ranges
    final Map<String, List<DateTime?>> periodeDateRanges = {};
    for (final p in _periodes) {
      try {
        final pid = (p['id'] ?? '')?.toString() ?? '';
        final startStr = (p['startDate'] ?? p['start_date'] ?? p['created_at'])?.toString();
        final endStr = (p['endDate'] ?? p['end_date'] ?? p['updated_at'])?.toString();
        final start = startStr != null ? DateTime.tryParse(startStr) : null;
        final end = endStr != null ? DateTime.tryParse(endStr) : null;
        periodeDateRanges[pid] = [start, end];
      } catch (_) {}
    }

    // iterate periods
    for (final p in _periodes) {
      final pid = (p['id'] ?? '')?.toString() ?? '';
      final title = (p['title'] ?? p['name'] ?? p['label'] ?? (pid == 'ALL' ? 'Toutes les périodes' : 'Période')).toString();
      final Map<String, Map<String, dynamic>> coursesAgg = {};

      // initialize with all courses by default (safer)
      for (final cid in coursesById.keys) {
        final course = coursesById[cid];
        final courseName = course != null ? (course['title'] ?? course['name'] ?? '').toString() : 'Cours $cid';
        coursesAgg[cid] = {'cours': courseName, 'evaluations': <Map<String, dynamic>>[], 'pointsAgg': <double>[]};
      }

      for (final ev in _evaluations) {
        try {
          String evPeriodeId = (ev['id_periode'] ?? ev['idPeriode'] ?? ev['periode_id'] ?? '')?.toString() ?? '';
          String courseId = (ev['id_cours'] ?? ev['idCours'] ?? ev['course_id'] ?? '')?.toString() ?? '';

          if (courseId.isEmpty) {
            final linkId = (ev['idCoursProfPeriod'] ?? ev['id_cours_prof_period'] ?? ev['idCoursProfPeriod'])?.toString() ?? '';
            if (linkId.isNotEmpty && coursProfPeriodById.containsKey(linkId)) {
              final rel = coursProfPeriodById[linkId]!;
              courseId = (rel['id_cours'] ?? rel['idCours'] ?? rel['course_id'])?.toString() ?? '';
              if (courseId.isEmpty) {
                final cpId = (rel['idCoursProf'] ?? rel['id_cours_prof'] ?? rel['idCoursProf'])?.toString() ?? '';
                if (cpId.isNotEmpty && coursProfIdToCoursId.containsKey(cpId)) {
                  courseId = coursProfIdToCoursId[cpId]!;
                }
              }
              if (evPeriodeId.isEmpty) {
                evPeriodeId = (rel['id_periode'] ?? rel['idPeriode'] ?? rel['periode_id'])?.toString() ?? '';
              }
            }
          }

          if (evPeriodeId.isEmpty) {
            final evDateStr = (ev['created_at'] ?? ev['date'] ?? ev['updated_at'])?.toString() ?? '';
            final evDate = evDateStr.isNotEmpty ? DateTime.tryParse(evDateStr) : null;
            if (evDate != null) {
              for (final entry in periodeDateRanges.entries) {
                final start = entry.value[0];
                final end = entry.value[1];
                if (start != null && end != null) {
                  if (!evDate.isBefore(start) && !evDate.isAfter(end)) {
                    evPeriodeId = entry.key;
                    break;
                  }
                }
              }
            }
          }

          if (evPeriodeId != pid) continue;

          String resolvedCourseId = courseId;
          if (coursProfIdToCoursId.containsKey(resolvedCourseId)) resolvedCourseId = coursProfIdToCoursId[resolvedCourseId]!;
          if (coursProfPeriodById.containsKey(resolvedCourseId)) {
            final rel2 = coursProfPeriodById[resolvedCourseId]!;
            final relCourse = (rel2['id_cours'] ?? rel2['idCours'] ?? rel2['course_id'])?.toString() ?? '';
            if (relCourse.isNotEmpty) resolvedCourseId = relCourse;
          }
          if (resolvedCourseId.isEmpty) continue;

          // Normalise l'ID d'évaluation (plusieurs noms possibles dans l'API)
          final evId = (ev['id'] ?? ev['idEvaluation'] ?? ev['id_evaluation'] ?? ev['evaluation_id'] ?? ev['idEval'])?.toString() ?? '';
          final matches = _evaluationEleves.where((ee) {
            try {
              final idEval = (ee['id_evaluation'] ?? ee['idEvaluation'] ?? ee['evaluation_id'] ?? ee['id'])?.toString() ?? '';
              final idEleve = (ee['id_eleve'] ?? ee['idEleve'] ?? ee['student_id'] ?? ee['id'])?.toString() ?? '';
              return idEval.isNotEmpty && idEval == evId && idEleve == studentId;
            } catch (_) {
              return false;
            }
          }).toList();

          String pointsStr = '-';
          if (matches.isNotEmpty) {
            final m = matches.first;
            final pt = m['point'] ?? m['points'] ?? m['note'];
            if (_debugLog) {
              // ignore: avoid_print
              print('[RESULTAT DEBUG] trouvé correspondance evId=$evId élève=$studentId pt=$pt');
            }
            if (pt != null) {
              // récupérer la pondération si possible
              final rawP = ev['ponderation'] ?? ev['ponderation_value'] ?? ev['ponderationValue'] ?? ev['weight'] ?? ev['poids'] ?? ev['ponderation_rate'];
              final pondVal = rawP != null ? double.tryParse(rawP.toString()) : null;
              final numVal = double.tryParse(pt.toString());
              if (numVal != null) {
                final denom = pondVal != null ? (pondVal.truncateToDouble() == pondVal ? pondVal.toInt().toString() : pondVal.toString()) : '20';
                pointsStr = '${numVal.toStringAsFixed(numVal.truncateToDouble() == numVal ? 0 : 2)}/$denom';
              } else {
                final denom = pondVal != null ? (pondVal.truncateToDouble() == pondVal ? pondVal.toInt().toString() : pondVal.toString()) : '20';
                pointsStr = '${pt.toString()}/$denom';
              }
            }
          } else {
            if (_debugLog) {
              // ignore: avoid_print
              print('[RESULTAT DEBUG] PAS de correspondance (compute) evId=$evId élève=$studentId count=${_evaluationEleves.length}');
            }
          }

           // Extraire la pondération pour la méthode compute également
           final rawP = ev['ponderation'] ?? ev['ponderation_value'] ?? ev['ponderationValue'] ?? ev['weight'] ?? ev['poids'] ?? ev['ponderation_rate'];
           String ponderation = '-';
           try {
             if (rawP != null) {
               final numP = double.tryParse(rawP.toString());
               if (numP != null) {
                 ponderation = numP.truncateToDouble() == numP ? numP.toInt().toString() : numP.toString();
               } else {
                 ponderation = rawP.toString();
               }
             }
           } catch (_) {
             ponderation = rawP?.toString() ?? '-';
           }

          final typeId = (ev['id_type'] ?? ev['idType'] ?? ev['idTypeEvaluation'])?.toString() ?? '';
          final typeName = _evaluationTypes.firstWhere((t) => ((t['id'] ?? t['id_type'] ?? '')?.toString() ?? '') == typeId, orElse: () => null)?['name'] ?? '';
          final rawDate = (ev['date'] ?? ev['created_at'])?.toString() ?? '';
          final date = _formatDate(rawDate);
          coursesAgg.putIfAbsent(resolvedCourseId, () => {'cours': coursesById[resolvedCourseId] != null ? (coursesById[resolvedCourseId]!['title'] ?? coursesById[resolvedCourseId]!['name'] ?? '').toString() : 'Cours $resolvedCourseId', 'evaluations': <Map<String, dynamic>>[], 'pointsAgg': <double>[]});
          coursesAgg[resolvedCourseId]!['evaluations'].add({'type': typeName, 'date': date, 'points': pointsStr, 'ponderation': ponderation});
          if (pointsStr != '-') {
            final val = double.tryParse(pointsStr) ?? 0.0;
            coursesAgg[resolvedCourseId]!['pointsAgg'].add(val);
          }
        } catch (_) {}
      }

      final List<Map<String, dynamic>> rows = [];
      coursesAgg.forEach((cid, data) {
        final avgPoints = (data['pointsAgg'] as List<double>);
        String pointsLabel = '-';
        if (avgPoints.isNotEmpty) {
          final avg = avgPoints.reduce((a, b) => a + b) / avgPoints.length;
          pointsLabel = '${avg.toStringAsFixed((avg % 1) == 0 ? 0 : 2)}/20';
        }
        rows.add({'cours': data['cours'], 'points': pointsLabel, 'evaluations': data['evaluations']});
      });

      result[title] = rows;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final bleu = AppColors.primary(context);
    final background = AppColors.background(context);
    final textColor = AppColors.text(context);

    // when dynamic data present, use it; otherwise fall back to static map
    List<String> periodes;
    List<Map<String, dynamic>> resultatsRows;
    if (_isLoadingData) {
      periodes = [loc.translate('period_1'), loc.translate('period_2'), loc.translate('period_3')];
      resultatsRows = resultatsParPeriode.values.first;
    } else if (_loadError != null) {
      periodes = [loc.translate('period_1'), loc.translate('period_2'), loc.translate('period_3')];
      resultatsRows = resultatsParPeriode.values.first;
    } else if (_dynamicResultatsParPeriode.isNotEmpty) {
      periodes = _dynamicResultatsParPeriode.keys.toList();
      // normalize selectedIndex bounds
      if (selectedIndex >= periodes.length) selectedIndex = 0;
      resultatsRows = _dynamicResultatsParPeriode[periodes[selectedIndex]] ?? [];
    } else {
      periodes = [loc.translate('period_1'), loc.translate('period_2'), loc.translate('period_3')];
      resultatsRows = resultatsParPeriode[periodes[selectedIndex]] ?? resultatsParPeriode.values.first;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: bleu),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.translate('result_complete'),
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      backgroundColor: background,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(periodes.length, (i) {
                      final selected = selectedIndex == i;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: selected ? bleu : background,
                            foregroundColor: selected ? Colors.white : bleu,
                            side: BorderSide(color: bleu, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: () => setState(() => selectedIndex = i),
                          child: Text(
                            periodes[i],
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),

                // Tableau principal des cours
                Container(
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.alpha(bleu, 0.18)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.alpha(bleu, 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(1),
                    },
                    border: TableBorder.symmetric(
                      inside: BorderSide(color: AppColors.alpha(bleu, 0.12)),
                      outside: BorderSide(color: AppColors.alpha(bleu, 0.18)),
                    ),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: AppColors.alpha(bleu, 0.08)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                loc.translate('cours'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                loc.translate('points_obtenus'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      ...resultatsRows.map((r) => TableRow(
                        children: [
                          GestureDetector(
                            onTap: () => _showEvaluationsSheet(
                                context, r["cours"].toString(), r["evaluations"] ?? []),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 4),
                              child: Text(
                                r["cours"],
                                style: TextStyle(fontSize: 15, color: textColor),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            child: Center(
                              child: Text(
                                r["points"].toString(),
                                style: TextStyle(
                                  color: bleu,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          if (_isLoadingData)
            const Center(child: CircularProgressIndicator())
          else if (_loadError != null)
            Positioned(
              left: 16,
              right: 16,
              top: 120,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text('Erreur chargement: ${_loadError}'),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: bleu,
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.download_rounded),
                label: Text(
                  loc.translate('download'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.translate('downloading'))),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEvaluationsSheet(
      BuildContext context, String cours, List<dynamic> evaluations) {
    final loc = AppLocalizations.of(context);
    final bleu = AppColors.primary(context);
    final background = AppColors.background(context);
    final textColor = AppColors.text(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  cours,
                  style: TextStyle(
                    fontSize: 18,
                    color: bleu,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.alpha(bleu, 0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(1),
                    },
                    border: TableBorder.symmetric(
                      inside: BorderSide(color: AppColors.alpha(bleu, 0.12)),
                    ),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: AppColors.alpha(bleu, 0.08)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                loc.translate('evaluation_type'),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textColor),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                loc.translate('evaluation_date'),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textColor),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(
                              child: Text(
                                loc.translate('points'),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textColor),
                              ),
                            ),
                          ),
                        ],
                      ),
                      ...evaluations.map((e) => TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            child:
                            Text(e["type"], style: TextStyle(color: textColor)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            child:
                            Text(e["date"], style: TextStyle(color: textColor)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            child: Center(
                              child: Text(
                                e["points"],
                                style: TextStyle(
                                    color: bleu, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
