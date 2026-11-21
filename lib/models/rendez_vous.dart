import 'package:pocketbase/pocketbase.dart';

class RendezVous {
  final String id, patientId, patientNom, medecinId, medecinNom, motif, statut;
  final DateTime dateHeure;
  final int dureeMinutes;

  RendezVous({
    required this.id,
    required this.patientId,
    this.patientNom = '',
    required this.medecinId,
    this.medecinNom = '',
    required this.dateHeure,
    this.dureeMinutes = 30,
    this.motif = '',
    this.statut = 'planifie',
  });

  factory RendezVous.fromRecord(RecordModel r) {
    String pn = '', mn = '';
    final pe = r.expand['patient'];
    if (pe != null && pe.isNotEmpty) {
      pn = '${pe[0].getStringValue('prenom')} ${pe[0].getStringValue('nom')}';
    }
    final me = r.expand['medecin'];
    if (me != null && me.isNotEmpty) {
      mn = '${me[0].getStringValue('prenom')} ${me[0].getStringValue('nom')}';
    }
    return RendezVous(
      id: r.id,
      patientId: r.getStringValue('patient'),
      patientNom: pn,
      medecinId: r.getStringValue('medecin'),
      medecinNom: mn,
      dateHeure: r.getDateTimeValue('date_heure') ?? DateTime.now(),
      dureeMinutes: r.getIntValue('duree_minutes'),
      motif: r.getStringValue('motif'),
      statut: r.getStringValue('statut'),
    );
  }

  Map<String, dynamic> toJson() => {
        'patient': patientId,
        'medecin': medecinId,
        'date_heure': dateHeure.toIso8601String(),
        'duree_minutes': dureeMinutes,
        'motif': motif,
        'statut': statut,
      };
}