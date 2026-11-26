import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/report_service.dart';

/// Sélecteur Jour / Mois / Année avec navigation précédent/suivant.
class PeriodBar extends StatelessWidget {
  final Granularite gran;
  final DateTime ref;
  final void Function(Granularite g, DateTime ref) onChanged;
  const PeriodBar({super.key, required this.gran, required this.ref, required this.onChanged});

  DateTime _shift(int dir) => switch (gran) {
        Granularite.jour => DateTime(ref.year, ref.month, ref.day + dir),
        Granularite.mois => DateTime(ref.year, ref.month + dir, 1),
        Granularite.annee => DateTime(ref.year + dir, 1, 1),
      };

  String get _label => switch (gran) {
        Granularite.jour => DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(ref),
        Granularite.mois => DateFormat.yMMMM('fr_FR').format(ref),
        Granularite.annee => '${ref.year}',
      };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<Granularite>(
          segments: const [
            ButtonSegment(value: Granularite.jour, label: Text('Jour')),
            ButtonSegment(value: Granularite.mois, label: Text('Mois')),
            ButtonSegment(value: Granularite.annee, label: Text('Année')),
          ],
          selected: {gran},
          onSelectionChanged: (s) => onChanged(s.first, ref),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => onChanged(gran, _shift(-1))),
          InkWell(
            onTap: () => onChanged(gran, DateTime.now()),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(_label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => onChanged(gran, _shift(1))),
        ]),
      ],
    );
  }
}
