/// Définition complète de la base de données (PocketBase 0.22.x).
/// Elle est appliquée automatiquement au premier lancement, et complétée
/// automatiquement lors des mises à jour (champs manquants ajoutés).
library;

const _auth = '@request.auth.id != ""';
const _admin = '@request.auth.role = "admin"';

Map<String, dynamic> _f(String name, String type,
        {bool required = false, Map<String, dynamic>? options}) =>
    {
      'name': name,
      'type': type,
      'required': required,
      'options': options ?? {},
    };

Map<String, dynamic> _text(String n, {bool required = false}) =>
    _f(n, 'text', required: required);
Map<String, dynamic> _num(String n, {bool required = false}) =>
    _f(n, 'number', required: required);
Map<String, dynamic> _date(String n, {bool required = false}) =>
    _f(n, 'date', required: required);
Map<String, dynamic> _json(String n) =>
    _f(n, 'json', options: {'maxSize': 5000000});
Map<String, dynamic> _select(String n, List<String> values,
        {bool required = false}) =>
    _f(n, 'select',
        required: required, options: {'maxSelect': 1, 'values': values});
Map<String, dynamic> _rel(String n, String collectionId,
        {bool required = false}) =>
    _f(n, 'relation', required: required, options: {
      'collectionId': collectionId,
      'cascadeDelete': false,
      'minSelect': null,
      'maxSelect': 1,
      'displayFields': null,
    });

class DbSchema {
  /// Champs ajoutés à la collection `users` (intégrée).
  static List<Map<String, dynamic>> usersFields() => [
        _text('nom'),
        _text('prenom'),
        _select('role', ['admin', 'dentiste', 'reception'], required: true),
      ];

  static Map<String, dynamic> usersRules() => {
        'listRule': _auth,
        'viewRule': _auth,
        'createRule': _admin,
        'updateRule': _admin,
        'deleteRule': _admin,
      };

  static const order = [
    'patients', 'actes', 'paiements', 'rendez_vous',
    'ordonnances', 'radiographies', 'parametres', 'odontogrammes',
  ];

  /// Collections de l'application, dans l'ordre de création.
  /// [ids] contient les ids des collections déjà existantes (users, patients…).
  static List<Map<String, dynamic>> collections(Map<String, String> ids) {
    Map<String, dynamic> base(String name, List<Map<String, dynamic>> schema,
            {List<String> indexes = const []}) =>
        {
          'name': name,
          'type': 'base',
          'schema': schema,
          'indexes': indexes,
          'listRule': _auth,
          'viewRule': _auth,
          'createRule': _auth,
          'updateRule': _auth,
          'deleteRule': _admin,
        };

    final users = ids['users'] ?? '';
    return [
      base('patients', [
        _text('numero_dossier', required: true),
        _text('nom', required: true),
        _text('prenom', required: true),
        _date('date_naissance'),
        _text('telephone'),
        _text('adresse'),
        _text('allergies'),
        _text('notes_medicales'),
      ], indexes: [
        'CREATE UNIQUE INDEX idx_patients_numero ON patients (numero_dossier)'
      ]),
      base('actes', [
        _rel('patient', ids['patients'] ?? '', required: true),
        _rel('medecin', users),
        _select('type', [
          'examen', 'detartrage', 'soin_carie', 'extraction', 'endodontie',
          'couronne', 'bridge', 'implant', 'prothese', 'autre'
        ], required: true),
        _num('dent'),
        _date('date'),
        _text('description'),
        _num('montant_total'),
        _select('statut', ['planifie', 'en_cours', 'termine', 'annule']),
      ]),
      base('paiements', [
        _rel('acte', ids['actes'] ?? ''),
        _rel('patient', ids['patients'] ?? '', required: true),
        _num('montant', required: true),
        _date('date'),
        _select('methode', ['espece', 'cheque', 'carte', 'virement']),
        _text('notes'),
      ]),
      base('rendez_vous', [
        _rel('patient', ids['patients'] ?? '', required: true),
        _rel('medecin', users),
        _date('date_heure', required: true),
        _num('duree_minutes'),
        _text('motif'),
        _select('statut', ['planifie', 'confirme', 'termine', 'annule']),
      ]),
      base('ordonnances', [
        _rel('patient', ids['patients'] ?? '', required: true),
        _rel('medecin', users),
        _date('date'),
        _json('medicaments'),
        _text('instructions'),
      ]),
      base('radiographies', [
        _rel('patient', ids['patients'] ?? '', required: true),
        _rel('acte', ids['actes'] ?? ''),
        _f('fichier', 'file', required: true, options: {
          'maxSelect': 1,
          'maxSize': 104857600,
          'mimeTypes': <String>[],
          'thumbs': <String>[],
          'protected': false,
        }),
        _select('type', ['panoramique', 'periapicale', 'cbct', 'autre']),
        _date('date'),
        _text('notes'),
      ]),
      base('parametres', [
        _text('nom_clinique'),
        _text('titre_praticien'),
        _text('adresse'),
        _text('telephone'),
        _text('email'),
        _text('numero_ordre'),
      ]),
      base('odontogrammes', [
        _rel('patient', ids['patients'] ?? '', required: true),
        _json('dents'),
        _select('type_dentition', ['permanent', 'temporaire', 'mixte']),
      ], indexes: [
        'CREATE UNIQUE INDEX idx_odonto_patient ON odontogrammes (patient)'
      ]),
    ];
  }
}
