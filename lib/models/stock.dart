import 'package:pocketbase/pocketbase.dart';
import '../utils/pb_utils.dart';

/// Article du stock (consommables, anesthésiques, matériel…).
class StockItem {
  final String id, nom, categorie, unite, notes;
  final double quantite, seuilAlerte, prixUnitaire;
  final DateTime? expireLe;

  StockItem({
    required this.id,
    required this.nom,
    this.categorie = 'autre',
    this.unite = 'u',
    this.quantite = 0,
    this.seuilAlerte = 0,
    this.prixUnitaire = 0,
    this.notes = '',
    this.expireLe,
  });

  bool get estBas => quantite <= seuilAlerte;
  bool get estExpire =>
      expireLe != null && expireLe!.isBefore(DateTime.now());

  factory StockItem.fromRecord(RecordModel r) => StockItem(
        id: r.id,
        nom: r.getStringValue('nom'),
        categorie: r.getStringValue('categorie') == ''
            ? 'autre'
            : r.getStringValue('categorie'),
        unite: r.getStringValue('unite') == '' ? 'u' : r.getStringValue('unite'),
        quantite: r.getDoubleValue('quantite'),
        seuilAlerte: r.getDoubleValue('seuil_alerte'),
        prixUnitaire: r.getDoubleValue('prix_unitaire'),
        notes: r.getStringValue('notes'),
        expireLe: pbDate(r, 'expire_le'),
      );

  Map<String, dynamic> toJson() => {
        'nom': nom,
        'categorie': categorie,
        'unite': unite,
        'quantite': quantite,
        'seuil_alerte': seuilAlerte,
        'prix_unitaire': prixUnitaire,
        'notes': notes,
        'expire_le': expireLe == null ? null : pbFmt(expireLe!),
      };
}
