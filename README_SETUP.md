# Cabinet Dentaire — Installation et développement

## Pour l'utilisateur final (cabinet)

1. Lancer **CabinetDentaire-Setup.exe** (Windows 10/11) → Suivant → Terminer.
2. Ouvrir « Cabinet Dentaire ». Au premier lancement, l'assistant demande :
   - **Poste principal** : nom du cabinet + compte administrateur (identifiant / mot de passe).
     La base de données (PocketBase) est lancée et préparée **automatiquement**.
   - **Poste secondaire** : adresse du poste principal (affichée dans *Réglages → Ce poste*).
3. L'administrateur crée ensuite les comptes dans le menu **Utilisateurs** en choisissant
   simplement le type : **Dentiste** ou **Réceptionniste**.

Aucune manipulation de PocketBase n'est nécessaire.

### Où sont les données ?
`%APPDATA%\<...>\database\pb_data` sur le poste principal (jamais supprimées à la désinstallation).
Sauvegardes : automatiques (1/jour, 30 conservées) + manuelles, avec copie vers clé USB depuis *Réglages*.

## Pour le développeur

- Flutter stable ≥ 3.24 ; PocketBase **0.22.x** (version fixée dans `.github/workflows/build.yml`).
- Le build GitHub produit : `CabinetDentaire-Setup.exe` (installateur Inno Setup, règle pare-feu incluse),
  `CabinetDentaire-Portable.zip` et l'APK Android (poste secondaire uniquement).
- `lib/services/server_manager.dart` : lance/arrête `dental_db.exe` (PocketBase renommé), compte admin interne aléatoire.
- `lib/services/db_schema.dart` + `db_bootstrap.dart` : création / mise à jour automatique des collections et règles.
  Pour ajouter un champ ou une collection : modifier `db_schema.dart` — il est appliqué au démarrage suivant.
- En développement : placer `pocketbase.exe` (0.22.x) dans `./pocketbase/`.

## Rôles
| Rôle | Accès |
|---|---|
| Administrateur | tout + gestion des utilisateurs + suppression |
| Dentiste | patients, actes, ordonnances, radios, RDV |
| Réceptionniste | idem + recettes / paiements |

> Port de la base embarquée : **8190** (volontairement différent du 8090 par défaut de PocketBase).
