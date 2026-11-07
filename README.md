# Voltora

Application Flutter de vente de produits électroniques avec API PHP/MySQL.

## Démarrer le backend avec XAMPP

1. Copie le dossier `backend` dans `C:\xampp\htdocs\voltora\backend`.
2. Démarre Apache et MySQL dans le panneau XAMPP.
3. Dans phpMyAdmin, importe `backend/schema.sql` pour créer la base et les
   articles de démonstration.
   Si la base Voltora existe déjà, applique une seule fois
   `backend/migrations/001_user_status_and_history.sql` et
   `backend/migrations/002_order_shipping_address.sql` et
   `backend/migrations/003_product_image_gallery.sql`,
   `backend/migrations/004_color_stock_and_cart_variants.sql` et
   `backend/migrations/005_product_categories.sql` depuis phpMyAdmin.
4. Copie `backend/config.example.php` vers `backend/config.local.php`, puis
   renseigne les accès MySQL et remplace `admin_setup_key` par une longue clé
   aléatoire que tu gardes secrète. Le fichier local est ignoré par Git.
5. Vérifie que `backend/public/uploads` est accessible en écriture par PHP et
   que `mod_rewrite` et `mod_headers` sont activés dans Apache. Les images
   statiques autorisent les requêtes cross-origin nécessaires au rendu Web.
   PHP doit également avoir les extensions `pdo_mysql`, `mbstring` et
   `fileinfo` activées.

Le point de santé de l’API est :
`http://localhost/voltora/backend/public/api/health`

## Lancer Flutter

Récupère les dépendances puis indique l’adresse correspondant à ta plateforme.
Par défaut, l’application utilise l’adresse locale adaptée à Chrome/Windows ;
les autres plateformes doivent préciser leur adresse avec `API_BASE_URL` :

```powershell
flutter pub get
# Navigateur ou application Flutter Windows
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost/voltora/backend/public/api
# Émulateur Android
flutter run --dart-define=API_BASE_URL=http://10.0.2.2/voltora/backend/public/api
```

Sur un téléphone physique, utilise l’adresse IP locale du PC à la place de
`10.0.2.2` et assure-toi que le téléphone peut accéder au serveur.
Les tests Android en mode debug autorisent HTTP pour le serveur local ; une
version de production doit utiliser HTTPS.

Pour ouvrir la version Web sur un téléphone connecté au même Wi-Fi, lance
Flutter avec `--web-hostname 0.0.0.0 --web-port 8080` et configure
`API_BASE_URL` avec l’adresse IP locale du PC. Génère ensuite le QR code avec
`dart run tool/generate_phone_qr.dart http://<IP-DU-PC>:8080/`. Le serveur
Flutter doit rester démarré, et l’adresse IP peut changer selon le réseau.

## Publier sur GitHub Pages

Le workflow `.github/workflows/deploy-pages.yml` publie Flutter Web sur GitHub
Pages. Avant son premier lancement, crée un dépôt GitHub et active **Settings →
Pages → GitHub Actions**. Ajoute ensuite la variable de dépôt `API_BASE_URL` avec
l’URL HTTPS publique de l’API, par exemple
`https://<hébergeur>/voltora/backend/public/api`. Le backend PHP/MySQL doit être
hébergé séparément de GitHub Pages, et son `cors_origin` doit autoriser l’origine
`https://<compte>.github.io`. Le workflow refuse de publier si `API_BASE_URL` est
absente ou n’utilise pas HTTPS.

## Compte administrateur et tableau de bord

Dans l’application, ouvre **Profil → Créer le compte administrateur**, puis
entre la clé configurée dans `backend/config.local.php`. Cette création initiale
n’est acceptée que lorsqu’aucun administrateur n’existe. Connecte-toi ensuite
avec ce compte et ouvre le tableau de bord depuis le profil.

Le tableau de bord permet de consulter/modifier/supprimer des utilisateurs,
choisir leur rôle, gérer les catégories en brouillon ou les publier, gérer les
articles (nom, catégorie, description, prix, stock, stock par couleur et jusqu’à
5 photos par article, envoyées depuis l’appareil ou ajoutées par URL) et
consulter les commandes et modifier leur statut. Pour configurer les couleurs,
saisis une couleur et son stock par ligne, par exemple `Noir: 5` et `Blanc: 0`
(indisponible). Les comptes, articles et commandes sont stockés dans MySQL et
partagés par les appareils qui utilisent cette même API.

Le paiement par carte reste une simulation : aucun débit n’est effectué et les
champs de carte fictifs ne sont jamais envoyés au serveur ni enregistrés. Avant
une mise en production, intègre un prestataire de paiement sécurisé, configure
HTTPS, restreins `cors_origin` à ton domaine, protège les sauvegardes et ne
distribue jamais la clé de création initiale. Les comptes créés avant la
migration locale ne sont pas transférés au serveur : ils doivent être recréés.

Le parcours de commande demande d’abord l’adresse de livraison, puis confirme
une simulation de paiement par carte. Les informations de livraison sont
enregistrées avec la commande ; les valeurs saisies dans le formulaire de carte
restent locales et sont ignorées par l’API.
