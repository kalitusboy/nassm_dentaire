import 'package:flutter/material.dart';
import '../utils/fmt.dart';

/// Histogramme simple (sans dépendance externe).
class MiniBarChart extends StatelessWidget {
  final List<MapEntry<String, double>> data;
  final Color color;
  final double height;
  const MiniBarChart({super.key, required this.data, this.color = Colors.teal, this.height = 170});

  @override
  Widget build(BuildContext context) {
    final maxV = data.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    if (data.isEmpty || maxV <= 0) {
      return SizedBox(
        height: height,
        child: Center(child: Text('Aucune donnée sur cette période',
            style: TextStyle(color: Colors.grey.shade600))),
      );
    }
    return SizedBox(
      height: height + 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in data)
            Expanded(
              child: Tooltip(
                message: '${e.key} : ${fmtMoney(e.value)}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: (e.value / maxV) * height,
                        decoration: BoxDecoration(
                          color: e.value > 0 ? color : Colors.grey.shade300,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                        constraints: const BoxConstraints(minHeight: 2),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        child: Text(e.key, style: const TextStyle(fontSize: 10)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
