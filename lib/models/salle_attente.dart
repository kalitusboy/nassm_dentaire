import 'package:pocketbase/pocketbase.dart';
import '../utils/pb_utils.dart';

/// Un patient présent dans la salle d'attente, enregistré par la réception.
/// L'ordre d'appel suit l'heure d'arrivée (ordre de création).
class SalleAttente {
  final String id, patientId, nom, prenom, statut, notes;
  final DateTime? dateNaissance;
  final DateTime arrivee, appel;

  SalleAttente({
    required this.id,
    this.patientId = '',
    required this.nom,
    required this.prenom,
    this.dateNaissance,
    this.statut = 'en_attente',
    this.notes = '',
    required this.arrivee,
    DateTime? appel,
  }) : appel = appel ?? arrivee;

  String get fullName => '$nom $prenom'.trim();

  factory SalleAttente.fromRecord(RecordModel r) => SalleAttente(
        id: r.id,
        patientId: r.getStringValue('patient'),
        nom: r.getStringValue('nom'),
        prenom: r.getStringValue('prenom'),
        dateNaissance: pbDate(r, 'date_naissance'),
        statut: r.getStringValue('statut') == ''
            ? 'en_attente'
            : r.getStringValue('statut'),
        notes: r.getStringValue('notes'),
        arrivee: pbDate(r, 'arrivee') ?? DateTime.now(),
        appel: pbDate(r, 'appel'),
      );

  Map<String, dynamic> toJson() => {
        'patient': patientId,
        'nom': nom,
        'prenom': prenom,
        'date_naissance': dateNaissance == null ? null : pbFmt(dateNaissance!),
        'statut': statut,
        'notes': notes,
        'arrivee': pbFmt(arrivee),
        'appel': pbFmt(appel),
      };
}
