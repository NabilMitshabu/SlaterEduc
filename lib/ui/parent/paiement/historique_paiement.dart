import 'dart:convert';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../services/app_colors.dart';
import '../../../services/app_localizations.dart';
import '../../../services/api/historique_paiement_service.dart';

class HistoriquePaiementScreen extends StatefulWidget {
  final String studentId;
  const HistoriquePaiementScreen({super.key, required this.studentId});

  @override
  State<HistoriquePaiementScreen> createState() => _HistoriquePaiementScreenState();
}

class _HistoriquePaiementScreenState extends State<HistoriquePaiementScreen> {
  late Future<List<PaymentRow>> _futureRows;
  final HistoriquePaiementService _service = HistoriquePaiementService();

  @override
  void initState() {
    super.initState();
    _futureRows = _service.loadData(widget.studentId);
  }

  @override
  Widget build(BuildContext context) {
    final bleu = AppColors.primary(context);
    final bg = AppColors.background(context);
    final txt = AppColors.text(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: txt),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context).translate('historique_paiement'),
           style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 18),
         ),
         centerTitle: true,
       ),
       backgroundColor: bg,
       body: Padding(
         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
         child: FutureBuilder<List<PaymentRow>>(
           future: _futureRows,
           builder: (context, snapshot) {
             if (snapshot.connectionState == ConnectionState.waiting) {
               return Center(child: CircularProgressIndicator(color: bleu));
             }
             if (snapshot.hasError) {
               return Center(child: Text('Erreur: ${snapshot.error}', style: TextStyle(color: txt)));
             }
             final rows = snapshot.data ?? [];
             if (rows.isEmpty) {
               return Center(child: Text(AppLocalizations.of(context).translate('no_payments'), style: TextStyle(color: txt)));
             }

             return SingleChildScrollView(

                 child: Table(
                   defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                   columnWidths: const {
                     0: FlexColumnWidth(3),
                     1: FlexColumnWidth(2),
                     2: FlexColumnWidth(1.5),
                   },
                   border: TableBorder.all(
                     color: AppColors.alpha(bleu, 0.15),
                     width: 1,
                   ),
                   children: [
                     // ----- ENTÊTE -----
                     TableRow(
                       decoration: BoxDecoration(
                         color: AppColors.alpha(bleu, 0.10),
                       ),
                       children: [
                         _headerCell(
                           context,
                           AppLocalizations.of(context).translate('type_frais'),
                           txt,
                         ),
                         _headerCell(
                           context,
                           AppLocalizations.of(context).translate('date_paiement'),
                           txt,
                         ),
                         _headerCell(
                           context,
                           AppLocalizations.of(context).translate('montant'),
                           txt,
                         ),
                       ],
                     ),

                     // ----- LIGNES -----
                     ...rows.map(
                           (p) => TableRow(
                         decoration: BoxDecoration(
                           color: AppColors.alpha(bleu, 0.03),
                         ),
                         children: [
                           _dataCell(p.type, txt),
                           _dataCell(p.date, txt),
                           _amountCell(p.amount, bleu),
                         ],
                       ),
                     ),
                   ],
                 ),
               );
           },
         ),
       ),
    );
  }
}

Widget _headerCell(BuildContext context, String text, Color txt) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Center(
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: txt,
        ),
      ),
    ),
  );
}

Widget _dataCell(String text, Color txt) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: txt,
      ),
    ),
  );
}

Widget _amountCell(String amount, Color bleu) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Center(
      child: Text(
        amount,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: bleu,
        ),
      ),
    ),
  );
}

