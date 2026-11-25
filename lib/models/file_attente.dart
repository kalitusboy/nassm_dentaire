import 'package:pocketbase/pocketbase.dart';
import '../utils/pb_utils.dart';

/// Un passage d'un patient en salle d'attente (une journée).
class FileAttente {
  final String id, patientId, patientNom, patientTel, medecinId, medecinNom;
  final String statut, motif, note;
  final bool appelReception;
  final DateTime heureArrivee;
  final DateTime? dateNaissance;

  FileAttente({
    required this.id,
    required this.patientId,
    this.patientNom = '',
    this.patientTel = '',
    this.dateNaissance,
    this.medecinId = '',
    this.medecinNom = '',
    required this.heureArrivee,
    this.statut = 'attente',
    this.motif = '',
    this.note = '',
    this.appelReception = false,
  });

  static const statutLibelles = {
    'attente': 'En attente',
    'en_consultation': 'En consultation',
    'a_encaisser': 'À encaisser',
    'termine': 'Terminé',
    'annule': 'Annulé',
  };

  String get statutLibelle => statutLibelles[statut] ?? statut;

  int? get age => dateNaissance == null
      ? null
      : DateTime.now().year -
          dateNaissance!.year -
          (DateTime.now().month < dateNaissance!.month ? 1 : 0);

  factory FileAttente.fromRecord(RecordModel r) {
    String pn = '', pt = '', mn = '';
    DateTime? dob;
    final pe = r.expand['patient'];
    if (pe != null && pe.isNotEmpty) {
      pn = '${pe[0].getStringValue('nom').toUpperCase()} ${pe[0].getStringValue('prenom')}'.trim();
      pt = pe[0].getStringValue('telephone');
      dob = pbDate(pe[0], 'date_naissance');
    }
    final me = r.expand['medecin'];
    if (me != null && me.isNotEmpty) {
      mn = '${me[0].getStringValue('prenom')} ${me[0].getStringValue('nom')}'.trim();
    }
    return FileAttente(
      id: r.id,
      patientId: r.getStringValue('patient'),
      patientNom: pn,
      patientTel: pt,
      dateNaissance: dob,
      medecinId: r.getStringValue('medecin'),
      medecinNom: mn,
      heureArrivee: pbDate(r, 'heure_arrivee') ?? DateTime.now(),
      statut: r.getStringValue('statut'),
      motif: r.getStringValue('motif'),
      note: r.getStringValue('note'),
      appelReception: r.getBoolValue('appel_reception'),
    );
  }
}
