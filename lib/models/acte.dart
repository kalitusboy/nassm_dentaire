import 'package:pocketbase/pocketbase.dart';
import '../utils/pb_utils.dart';

class Acte {
  final String id, patientId, medecinId, medecinNom, type, description, statut;
  final int? dent;
  final DateTime date;
  final double montantTotal;

  Acte({
    required this.id,
    required this.patientId,
    required this.medecinId,
    this.medecinNom = '',
    required this.type,
    this.dent,
    required this.date,
    this.description = '',
    required this.montantTotal,
    this.statut = 'planifie',
  });

  static const typesLibelles = {
    'examen': 'Examen clinique',
    'detartrage': 'Détartrage',
    'soin_carie': 'Soin carie',
    'extraction': 'Extraction',
    'endodontie': 'Endodontie',
    'couronne': 'Couronne',
    'bridge': 'Bridge',
    'implant': 'Implant',
    'prothese': 'Prothèse',
    'autre': 'Autre',
  };

  String get typeLibelle => typesLibelles[type] ?? type;

  factory Acte.fromRecord(RecordModel r) {
    String med = '';
    final e = r.expand['medecin'];
    if (e != null && e.isNotEmpty) {
      med = '${e[0].getStringValue('prenom')} ${e[0].getStringValue('nom')}';
    }
    return Acte(
      id: r.id,
      patientId: r.getStringValue('patient'),
      medecinId: r.getStringValue('medecin'),
      medecinNom: med,
      type: r.getStringValue('type'),
      dent: r.getIntValue('dent') > 0 ? r.getIntValue('dent') : null,
      date: pbDate(r, 'date') ?? DateTime.now(),
      description: r.getStringValue('description'),
      montantTotal: r.getDoubleValue('montant_total'),
      statut: r.getStringValue('statut'),
    );
  }

  Map<String, dynamic> toJson() => {
        'patient': patientId,
        'medecin': medecinId,
        'type': type,
        'dent': dent ?? 0,
        'date': date.toIso8601String(),
        'description': description,
        'montant_total': montantTotal,
        'statut': statut,
      };
}