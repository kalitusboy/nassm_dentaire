import 'package:pocketbase/pocketbase.dart';

class Patient {
  final String id, numeroDossier, nom, prenom, telephone, adresse, allergies, notesMedicales;
  final DateTime? dateNaissance;

  Patient({
    required this.id,
    required this.numeroDossier,
    required this.nom,
    required this.prenom,
    this.dateNaissance,
    this.telephone = '',
    this.adresse = '',
    this.allergies = '',
    this.notesMedicales = '',
  });

  String get fullName => '$prenom $nom'.trim();
  int? get age => dateNaissance == null
      ? null
      : DateTime.now().year - dateNaissance!.year -
          (DateTime.now().month < dateNaissance!.month ? 1 : 0);

  factory Patient.fromRecord(RecordModel r) => Patient(
        id: r.id,
        numeroDossier: r.getStringValue('numero_dossier'),
        nom: r.getStringValue('nom'),
        prenom: r.getStringValue('prenom'),
        dateNaissance: r.getDateTimeValue('date_naissance'),
        telephone: r.getStringValue('telephone'),
        adresse: r.getStringValue('adresse'),
        allergies: r.getStringValue('allergies'),
        notesMedicales: r.getStringValue('notes_medicales'),
      );

  Map<String, dynamic> toJson() => {
        'numero_dossier': numeroDossier,
        'nom': nom,
        'prenom': prenom,
        'date_naissance': dateNaissance?.toIso8601String(),
        'telephone': telephone,
        'adresse': adresse,
        'allergies': allergies,
        'notes_medicales': notesMedicales,
      };
}