import 'package:pocketbase/pocketbase.dart';

class Parametre {
  final String id, nomClinique, titrePraticien, adresse, telephone, email, numeroOrdre;
  final String logoUrl; // nom du fichier logo (collection parametres)

  Parametre({
    required this.id,
    required this.nomClinique,
    required this.titrePraticien,
    required this.adresse,
    required this.telephone,
    this.email = '',
    this.numeroOrdre = '',
    this.logoUrl = '',
  });

  factory Parametre.fromRecord(RecordModel r) => Parametre(
        id: r.id,
        nomClinique: r.getStringValue('nom_clinique'),
        titrePraticien: r.getStringValue('titre_praticien'),
        adresse: r.getStringValue('adresse'),
        telephone: r.getStringValue('telephone'),
        email: r.getStringValue('email'),
        numeroOrdre: r.getStringValue('numero_ordre'),
        logoUrl: r.getStringValue('logo'),
      );

  Map<String, dynamic> toJson() => {
        'nom_clinique': nomClinique,
        'titre_praticien': titrePraticien,
        'adresse': adresse,
        'telephone': telephone,
        'email': email,
        'numero_ordre': numeroOrdre,
      };
}