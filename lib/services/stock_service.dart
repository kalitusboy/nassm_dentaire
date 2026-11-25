import 'package:pocketbase/pocketbase.dart';
import '../models/stock.dart';
import 'pb_client.dart';

class StockService {
  PocketBase get _pb => PbClient.instance.pb;

  Future<List<StockItem>> list({String categorie = ''}) async {
    final r = await _pb.collection('stock').getFullList(
        filter: categorie.isEmpty ? '' : 'categorie = "$categorie"',
        sort: 'nom');
    return r.map(StockItem.fromRecord).toList();
  }

  /// Articles à commander : quantité <= seuil d'alerte ou périmés.
  Future<List<StockItem>> alertes() async {
    final all = await list();
    return all.where((a) => a.estBas || a.estExpire).toList();
  }

  Future<StockItem> create(StockItem i) async => StockItem.fromRecord(
      await _pb.collection('stock').create(body: i.toJson()));

  Future<StockItem> update(String id, StockItem i) async =>
      StockItem.fromRecord(
          await _pb.collection('stock').update(id, body: i.toJson()));

  /// Entrée (+) ou sortie (-) de stock, en une opération atomique simple.
  Future<void> ajuster(String id, double delta) async {
    final r = await _pb.collection('stock').getOne(id);
    final item = StockItem.fromRecord(r);
    final q = (item.quantite + delta).clamp(0, double.infinity);
    await _pb.collection('stock').update(id, body: {'quantite': q});
  }

  Future<void> delete(String id) => _pb.collection('stock').delete(id);
}
