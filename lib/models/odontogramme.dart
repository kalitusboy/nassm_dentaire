import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

enum TypeDentition { permanent, temporaire, mixte }

class ToothStatus {
  final String status, notes;
  const ToothStatus({this.status = 'sain', this.notes = ''});
  Map<String, dynamic> toMap() => {'status': status, 'notes': notes};
  factory ToothStatus.fromMap(Map<String, dynamic> m) =>
      ToothStatus(status: m['status'] ?? 'sain', notes: m['notes'] ?? '');
}

class Odontogramme {
  final String id, patientId;
  final Map<String, ToothStatus> dents;
  final TypeDentition typeDentition;

  Odontogramme({
    required this.id,
    required this.patientId,
    Map<String, ToothStatus>? dents,
    this.typeDentition = TypeDentition.mixte,
  }) : dents = dents ?? {};

  // Adulte (permanent FDI)
  static const permSup = ['18','17','16','15','14','13','12','11','21','22','23','24','25','26','27','28'];
  static const permInf = ['48','47','46','45','44','43','42','41','31','32','33','34','35','36','37','38'];

  // Enfant (temporaire FDI 51–85)
  static const tempSup = ['55','54','53','52','51','61','62','63','64','65'];
  static const tempInf = ['85','84','83','82','81','71','72','73','74','75'];

  List<String> get sup => typeDentition == TypeDentition.temporaire ? tempSup : permSup;
  List<String> get inf => typeDentition == TypeDentition.temporaire ? tempInf : permInf;

  static const statuts = <String, String>{
    'sain': 'Sain',
    'carie': 'Carie',
    'soin': 'Soin',
    'couronne': 'Couronne',
    'implant': 'Implant',
    'extraction': 'Extrait',
    'prothese': 'Prothèse',
    'absente': 'Absente',
  };

  static const couleurs = <String, Color>{
    'sain': Colors.white,
    'carie': Color(0xFFE53935),
    'soin': Color(0xFF1E88E5),
    'couronne': Color(0xFFFFB300),
    'implant': Color(0xFF43A047),
    'extraction': Color(0xFF757575),
    'prothese': Color(0xFF8E24AA),
    'absente': Color(0xFF212121),
  };

  ToothStatus statusOf(String d) => dents[d] ?? const ToothStatus();

  factory Odontogramme.fromRecord(RecordModel r) {
    final raw = r.getDataValue('dents');
    final Map<String, ToothStatus> map = {};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) map[k.toString()] = ToothStatus.fromMap(Map<String, dynamic>.from(v));
      });
    }
    final typeStr = r.getStringValue('type_dentition');
    final type = TypeDentition.values.firstWhere(
      (t) => t.name == typeStr, orElse: () => TypeDentition.mixte);
    return Odontogramme(id: r.id, patientId: r.getStringValue('patient'),
      dents: map, typeDentition: type);
  }

  Map<String, dynamic> toJson() => {
        'patient': patientId,
        'dents': dents.map((k, v) => MapEntry(k, v.toMap())),
        'type_dentition': typeDentition.name,
      };

  Odontogramme copyWith({Map<String, ToothStatus>? dents, TypeDentition? type}) =>
      Odontogramme(
        id: id, patientId: patientId,
        dents: dents ?? this.dents,
        typeDentition: type ?? typeDentition,
      );
}