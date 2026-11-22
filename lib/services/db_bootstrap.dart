import 'admin_api.dart';
import 'db_schema.dart';

/// Prépare la base de données : crée les collections manquantes, ajoute les
/// champs manquants (mises à jour) et crée le premier compte utilisateur.
/// Opération idempotente : peut être relancée à chaque démarrage.
class DbBootstrap {
  final AdminApi api;
  DbBootstrap(this.api);

  Future<void> ensureSchema() async {
    await api.auth();
    var existing = await api.listCollections();
    Map<String, Map<String, dynamic>> byName() =>
        {for (final c in existing) c['name'] as String: c};

    // 1) Collection users : champs nom / prénom / rôle + règles
    final users = byName()['users'];
    if (users == null) {
      throw AdminApiException('Collection « users » introuvable.');
    }
    final uSchema = List<Map<String, dynamic>>.from(
        (users['schema'] as List).map((e) => Map<String, dynamic>.from(e)));
    final have = uSchema.map((f) => f['name']).toSet();
    var changed = false;
    for (final f in DbSchema.usersFields()) {
      if (!have.contains(f['name'])) {
        uSchema.add(f);
        changed = true;
      }
    }
    final opts = Map<String, dynamic>.from(users['options'] ?? {});
    final wantOpts = {
      'allowUsernameAuth': true,
      'allowEmailAuth': true,
      'requireEmail': false,
      'minPasswordLength': 6,
    };
    wantOpts.forEach((k, v) {
      if (opts[k] != v) {
        opts[k] = v;
        changed = true;
      }
    });
    final rules = DbSchema.usersRules();
    rules.forEach((k, v) {
      if (users[k] != v) changed = true;
    });
    if (changed) {
      await api.updateCollection(users['id'] as String,
          {'schema': uSchema, 'options': opts, ...rules});
    }

    // 2) Collections métier (création, puis ajout des champs manquants)
    existing = await api.listCollections();
    final ids = {for (final c in existing) c['name'] as String: c['id'] as String};

    for (final name in DbSchema.order) {
      // recalculé à chaque tour : les relations ont besoin des ids déjà créés
      final def =
          DbSchema.collections(ids).firstWhere((d) => d['name'] == name);
      final cur = byName()[name];
      if (cur == null) {
        final created = await api.createCollection(def);
        ids[name] = created['id'] as String;
        // les collections suivantes ont besoin de cet id
        existing = await api.listCollections();
        continue;
      }
      final curSchema = List<Map<String, dynamic>>.from(
          (cur['schema'] as List).map((e) => Map<String, dynamic>.from(e)));
      final names = curSchema.map((f) => f['name']).toSet();
      var add = false;
      for (final f in (def['schema'] as List)) {
        if (!names.contains(f['name'])) {
          // un champ requis ajouté après coup ne doit pas bloquer l'existant
          curSchema.add({...Map<String, dynamic>.from(f), 'required': false});
          add = true;
        }
      }
      if (add) {
        await api.updateCollection(cur['id'] as String, {'schema': curSchema});
      }
    }
  }

  /// Vrai si au moins un utilisateur existe déjà.
  Future<bool> hasUsers() async =>
      (await api.listRecords('users', perPage: 1)).isNotEmpty;

  /// Crée le compte principal (administrateur) et la fiche du cabinet.
  Future<void> createFirstAccount({
    required String clinicName,
    required String nom,
    required String prenom,
    required String username,
    required String password,
  }) async {
    await api.createRecord('users', {
      'username': username,
      'password': password,
      'passwordConfirm': password,
      'emailVisibility': false,
      'nom': nom,
      'prenom': prenom,
      'role': 'admin',
    });
    final p = await api.listRecords('parametres', perPage: 1);
    if (p.isEmpty) {
      await api.createRecord('parametres', {
        'nom_clinique': clinicName,
        'titre_praticien': 'CHIRURGIEN DENTISTE',
      });
    }
  }
}
