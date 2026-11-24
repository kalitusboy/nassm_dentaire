import 'package:pocketbase/pocketbase.dart';
import '../utils/pb_utils.dart';

class Medicament {
  final String nom, posologie, duree;
  Medicament({required this.nom, required this.posologie, required this.duree});
  factory Medicament.fromMap(Map<String, dynamic> m) => Medicament(
        nom: m['nom'] ?? '', posologie: m['posologie'] ?? '', duree: m['duree'] ?? '');
  Map<String, dynamic> toMap() => {'nom': nom, 'posologie': posologie, 'duree': duree};
}

class Ordonnance {
  final String id, patientId, medecinId, instructions;
  final DateTime date;
  final List<Medicament> medicaments;

  Ordonnance({
    required this.id,
    required this.patientId,
    required this.medecinId,
    required this.date,
    required this.medicaments,
    this.instructions = '',
  });

  factory Ordonnance.fromRecord(RecordModel r) {
    final raw = r.getDataValue('medicaments');
    final List<Medicament> meds = [];
    if (raw is List) {
      meds.addAll(raw.map((e) => Medicament.fromMap(Map<String, dynamic>.from(e))));
    }
    return Ordonnance(
      id: r.id, patientId: r.getStringValue('patient'),
      medecinId: r.getStringValue('medecin'),
      date: pbDate(r, 'date') ?? DateTime.now(),
      medicaments: meds,
      instructions: r.getStringValue('instructions'),
    );
  }

  Map<String, dynamic> toJson() => {
        'patient': patientId,
        'medecin': medecinId,
        'date': pbFmt(date),
        'medicaments': medicaments.map((m) => m.toMap()).toList(),
        'instructions': instructions,
      };
}