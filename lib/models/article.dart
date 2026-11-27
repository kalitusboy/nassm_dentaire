import 'package:pocketbase/pocketbase.dart';
import '../utils/pb_utils.dart';

class Article {
  final String id, nom, categorie, unite, fournisseur, notes;
  final double quantite, seuilAlerte, prixUnitaire;

  Article({
    required this.id,
    required this.nom,
    this.categorie = 'consommable',
    this.unite = '',
    this.quantite = 0,
    this.seuilAlerte = 0,
    this.prixUnitaire = 0,
    this.fournisseur = '',
    this.notes = '',
  });

  static const categorieLibelles = {
    'anesthesie': 'Anesthésie',
    'injection': 'Injections / seringues',
    'consommable': 'Consommables',
    'materiel': 'Matériel / instruments',
    'medicament': 'Médicaments',
    'hygiene': 'Hygiène / stérilisation',
    'autre': 'Autre',
  };

  String get categorieLibelle => categorieLibelles[categorie] ?? categorie;
  bool get enAlerte => seuilAlerte > 0 && quantite <= seuilAlerte;
  bool get enRupture => quantite <= 0;

  factory Article.fromRecord(RecordModel r) => Article(
        id: r.id,
        nom: r.getStringValue('nom'),
        categorie: r.getStringValue('categorie'),
        unite: r.getStringValue('unite'),
        quantite: r.getDoubleValue('quantite'),
        seuilAlerte: r.getDoubleValue('seuil_alerte'),
        prixUnitaire: r.getDoubleValue('prix_unitaire'),
        fournisseur: r.getStringValue('fournisseur'),
        notes: r.getStringValue('notes'),
      );

  Map<String, dynamic> toJson() => {
        'nom': nom,
        'categorie': categorie.isEmpty ? 'autre' : categorie,
        'unite': unite,
        'quantite': quantite,
        'seuil_alerte': seuilAlerte,
        'prix_unitaire': prixUnitaire,
        'fournisseur': fournisseur,
        'notes': notes,
      };
}

class MouvementStock {
  final String id, articleId, type, motif, utilisateurNom;
  final double quantite;
  final DateTime date;

  MouvementStock({
    required this.id,
    required this.articleId,
    required this.type,
    required this.quantite,
    required this.date,
    this.motif = '',
    this.utilisateurNom = '',
  });

  factory MouvementStock.fromRecord(RecordModel r) {
    String un = '';
    final ue = r.expand['utilisateur'];
    if (ue != null && ue.isNotEmpty) {
      un = '${ue[0].getStringValue('prenom')} ${ue[0].getStringValue('nom')}'.trim();
      if (un.isEmpty) un = ue[0].getStringValue('username');
    }
    return MouvementStock(
      id: r.id,
      articleId: r.getStringValue('article'),
      type: r.getStringValue('type'),
      quantite: r.getDoubleValue('quantite'),
      date: pbDate(r, 'date') ?? DateTime.now(),
      motif: r.getStringValue('motif'),
      utilisateurNom: un,
    );
  }
}
