import 'package:pocketbase/pocketbase.dart';
import '../utils/pb_utils.dart';

class PbClientHolder { static String baseUrl = 'http://127.0.0.1:8190'; }

class Radiographie {
  final String id, patientId, acteId, type, notes, fileName;
  final DateTime date;

  Radiographie({
    required this.id,
    required this.patientId,
    this.acteId = '',
    required this.type,
    required this.date,
    this.notes = '',
    this.fileName = '',
  });

  String get fileUrl =>
      fileName.isEmpty ? '' : '${PbClientHolder.baseUrl}/api/files/radiographies/$id/$fileName';

  factory Radiographie.fromRecord(RecordModel r) => Radiographie(
        id: r.id,
        patientId: r.getStringValue('patient'),
        acteId: r.getStringValue('acte'),
        type: r.getStringValue('type'),
        date: pbDate(r, 'date') ?? DateTime.now(),
        notes: r.getStringValue('notes'),
        fileName: r.getStringValue('fichier'),
      );
}