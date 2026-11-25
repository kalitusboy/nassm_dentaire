import 'package:pocketbase/pocketbase.dart';

/// Lit un champ date d'un enregistrement PocketBase.
/// (Remplace `getDateTimeValue`, absent de la version du SDK utilisée.)
DateTime? pbDate(RecordModel r, String field) {
  final s = r.getStringValue(field);
  if (s.isEmpty) return null;
  return DateTime.tryParse(s)?.toLocal();
}

/// Formate une date pour PocketBase : UTC, « 2026-11-22 09:00:00.000Z ».
/// À utiliser pour les valeurs envoyées ET pour les filtres (comparaison textuelle).
String pbFmt(DateTime d) =>
    DateTime.fromMillisecondsSinceEpoch(d.millisecondsSinceEpoch, isUtc: true)
        .toString();
