import 'package:pocketbase/pocketbase.dart';

/// Lit un champ date d'un enregistrement PocketBase.
/// (Remplace `getDateTimeValue`, absent de la version du SDK utilisée.)
DateTime? pbDate(RecordModel r, String field) {
  final s = r.getStringValue(field);
  if (s.isEmpty) return null;
  return DateTime.tryParse(s)?.toLocal();
}
