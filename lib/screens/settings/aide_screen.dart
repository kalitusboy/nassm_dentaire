import 'package:flutter/material.dart';

class AideScreen extends StatelessWidget {
  const AideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aide — Guide d\'utilisation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête
          Card(
            color: Theme.of(context).primaryColor.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.help_outline,
                      size: 40, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bienvenue dans l\'aide',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Guide complet d\'utilisation du logiciel. '
                          'Cliquez sur chaque section pour voir les détails.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ═════ Démarrage ═════
          _section(
            icon: Icons.rocket_launch,
            title: 'Démarrage rapide',
            children: [
              _qa(
                'Première connexion',
                'Lancez l\'application → saisissez votre email et mot de '
                    'passe (fournis par l\'administrateur) → cliquez sur '
                    '"Se connecter".',
              ),
              _qa(
                'Configuration du cabinet',
                'Allez à "Paramétrage" dans le menu de gauche → saisissez '
                    'le nom de la clinique, le titre du praticien, l\'adresse '
                    'et le téléphone → Enregistrer. Ces infos apparaîtront '
                    'sur toutes les ordonnances et factures.',
              ),
              _qa(
                'Mode Serveur (Hôte) ou Client',
                'Le poste principal (réception) doit être en mode "Serveur". '
                    'Les autres postes se connectent en mode "Client" en '
                    'saisissant l\'adresse IP du serveur. Modifiable dans '
                    '"Réglages".',
              ),
            ],
          ),

          // ═════ Patients ═════
          _section(
            icon: Icons.people,
            title: 'Gestion des patients',
            children: [
              _qa(
                'Ajouter un nouveau patient',
                'Menu "Patients" → bouton "Nouveau patient" → remplissez '
                    'les champs obligatoires (nom, prénom) → Enregistrer. '
                    'Le numéro de dossier est généré automatiquement.',
              ),
              _qa(
                'Rechercher un patient',
                'Dans la barre de recherche, tapez le nom, prénom ou '
                    'numéro de dossier. La recherche est instantanée.',
              ),
              _qa(
                'Consulter le dossier d\'un patient',
                'Cliquez sur un patient dans la liste → vous verrez ses '
                    'informations, sa situation financière, ses actes, ses '
                    'rendez-vous et son schéma dentaire.',
              ),
            ],
          ),

          // ═════ Actes / Soins ═════
          _section(
            icon: Icons.medical_services,
            title: 'Actes et soins',
            children: [
              _qa(
                'Enregistrer un acte',
                'Ouvrez un patient → onglet "Actes" → bouton "Nouvel acte" '
                    '(ou FAB en bas) → choisissez le type (soin carie, '
                    'extraction, implant...) → dent (optionnel) → montant '
                    '→ Enregistrer.',
              ),
              _qa(
                'Statuts des actes',
                'Planifié (prévu), En cours (en traitement), Terminé '
                    '(achevé — c\'est ici que la "dernière visite" est '
                    'calculée), Annulé.',
              ),
              _qa(
                'Voir qui a soigné le patient',
                'Dans l\'onglet "Actes", chaque acte affiche le nom du '
                    'médecin traitant (Dr. ...). Utile quand plusieurs '
                    'praticiens travaillent dans le cabinet.',
              ),
            ],
          ),

          // ═════ Paiements ═════
          _section(
            icon: Icons.payments,
            title: 'Paiements et finances',
            children: [
              _qa(
                'Enregistrer un paiement',
                'Dans l\'onglet "Actes" d\'un patient → icône 💰 sur un '
                    'acte → saisissez le montant versé → méthode (espèces, '
                    'chèque, carte, virement) → Valider.',
              ),
              _qa(
                'Voir la situation financière',
                'Onglet "Infos" du patient → carte "Situation financière" '
                    'affiche : Total facturé, Total payé et Reste à payer.',
              ),
              _qa(
                'Imprimer une facture',
                'Menu du patient (⋮ en haut à droite) → "Imprimer facture". '
                    'Une facture A5 s\'ouvre pour impression ou PDF.',
              ),
              _qa(
                'Relevé de compte détaillé',
                'Menu du patient (⋮) → "Relevé de compte". Document A4 '
                    'listant toutes les transactions (actes + paiements) avec '
                    'solde cumulatif.',
              ),
            ],
          ),

          // ═════ Rendez-vous ═════
          _section(
            icon: Icons.calendar_month,
            title: 'Rendez-vous',
            children: [
              _qa(
                'Créer un rendez-vous',
                'Menu "Rendez-vous" → bouton "Nouveau RDV" → choisissez le '
                    'patient, la date, l\'heure et la durée → Enregistrer.',
              ),
              _qa(
                'Navigation par jour',
                'Flèches ← → en haut pour passer au jour précédent / suivant.',
              ),
              _qa(
                'Imprimer la liste du jour',
                'Bouton "Imprimer" en haut à droite de la liste des RDV → '
                    'une liste A4 avec tous les rendez-vous du jour s\'ouvre.',
              ),
              _qa(
                'Notifications de rappel',
                'À chaque ouverture de l\'application, une notification '
                    's\'affiche si vous avez des rendez-vous aujourd\'hui. '
                    'Pour un rappel quotidien automatique à 08:00 : '
                    'Réglages → Programmer rappel quotidien.',
              ),
            ],
          ),

          // ═════ Ordonnances ═════
          _section(
            icon: Icons.receipt_long,
            title: 'Ordonnances',
            children: [
              _qa(
                'Créer une ordonnance',
                'Ouvrez un patient → onglet "Infos" → bouton "Ordonnance" '
                    '→ ajoutez les médicaments (ou cliquez sur une suggestion '
                    'pour l\'ajouter directement) → Enregistrer et imprimer.',
              ),
              _qa(
                'Médicaments prédéfinis',
                'Des médicaments courants sont proposés (Amoxicilline, '
                    'Paracétamol, Ibuprofène, etc.) pour gagner du temps. '
                    'Cliquez simplement sur une puce pour l\'ajouter.',
              ),
              _qa(
                'Format d\'impression',
                'L\'ordonnance s\'imprime par défaut en A5 (format standard '
                    'ordonnance). Vous pouvez changer pour A4 dans la fenêtre '
                    'd\'impression.',
              ),
            ],
          ),

          // ═════ Radiographies ═════
          _section(
            icon: Icons.image,
            title: 'Radiographies',
            children: [
              _qa(
                'Ajouter une radiographie',
                'Patient → onglet "Infos" → bouton "Radiographies" → bouton '
                    '"Ajouter" (FAB) → sélectionnez un fichier image → '
                    'choisissez le type (panoramique, périapicale, CBCT, '
                    'autre).',
              ),
              _qa(
                'Consulter / supprimer',
                'Les images s\'affichent en grille. Appui long sur une image '
                    '→ confirmation de suppression.',
              ),
            ],
          ),

          // ═════ Odontogramme ═════
          _section(
            icon: Icons.grid_on,
            title: 'Schéma dentaire (Odontogramme)',
            children: [
              _qa(
                'À quoi ça sert ?',
                'Visualiser et annoter l\'état de chaque dent du patient. '
                    '32 dents adultes (FDI 18–48) ou 20 dents temporaires '
                    'pour enfants (51–85).',
              ),
              _qa(
                'Comment l\'utiliser',
                'Onglet "Schéma dentaire" d\'un patient → cliquez sur une '
                    'dent → choisissez son statut (carie, soin, couronne, '
                    'implant, extraction...) → Enregistrer. Les modifications '
                    'sont sauvegardées automatiquement.',
              ),
              _qa(
                'Changer Adulte / Enfant / Mixte',
                'En haut du schéma, trois boutons : Adulte (dents '
                    'permanentes), Enfant (dents temporaires 51–85), Mixte.',
              ),
            ],
          ),

          // ═════ Rapports ═════
          _section(
            icon: Icons.bar_chart,
            title: 'Rapports et recettes',
            children: [
              _qa(
                'Voir les recettes',
                'Menu "Recettes" (visible pour la réception/admin) → vous '
                    'verrez la recette du jour, du mois sélectionné, le total '
                    'restant à payer, et le détail des encaissements.',
              ),
              _qa(
                'Changer de mois',
                'Flèches ← → en haut à côté du nom du mois.',
              ),
              _qa(
                'Exporter vers Excel',
                'Boutons "Export jour CSV" et "Export mois CSV" → un fichier '
                    '.csv est enregistré dans le dossier Téléchargements. '
                    'Ouvrez-le avec Excel (le séparateur est le point-virgule).',
              ),
              _qa(
                'Recette par médecin',
                'Section "Recette du jour par médecin" liste les encaissements '
                    'du jour par praticien.',
              ),
            ],
          ),

          // ═════ Sauvegarde ═════
          _section(
            icon: Icons.backup,
            title: 'Sauvegarde et restauration',
            children: [
              _qa(
                'Sauvegarde automatique',
                'PocketBase sauvegarde automatiquement la base chaque jour '
                    'à 03:00 (configuré côté serveur). Les 30 dernières '
                    'sauvegardes sont conservées.',
              ),
              _qa(
                'Sauvegarde manuelle',
                'Réglages → "Sauvegarder maintenant". Une sauvegarde immédiate '
                    'est créée.',
              ),
              _qa(
                'Restaurer une sauvegarde',
                'Réglages → liste des sauvegardes → bouton "Restaurer" à '
                    'droite → confirmation. ⚠️ Les données actuelles seront '
                    'remplacées. Le serveur redémarrera automatiquement.',
              ),
            ],
          ),

          // ═════ Réseau ═════
          _section(
            icon: Icons.wifi,
            title: 'Réseau (Serveur / Client)',
            children: [
              _qa(
                'Comment ça marche',
                'Un seul poste est "Serveur" (généralement la réception) : '
                    'il héberge la base. Les autres postes sont "Clients" et '
                    's\'y connectent via le Wi-Fi ou le câble. Aucun accès '
                    'internet n\'est nécessaire.',
              ),
              _qa(
                'Configurer un client',
                'Sur le poste client : Réglages → Mode "Client" → saisir '
                    'l\'adresse IP du serveur (ex : http://192.168.1.10:8190) '
                    '→ Enregistrer → déconnectez-vous et reconnectez-vous.',
              ),
              _qa(
                'Trouver l\'IP du serveur',
                'Sur le poste serveur (Windows) : touche Windows + R → tapez '
                    '"cmd" → Entrée → tapez "ipconfig" → cherchez "Adresse '
                    'IPv4" (ex : 192.168.1.10).',
              ),
              _qa(
                'Pare-feu Windows',
                'Si les clients ne se connectent pas, autorisez le port '
                    '8190 dans le pare-feu Windows du serveur.',
              ),
            ],
          ),

          // ═════ FAQ ═════
          _section(
            icon: Icons.question_answer,
            title: 'Foire aux questions (FAQ)',
            children: [
              _qa(
                'J\'ai oublié mon mot de passe',
                'Seul un administrateur peut le réinitialiser depuis '
                    'PocketBase (http://IP:8190/_/ → collection users).',
              ),
              _qa(
                'Erreur "Identifiants invalides"',
                'Vérifiez l\'email et le mot de passe. Vérifiez aussi que '
                    'vous êtes connecté au bon serveur (mode Serveur ou '
                    'Client correct).',
              ),
              _qa(
                'Les autres postes ne voient pas les données',
                'Vérifiez que : 1) Le serveur est démarré. 2) Vous êtes sur '
                    'le même réseau Wi-Fi/câble. 3) L\'adresse IP est correcte. '
                    '4) Le pare-feu autorise le port 8190.',
              ),
              _qa(
                'Puis-je utiliser plusieurs médecins ?',
                'Oui, autant que nécessaire. Créez un utilisateur par médecin '
                    'avec le rôle "dentiste". Chaque acte sera automatiquement '
                    'associé au médecin connecté.',
              ),
              _qa(
                'Peut-on travailler hors ligne ?',
                'Oui, à 100 %. Aucune connexion internet n\'est nécessaire. '
                    'Seul le réseau local (Wi-Fi ou câble) est utilisé.',
              ),
              _qa(
                'Comment contacter le support ?',
                'Consultez l\'écran "À propos" pour les coordonnées du '
                    'développeur.',
              ),
            ],
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              'Pour plus d\'aide, contactez votre administrateur\n'
              'ou le développeur (voir "À propos").',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.teal),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: children,
      ),
    );
  }

  Widget _qa(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.help, size: 14, color: Colors.teal),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              answer,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}