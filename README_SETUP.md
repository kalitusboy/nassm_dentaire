# Installation

1. Flutter stable ≥ 3.22
2. flutter pub get
3. Télécharger PocketBase Windows depuis https://pocketbase.io/docs/
   → placer l'exe dans ./pocketbase/
4. Lancer : pocketbase/pocketbase.exe serve --http=0.0.0.0:8090
5. Ouvrir http://localhost:8090/_/ → créer admin

## Collections PocketBase

### users (built-in) — ajouter :
- nom (text), prenom (text), role (select: admin, dentiste, reception)

### patients
numero_dossier(text, unique), nom, prenom, date_naissance(date),
telephone, adresse, allergies, notes_medicales

### actes
patient(rel→patients), medecin(rel→users), type(select: examen,
detartrage, soin_carie, extraction, endodontie, couronne, bridge,
implant, prothese, autre), dent(number), date(date), description,
montant_total(number), statut(select: planifie, en_cours, termine, annule)

### paiements
acte(rel→actes), patient(rel→patients), montant(number),
date(date), methode(select: espece, cheque, carte, virement), notes

### rendez_vous
patient(rel→patients), medecin(rel→users), date_heure(date),
duree_minutes(number), motif(text), statut(select: planifie,
confirme, termine, annule)

### ordonnances
patient(rel→patients), medecin(rel→users), date(date),
medicaments(json), instructions(text)

### radiographies
patient(rel→patients), acte(rel→actes), fichier(file),
type(select: panoramique, periapicale, cbct, autre), date(date), notes

### parametres
nom_clinique, titre_praticien, adresse, telephone, email, numero_ordre

### odontogrammes
patient(rel→patients, unique), dents(json)

## API Rules (toutes) :
List/View/Create/Update : @request.auth.id != ""
Delete : @request.auth.role = "admin"

## Backups automatiques
Settings → Backups → Cron "0 3 * * *", Max keep 30