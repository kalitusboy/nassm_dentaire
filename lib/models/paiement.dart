import 'package:pocketbase/pocketbase.dart';
import '../utils/pb_utils.dart';

class Paiement {
  final String id, acteId, patientId, methode, notes;
  final double montant;
  final DateTime date;

  Paiement({
    required this.id,
    required this.acteId,
    required this.patientId,
    required this.montant,
    required this.date,
    this.methode = 'espece',
    this.notes = '',
  });

  factory Paiement.fromRecord(RecordModel r) => Paiement(
        id: r.id,
        acteId: r.getStringValue('acte'),
        patientId: r.getStringValue('patient'),
        montant: r.getDoubleValue('montant'),
        date: pbDate(r, 'date') ?? DateTime.now(),
        methode: r.getStringValue('methode'),
        notes: r.getStringValue('notes'),
      );

  Map<String, dynamic> toJson() => {
        'acte': acteId,
        'patient': patientId,
        'montant': montant,
        'date': date.toIso8601String(),
        'methode': methode,
        'notes': notes,
      };
}