import 'package:pocketbase/pocketbase.dart';
import '../utils/pb_utils.dart';

/// Acte terminé dont le montant a été fixé par le médecin, en attente
/// d'encaissement par la réception. Créé automatiquement quand le médecin
/// enregistre un acte « terminé » avec un montant.
class Encaissement {
  final String id, patientId, patientNom, acteId, acteType, medecinNom, statut;
  final double montant;
  final DateTime cree;

  Encaissement({
    required this.id,
    required this.patientId,
    this.patientNom = '',
    this.acteId = '',
    this.acteType = '',
    this.medecinNom = '',
    required this.montant,
    this.statut = 'en_attente',
    required this.cree,
  });

  bool get estEncaisse => statut == 'encaisse';

  factory Encaissement.fromRecord(RecordModel r) {
    String pn = '', mn = '', at = '';
    final pe = r.expand['patient'];
    if (pe != null && pe.isNotEmpty) {
      pn = '${pe[0].getStringValue('prenom')} ${pe[0].getStringValue('nom')}';
    }
    final ae = r.expand['acte'];
    if (ae != null && ae.isNotEmpty) at = ae[0].getStringValue('type');
    final me = r.expand['medecin'];
    if (me != null && me.isNotEmpty) {
      mn = '${me[0].getStringValue('prenom')} ${me[0].getStringValue('nom')}';
    }
    return Encaissement(
      id: r.id,
      patientId: r.getStringValue('patient'),
      patientNom: pn,
      acteId: r.getStringValue('acte'),
      acteType: at,
      medecinNom: mn,
      montant: r.getDoubleValue('montant'),
      statut: r.getStringValue('statut') == '' ? 'en_attente' : r.getStringValue('statut'),
      cree: pbDate(r, 'created') ?? DateTime.now(),
    );
  }
}
