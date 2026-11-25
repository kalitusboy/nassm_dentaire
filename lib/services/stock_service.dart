import 'package:pocketbase/pocketbase.dart';
import '../models/article.dart';
import '../utils/pb_utils.dart';
import 'pb_client.dart';

class StockService {
  PocketBase get _pb => PbClient.instance.pb;

  static String _esc(String q) => q.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

  Future<List<Article>> list({String search = ''}) async {
    final r = await _pb.collection('articles').getFullList(
        filter: search.isEmpty ? '' : 'nom ~ "${_esc(search)}"', sort: 'nom');
    return r.map(Article.fromRecord).toList();
  }

  Future<int> countAlertes() async {
    final all = await list();
    return all.where((a) => a.enAlerte).length;
  }

  Future<Article> create(Article a) async =>
      Article.fromRecord(await _pb.collection('articles').create(body: a.toJson()));

  Future<Article> update(String id, Article a) async =>
      Article.fromRecord(await _pb.collection('articles').update(id, body: a.toJson()));

  Future<void> delete(String id) => _pb.collection('articles').delete(id);

  /// Entrée (+), sortie (−) ou ajustement (quantité = valeur donnée).
  Future<void> mouvement({
    required String articleId,
    required String type,
    required double quantite,
    required String userId,
    String motif = '',
  }) async {
    final cur = await _pb.collection('articles').getOne(articleId);
    final q = cur.getDoubleValue('quantite');
    final nouvelle = switch (type) {
      'entree' => q + quantite,
      'sortie' => q - quantite,
      _ => quantite,
    };
    await _pb.collection('mouvements_stock').create(body: {
      'article': articleId,
      'type': type,
      'quantite': quantite,
      'date': pbFmt(DateTime.now()),
      'motif': motif,
      if (userId.isNotEmpty) 'utilisateur': userId,
    });
    await _pb.collection('articles').update(articleId,
        body: {'quantite': nouvelle < 0 ? 0 : nouvelle});
  }

  Future<List<MouvementStock>> historique(String articleId) async {
    final r = await _pb.collection('mouvements_stock').getFullList(
        filter: 'article = "$articleId"', sort: '-date', expand: 'utilisateur');
    return r.map(MouvementStock.fromRecord).toList();
  }
}
