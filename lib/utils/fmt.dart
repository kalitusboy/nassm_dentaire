import 'package:intl/intl.dart';

final NumberFormat _money =
    NumberFormat.currency(locale: 'fr_FR', symbol: 'DA', decimalDigits: 0);

/// « 12 500 DA »
String fmtMoney(num v) => _money.format(v);

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

String fmtDate(DateTime d) => DateFormat('dd/MM/yyyy', 'fr_FR').format(d);
String fmtTime(DateTime d) => DateFormat('HH:mm', 'fr_FR').format(d);
String fmtDateTime(DateTime d) => DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(d);

/// « il y a 12 min » / « 1 h 05 »
String fmtWaiting(Duration d) {
  if (d.inMinutes < 1) return 'à l\'instant';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  return '${d.inHours} h $m';
}
