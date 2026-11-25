# DentaGest — Gestion de cabinet dentaire

## Pour l'utilisateur final (cabinet)

1. Lancer **DentaGest-Setup.exe** (Windows 10/11) → Suivant → Terminer.
2. Ouvrir DentaGest. Au premier lancement :
   - **Poste principal** : saisir le nom du cabinet. La base de données (PocketBase) est lancée et préparée
     **automatiquement**. Un compte administrateur est créé : **admin / admin123** (à changer ensuite).
   - **Poste secondaire** : saisir l'adresse du poste principal (affichée dans *Réglages → Ce poste*).
3. Connectez-vous avec `admin`, puis **Utilisateurs** → créez les comptes : **Dentiste**, **Réceptionniste** (ou Admin).

## Circuit d'un patient

1. **Réception** → *Salle d'attente* → « Enregistrer un patient » (nom, prénom, date de naissance…).
   Le patient est classé par heure d'arrivée ; son dossier est créé (ou retrouvé s'il existe déjà).
2. **Dentiste** → « Appeler » le patient suivant → « Dossier » : soins, actes et **prix de chaque acte**, ordonnance, RDV…
3. **Dentiste** → « Terminer → encaissement » (ou « Appeler la réception »).
   La réception reçoit une alerte (badge + message + son).
4. **Réception** → « Encaisser » : voit le montant dû, saisit le montant reçu (paiement partiel possible) ;
   le reste est calculé et conservé automatiquement.

Chaque acte (soin, extraction, détartrage…) a son propre prix et ses propres paiements.

## Fonctions

| Menu | Contenu |
|---|---|
| Accueil | Indicateurs du jour (selon le rôle), chaque carte ouvre sa fenêtre |
| Salle d'attente | Arrivées, appel dans l'ordre, consultation, encaissement, alertes |
| Patients / Rendez-vous | Dossiers, odontogramme, ordonnances, radios ; **carte de RDV** imprimable (une seule carte par patient) |
| Recettes | Journal de caisse jour / mois / année, export CSV (Excel), impression |
| Statistiques | Activité (actes, patients vus, nouveaux patients, RDV), graphiques, export / impression |
| Stock | Anesthésiques, seringues, consommables, matériel : entrées, sorties, inventaire, alertes de seuil |
| Paramétrage | Informations du cabinet et **logo du cabinet** (affiché dans l'application et sur les documents) |
| Utilisateurs | Création / modification des comptes (admin) |
| Réglages | Mot de passe, adresse réseau, sauvegardes (auto quotidienne + copie USB) |

## Données

`%APPDATA%\<...>\database\pb_data` sur le poste principal (jamais supprimées à la désinstallation).

## Pour le développeur

- Flutter 3.24 ; PocketBase **0.22.x** (version fixée dans `.github/workflows/build.yml`), port **8090**.
- Compte technique interne de PocketBase : `admin@clinic.local` / `admin12345` (voir `server_manager.dart`).
  Si un autre PocketBase tourne déjà sur le port 8090, créez-y ce compte ou fermez-le.
- `lib/services/db_schema.dart` : toutes les collections ; tout champ / collection ajouté est appliqué au démarrage suivant.
- Le build GitHub produit `DentaGest-Setup.exe`, `DentaGest-Portable.zip` et l'APK Android (poste secondaire).
- Icônes : `assets/` (logo, `app_icon.ico`, icônes Android), appliquées par le workflow / `scripts/patch_android.py`.
