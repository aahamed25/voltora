<?php

declare(strict_types=1);

$runtime = require dirname(__DIR__) . '/config.php';
$pdo = $runtime['pdo'];
$settings = $runtime['settings'];

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: ' . ($settings['cors_origin'] ?? '*'));
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Admin-Setup-Key');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');

function respond(int $status, array $payload): void
{
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function read_input(): array
{
    if (isset($_POST) && count($_POST) > 0) {
        return $_POST;
    }
    $raw = file_get_contents('php://input');
    if ($raw === false || $raw === '') {
        return [];
    }
    $decoded = json_decode($raw, true);
    if (!is_array($decoded)) {
        respond(400, ['error' => 'Corps JSON invalide.']);
    }
    return $decoded;
}

function required_string(array $input, string $key, int $maxLength): string
{
    $value = trim((string)($input[$key] ?? ''));
    if ($value === '' || mb_strlen($value) > $maxLength) {
        respond(422, ['error' => "Champ invalide : $key."]);
    }
    return $value;
}

function canonical_category_key(string $category): string
{
    $normalized = mb_strtolower(trim($category));
    return match ($normalized) {
        'mobile', 'mobiles', 'smartphone', 'smartphones' => 'smartphones',
        'ordinateur', 'ordinateurs' => 'ordinateurs',
        'tablette', 'tablettes' => 'tablettes',
        'casque', 'casques' => 'casques',
        'enceinte', 'enceintes' => 'enceintes',
        'montre', 'montres' => 'montres',
        default => $normalized,
    };
}

function validated_password(array $input): string
{
    $password = (string)($input['password'] ?? '');
    if (strlen($password) < 8 || strlen($password) > 200) {
        respond(422, ['error' => 'Le mot de passe doit contenir entre 8 et 200 caractères.']);
    }
    return $password;
}

function valid_date(string $date): bool
{
    $parsed = DateTimeImmutable::createFromFormat('!Y-m-d', $date);
    return $parsed !== false && $parsed->format('Y-m-d') === $date;
}

function bearer_token(): ?string
{
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if ($header === '' && function_exists('getallheaders')) {
        $headers = getallheaders();
        $header = $headers['Authorization'] ?? $headers['authorization'] ?? '';
    }
    return preg_match('/^Bearer\s+([a-f0-9]{64})$/i', $header, $matches)
        ? $matches[1]
        : null;
}

function current_user(PDO $pdo): array
{
    $token = bearer_token();
    if ($token === null) {
        respond(401, ['error' => 'Connectez-vous pour continuer.']);
    }

    $query = $pdo->prepare(
        'SELECT u.id, u.nom, u.prenom, u.birth_date, u.phone, u.email, u.username, u.role,
                u.is_active
         FROM api_tokens t
         JOIN users u ON u.id = t.user_id
         WHERE t.token_hash = ? AND t.expires_at > UTC_TIMESTAMP() AND u.is_active = 1'
    );
    $query->execute([hash('sha256', $token)]);
    $user = $query->fetch();
    if (!$user) {
        respond(401, ['error' => 'Session expirée. Reconnectez-vous.']);
    }
    return $user;
}

function require_admin(PDO $pdo): array
{
    $user = current_user($pdo);
    if ($user['role'] !== 'admin') {
        respond(403, ['error' => 'Accès réservé à un administrateur.']);
    }
    return $user;
}

function public_user(array $user): array
{
    return [
        'id' => (string)$user['id'],
        'nom' => $user['nom'],
        'prenom' => $user['prenom'],
        'birthDate' => $user['birth_date'],
        'phone' => $user['phone'],
        'email' => $user['email'],
        'username' => $user['username'],
        'isAdmin' => $user['role'] === 'admin',
        'isActive' => (bool)($user['is_active'] ?? true),
    ];
}

function log_admin_user_action(
    PDO $pdo,
    int $adminId,
    int $targetId,
    string $targetEmail,
    string $action,
    array $details = []
): void {
    $query = $pdo->prepare(
        'INSERT INTO admin_user_actions
            (target_user_id, target_email, admin_user_id, action, details)
         VALUES (?, ?, ?, ?, ?)'
    );
    $query->execute([
        $targetId,
        $targetEmail,
        $adminId,
        $action,
        $details === [] ? null : json_encode($details, JSON_UNESCAPED_UNICODE),
    ]);
}

function record_login(PDO $pdo, int $userId, string $email, bool $succeeded): void
{
    $history = $pdo->prepare(
        'INSERT INTO login_history (user_id, email, succeeded) VALUES (?, ?, ?)'
    );
    $history->execute([$userId, $email, $succeeded ? 1 : 0]);
    if ($succeeded) {
        $update = $pdo->prepare(
            'UPDATE users SET last_login_at = UTC_TIMESTAMP() WHERE id = ?'
        );
        $update->execute([$userId]);
    }
}

function issue_token(PDO $pdo, int $userId): string
{
    $token = bin2hex(random_bytes(32));
    $query = $pdo->prepare(
        'INSERT INTO api_tokens (user_id, token_hash, expires_at)
         VALUES (?, ?, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 30 DAY))'
    );
    $query->execute([$userId, hash('sha256', $token)]);
    return $token;
}

function product_row(array $row): array
{
    $imageUrls = is_string($row['image_urls'] ?? null)
        ? json_decode($row['image_urls'], true)
        : ($row['image_urls'] ?? null);
    if (!is_array($imageUrls)) {
        $imageUrls = [];
    }
    $imageUrls = array_values(array_filter(
        $imageUrls,
        static fn($url): bool => is_string($url) && $url !== ''
    ));
    if ($imageUrls === [] && !empty($row['image_url'])) {
        $imageUrls[] = $row['image_url'];
    }

    $specs = is_string($row['specs'])
        ? json_decode($row['specs'])
        : $row['specs'];
    if (!is_object($specs)) {
        $specs = new stdClass();
    }
    $colorStock = is_string($row['color_stock'] ?? null)
        ? json_decode($row['color_stock'], true)
        : ($row['color_stock'] ?? []);
    if (!is_array($colorStock)) {
        $colorStock = [];
    }

    return [
        'id' => (int)$row['id'],
        'name' => $row['name'],
        'brand' => $row['brand'],
        'category' => $row['category'],
        'description' => $row['description'],
        'price' => (float)$row['price'],
        'promo_price' => $row['promo_price'] === null ? null : (float)$row['promo_price'],
        'stock' => (int)$row['stock'],
        'color_stock' => (object)$colorStock,
        'rating' => (float)$row['rating'],
        'reviews' => (int)$row['reviews'],
        'icon' => $row['icon'],
        'image_url' => $imageUrls[0] ?? null,
        'image_urls' => $imageUrls,
        'specs' => $specs,
    ];
}

function product_values(array $input, array $settings): array
{
    $name = required_string($input, 'name', 180);
    $brand = required_string($input, 'brand', 120);
    $category = required_string($input, 'category', 100);
    $description = required_string($input, 'description', 10000);
    $price = filter_var($input['price'] ?? null, FILTER_VALIDATE_FLOAT);
    $promoPriceInput = trim((string)($input['promo_price'] ?? ''));
    $promoPrice = $promoPriceInput === ''
        ? null
        : filter_var($promoPriceInput, FILTER_VALIDATE_FLOAT);
    $stock = filter_var($input['stock'] ?? null, FILTER_VALIDATE_INT);
    if ($price === false || $price < 0 || ($promoPriceInput !== '' && ($promoPrice === false || $promoPrice < 0)) || $stock === false || $stock < 0) {
        respond(422, ['error' => 'Prix ou stock invalide.']);
    }
    if ($promoPrice !== null && $promoPrice > $price) {
        respond(422, ['error' => 'Le prix promotionnel ne peut pas dépasser le prix normal.']);
    }

    $colorStock = $input['color_stock'] ?? [];
    if (is_string($colorStock)) {
        $colorStock = json_decode($colorStock, true);
    }
    if (!is_array($colorStock) || ($colorStock !== [] && array_is_list($colorStock))) {
        respond(422, ['error' => 'Le stock par couleur doit être un objet.']);
    }
    $normalizedColorStock = [];
    $totalColorStock = 0;
    foreach ($colorStock as $color => $quantity) {
        if (!is_string($color) || trim($color) === '' || strlen($color) > 80) {
            respond(422, ['error' => 'Nom de couleur invalide.']);
        }
        $quantity = filter_var($quantity, FILTER_VALIDATE_INT);
        if ($quantity === false || $quantity < 0) {
            respond(422, ['error' => 'Stock de couleur invalide.']);
        }
        $normalizedColorStock[trim($color)] = $quantity;
        $totalColorStock += $quantity;
    }
    if ($totalColorStock > $stock) {
        respond(422, ['error' => 'Le stock des couleurs dépasse le stock du produit.']);
    }

    $specs = $input['specs'] ?? '{}';
    if (is_string($specs)) {
        $specs = json_decode($specs, true);
    }
    if (!is_array($specs)) {
        respond(422, ['error' => 'Les caractéristiques doivent être un objet JSON.']);
    }

    if (array_key_exists('image_urls', $input)) {
        $imageUrls = $input['image_urls'];
        if (is_string($imageUrls)) {
            $imageUrls = json_decode($imageUrls, true);
        }
        if (!is_array($imageUrls) || !array_is_list($imageUrls)) {
            respond(422, ['error' => 'La galerie doit être une liste d’URL.']);
        }
    } else {
        $legacyImageUrl = trim((string)($input['image_url'] ?? ''));
        $imageUrls = $legacyImageUrl === '' ? [] : [$legacyImageUrl];
    }

    $normalizedImageUrls = [];
    foreach ($imageUrls as $imageUrl) {
        if (!is_string($imageUrl)) {
            respond(422, ['error' => 'Chaque photo doit être une URL valide.']);
        }
        $imageUrl = trim($imageUrl);
        $parts = parse_url($imageUrl);
        $isStoredUploadPath = str_starts_with($imageUrl, '/') &&
            !str_starts_with($imageUrl, '//') &&
            !str_contains($imageUrl, '..') &&
            !str_contains($imageUrl, '\\');
        $isWebUrl = filter_var($imageUrl, FILTER_VALIDATE_URL) &&
            in_array(strtolower($parts['scheme'] ?? ''), ['https', 'http'], true);
        if ($imageUrl === '' || (!$isStoredUploadPath && !$isWebUrl)) {
            respond(422, ['error' => 'Chaque photo doit avoir une URL valide ou provenir du serveur.']);
        }
        $normalizedImageUrls[] = $imageUrl;
    }
    $imageUrls = $normalizedImageUrls;

    $uploadedFiles = product_image_uploads();
    if (!array_key_exists('image_urls', $input) &&
        isset($_FILES['image']) &&
        $_FILES['image']['error'] !== UPLOAD_ERR_NO_FILE) {
        $imageUrls = [];
    }
    if (count($imageUrls) + count($uploadedFiles) > 5) {
        respond(422, ['error' => 'Un article peut contenir 5 photos maximum.']);
    }
    foreach ($uploadedFiles as $file) {
        $imageUrls[] = store_product_image($file);
    }

    return [
        $name,
        $brand,
        $category,
        $description,
        $price,
        $promoPrice,
        $stock,
        json_encode($normalizedColorStock, JSON_UNESCAPED_UNICODE),
        required_string($input + ['icon' => 'devices'], 'icon', 60),
        $imageUrls[0] ?? null,
        json_encode($imageUrls, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
        json_encode($specs, JSON_UNESCAPED_UNICODE),
    ];
}

function product_image_uploads(): array
{
    if (!isset($_FILES['images'])) {
        if (!isset($_FILES['image']) || $_FILES['image']['error'] === UPLOAD_ERR_NO_FILE) {
            return [];
        }
        return [$_FILES['image']];
    }

    $files = $_FILES['images'];
    if (!is_array($files['name'] ?? null)) {
        respond(422, ['error' => 'Les photos envoyées sont invalides.']);
    }

    $uploads = [];
    foreach ($files['name'] as $index => $name) {
        $error = $files['error'][$index] ?? UPLOAD_ERR_NO_FILE;
        if ($error === UPLOAD_ERR_NO_FILE) {
            continue;
        }
        $uploads[] = [
            'name' => $name,
            'type' => $files['type'][$index] ?? '',
            'tmp_name' => $files['tmp_name'][$index] ?? '',
            'error' => $error,
            'size' => $files['size'][$index] ?? 0,
        ];
    }
    return $uploads;
}

function store_product_image(array $file): string
{
    if ($file['error'] !== UPLOAD_ERR_OK || $file['size'] > 8 * 1024 * 1024) {
        respond(422, ['error' => 'Image invalide ou supérieure à 8 Mo.']);
    }
    $mime = (new finfo(FILEINFO_MIME_TYPE))->file($file['tmp_name']);
    $extensions = [
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
    ];
    if (!isset($extensions[$mime]) || getimagesize($file['tmp_name']) === false) {
        respond(422, ['error' => 'Formats autorisés : JPEG, PNG ou WebP.']);
    }

    $uploadDir = __DIR__ . '/uploads';
    if (!is_dir($uploadDir) && !mkdir($uploadDir, 0755, true) && !is_dir($uploadDir)) {
        respond(500, ['error' => 'Impossible de créer le dossier des images.']);
    }
    $filename = bin2hex(random_bytes(16)) . '.' . $extensions[$mime];
    if (!move_uploaded_file($file['tmp_name'], $uploadDir . '/' . $filename)) {
        respond(500, ['error' => 'Impossible d’enregistrer l’image.']);
    }

    $basePath = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
    return "$basePath/uploads/$filename";
}

function find_product(PDO $pdo, int $id): array
{
    $query = $pdo->prepare('SELECT * FROM products WHERE id = ?');
    $query->execute([$id]);
    $row = $query->fetch();
    if (!$row) {
        respond(404, ['error' => 'Article introuvable.']);
    }
    return $row;
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

$requestPath = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$scriptDirectory = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
if ($scriptDirectory !== '' && str_starts_with($requestPath, $scriptDirectory)) {
    $requestPath = substr($requestPath, strlen($scriptDirectory));
}
$route = trim(preg_replace('#^/index\.php#', '', $requestPath), '/');
if (str_starts_with($route, 'api/')) {
    $route = substr($route, 4);
}
$segments = $route === '' ? [] : explode('/', $route);
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$input = read_input();

try {
    if ($method === 'GET' && $segments === ['health']) {
        respond(200, ['ok' => true]);
    }

    if ($method === 'GET' && $segments === ['categories']) {
        $rows = $pdo->query(
            'SELECT name FROM product_categories WHERE is_published = 1 ORDER BY name'
        )->fetchAll(PDO::FETCH_COLUMN);
        respond(200, ['categories' => array_map('strval', $rows)]);
    }

    if ($method === 'GET' && $segments === ['auth', 'admin-setup-status']) {
        $adminCount = (int)$pdo->query(
            "SELECT COUNT(*) FROM users WHERE role = 'admin'"
        )->fetchColumn();
        respond(200, ['available' => $adminCount === 0]);
    }

    if ($method === 'POST' && $segments === ['auth', 'register']) {
        $birthDate = required_string($input, 'birth_date', 10);
        if (!valid_date($birthDate)) {
            respond(422, ['error' => 'Date de naissance invalide.']);
        }
        $values = [
            required_string($input, 'nom', 120),
            required_string($input, 'prenom', 120),
            $birthDate,
            required_string($input, 'phone', 40),
            strtolower(required_string($input, 'email', 254)),
            required_string($input, 'username', 80),
            password_hash(validated_password($input), PASSWORD_DEFAULT),
            'user',
        ];
        if (!filter_var($values[4], FILTER_VALIDATE_EMAIL)) {
            respond(422, ['error' => 'Adresse e-mail invalide.']);
        }
        $insert = $pdo->prepare(
            'INSERT INTO users (nom, prenom, birth_date, phone, email, username, password_hash, role)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
        );
        try {
            $insert->execute($values);
        } catch (PDOException $exception) {
            if ($exception->getCode() === '23000') {
                respond(409, ['error' => 'Cet e-mail ou cet identifiant est déjà utilisé.']);
            }
            throw $exception;
        }
        $userId = (int)$pdo->lastInsertId();
        $query = $pdo->prepare('SELECT * FROM users WHERE id = ?');
        $query->execute([$userId]);
        $user = $query->fetch();
        record_login($pdo, $userId, $user['email'], true);
        respond(201, ['user' => public_user($user), 'token' => issue_token($pdo, $userId)]);
    }

    if ($method === 'POST' && $segments === ['auth', 'first-admin']) {
        $configuredKey = (string)($settings['admin_setup_key'] ?? '');
        $providedKey = (string)($_SERVER['HTTP_X_ADMIN_SETUP_KEY'] ?? '');
        if ($configuredKey === '' || $configuredKey === 'replace-with-a-long-random-secret' ||
            !hash_equals($configuredKey, $providedKey)) {
            respond(403, ['error' => 'Clé de création initiale invalide.']);
        }
        $lock = $pdo->query("SELECT GET_LOCK('voltora_first_admin', 10)")->fetchColumn();
        if ((int)$lock !== 1) {
            respond(503, ['error' => 'Création administrateur déjà en cours. Réessayez.']);
        }
        try {
            if ((int)$pdo->query("SELECT COUNT(*) FROM users WHERE role = 'admin'")->fetchColumn() > 0) {
                respond(409, ['error' => 'Un administrateur existe déjà.']);
            }
            $email = strtolower(required_string($input, 'email', 254));
            if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
                respond(422, ['error' => 'Adresse e-mail invalide.']);
            }
            $insert = $pdo->prepare(
                "INSERT INTO users (nom, prenom, birth_date, phone, email, username, password_hash, role)
                 VALUES (?, ?, ?, ?, ?, ?, ?, 'admin')"
            );
            try {
                $birthDate = required_string($input, 'birth_date', 10);
                if (!valid_date($birthDate)) {
                    respond(422, ['error' => 'Date de naissance invalide.']);
                }
                $insert->execute([
                    required_string($input, 'nom', 120),
                    required_string($input, 'prenom', 120),
                    $birthDate,
                    required_string($input, 'phone', 40),
                    $email,
                    required_string($input, 'username', 80),
                    password_hash(validated_password($input), PASSWORD_DEFAULT),
                ]);
            } catch (PDOException $exception) {
                if ($exception->getCode() === '23000') {
                    respond(409, ['error' => 'Cet e-mail ou cet identifiant est déjà utilisé.']);
                }
                throw $exception;
            }
            $userId = (int)$pdo->lastInsertId();
            $query = $pdo->prepare('SELECT * FROM users WHERE id = ?');
            $query->execute([$userId]);
            $user = $query->fetch();
            record_login($pdo, $userId, $user['email'], true);
            respond(201, ['user' => public_user($user), 'token' => issue_token($pdo, $userId)]);
        } finally {
            $pdo->query("SELECT RELEASE_LOCK('voltora_first_admin')");
        }
    }

    if ($method === 'POST' && $segments === ['auth', 'login']) {
        $identifier = mb_strtolower(trim((string)($input['identifier'] ?? '')));
        $query = $pdo->prepare(
            'SELECT * FROM users WHERE LOWER(email) = ? OR LOWER(username) = ? LIMIT 1'
        );
        $query->execute([$identifier, $identifier]);
        $user = $query->fetch();
        if ($user) {
            $passwordValid = password_verify(
                (string)($input['password'] ?? ''),
                $user['password_hash']
            );
            $succeeded = $passwordValid && (bool)$user['is_active'];
            record_login($pdo, (int)$user['id'], $user['email'], $succeeded);
        } else {
            $passwordValid = false;
        }
        if (!$user || !$passwordValid || !(bool)$user['is_active']) {
            respond(401, ['error' => 'Identifiant ou mot de passe incorrect.']);
        }
        $token = issue_token($pdo, (int)$user['id']);
        respond(200, ['user' => public_user($user), 'token' => $token]);
    }

    if ($method === 'GET' && $segments === ['auth', 'me']) {
        respond(200, ['user' => public_user(current_user($pdo))]);
    }

    if ($method === 'POST' && $segments === ['auth', 'logout']) {
        $token = bearer_token();
        if ($token !== null) {
            $delete = $pdo->prepare('DELETE FROM api_tokens WHERE token_hash = ?');
            $delete->execute([hash('sha256', $token)]);
        }
        respond(200, ['ok' => true]);
    }

    if ($method === 'GET' && $segments === ['products']) {
        $rows = $pdo->query('SELECT * FROM products ORDER BY id DESC')->fetchAll();
        respond(200, ['products' => array_map('product_row', $rows)]);
    }

    if ($segments === ['favorites'] && $method === 'GET') {
        $user = current_user($pdo);
        $query = $pdo->prepare('SELECT product_id FROM favorites WHERE user_id = ?');
        $query->execute([$user['id']]);
        respond(200, ['ids' => array_map('intval', $query->fetchAll(PDO::FETCH_COLUMN))]);
    }
    if (count($segments) === 2 && $segments[0] === 'favorites' &&
        in_array($method, ['POST', 'DELETE'], true)) {
        $user = current_user($pdo);
        $productId = filter_var($segments[1], FILTER_VALIDATE_INT);
        if ($productId === false) {
            respond(400, ['error' => 'Article invalide.']);
        }
        find_product($pdo, $productId);
        $query = $method === 'POST'
            ? $pdo->prepare('INSERT IGNORE INTO favorites (user_id, product_id) VALUES (?, ?)')
            : $pdo->prepare('DELETE FROM favorites WHERE user_id = ? AND product_id = ?');
        $query->execute([$user['id'], $productId]);
        respond(200, ['ok' => true]);
    }

    if ($segments === ['cart'] && $method === 'GET') {
        $user = current_user($pdo);
        $query = $pdo->prepare(
            'SELECT p.*, c.quantity, c.color FROM cart_items c
             JOIN products p ON p.id = c.product_id WHERE c.user_id = ?'
        );
        $query->execute([$user['id']]);
        $items = array_map(
            fn(array $row): array => product_row($row) + [
                'quantity' => (int)$row['quantity'],
                'color' => $row['color'],
            ],
            $query->fetchAll()
        );
        respond(200, ['items' => $items]);
    }
    if (count($segments) === 2 && $segments[0] === 'cart' &&
        in_array($method, ['PUT', 'DELETE'], true)) {
        $user = current_user($pdo);
        $productId = filter_var($segments[1], FILTER_VALIDATE_INT);
        if ($productId === false) {
            respond(400, ['error' => 'Article invalide.']);
        }
        if ($method === 'DELETE') {
            $color = trim((string)($_GET['color'] ?? ''));
            $query = $pdo->prepare(
                'DELETE FROM cart_items WHERE user_id = ? AND product_id = ? AND color = ?'
            );
            $query->execute([$user['id'], $productId, $color]);
            respond(200, ['ok' => true]);
        }
        $product = find_product($pdo, $productId);
        $quantity = filter_var($input['quantity'] ?? null, FILTER_VALIDATE_INT);
        $color = trim((string)($input['color'] ?? ''));
        $colorStock = is_string($product['color_stock'] ?? null)
            ? json_decode($product['color_stock'], true)
            : ($product['color_stock'] ?? []);
        if (!is_array($colorStock)) {
            $colorStock = [];
        }
        if ($colorStock !== []) {
            if ($color === '') {
                respond(422, ['error' => 'Choisis une couleur pour cet article.']);
            }
            if (!array_key_exists($color, $colorStock) || (int)$colorStock[$color] < 1) {
                respond(409, ['error' => 'Cette couleur n’est plus disponible.']);
            }
            if ($quantity !== false && $quantity > (int)$colorStock[$color]) {
                respond(422, ['error' => 'Stock insuffisant pour cette couleur.']);
            }
        } elseif ($color !== '') {
            respond(409, ['error' => 'Cette couleur n’est plus disponible.']);
        }
        if ($quantity === false || $quantity < 1 || $quantity > (int)$product['stock']) {
            respond(422, ['error' => 'Quantité invalide ou stock insuffisant.']);
        }
        $query = $pdo->prepare(
            'INSERT INTO cart_items (user_id, product_id, color, quantity) VALUES (?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE quantity = VALUES(quantity)'
        );
        $query->execute([$user['id'], $productId, $color, $quantity]);
        respond(200, ['ok' => true]);
    }

    if ($segments === ['orders'] && $method === 'GET') {
        $user = current_user($pdo);
        $query = $pdo->prepare('SELECT * FROM orders WHERE user_id = ? ORDER BY id DESC');
        $query->execute([$user['id']]);
        respond(200, ['orders' => $query->fetchAll()]);
    }
    if ($segments === ['orders'] && $method === 'POST') {
        $user = current_user($pdo);
        $shipping = $input['shipping'] ?? null;
        if (!is_array($shipping)) {
            respond(422, ['error' => 'Les informations de livraison sont requises.']);
        }
        $shippingValues = [
            required_string($shipping, 'nom', 120),
            required_string($shipping, 'prenom', 120),
            required_string($shipping, 'address', 240),
            required_string($shipping, 'postal_code', 12),
            required_string($shipping, 'city', 100),
        ];
        $items = $input['items'] ?? null;
        if (!is_array($items) || count($items) === 0) {
            respond(422, ['error' => 'La commande ne contient aucun article.']);
        }
        $pdo->beginTransaction();
        try {
            $total = 0.0;
            $count = 0;
            $validated = [];
            $lockedProducts = [];
            $productQuantities = [];
            $variantQuantities = [];
            $getProduct = $pdo->prepare('SELECT * FROM products WHERE id = ? FOR UPDATE');
            foreach ($items as $item) {
                if (!is_array($item)) {
                    respond(422, ['error' => 'Article invalide.']);
                }
                $productId = filter_var($item['product_id'] ?? null, FILTER_VALIDATE_INT);
                $quantity = filter_var($item['quantity'] ?? null, FILTER_VALIDATE_INT);
                if ($productId === false || $quantity === false || $quantity < 1) {
                    respond(422, ['error' => 'Article ou quantité invalide.']);
                }
                if (!array_key_exists($productId, $lockedProducts)) {
                    $getProduct->execute([$productId]);
                    $lockedProducts[$productId] = $getProduct->fetch();
                }
                $product = $lockedProducts[$productId];
                if (!$product) {
                    respond(409, ['error' => 'Un article est indisponible ou en stock insuffisant.']);
                }
                $color = trim((string)($item['color'] ?? ''));
                $colorStock = is_string($product['color_stock'] ?? null)
                    ? json_decode($product['color_stock'], true)
                    : ($product['color_stock'] ?? []);
                if (!is_array($colorStock)) {
                    $colorStock = [];
                }
                if ($colorStock !== []) {
                    if ($color === '') {
                        respond(409, ['error' => 'Choisis une couleur pour cet article.']);
                    }
                    if (!array_key_exists($color, $colorStock)) {
                        respond(409, ['error' => 'Cette couleur n’est plus disponible.']);
                    }
                    $variantKey = $productId . "\0" . $color;
                    $variantQuantities[$variantKey] =
                        ($variantQuantities[$variantKey] ?? 0) + $quantity;
                    if ($variantQuantities[$variantKey] > (int)$colorStock[$color]) {
                        respond(409, ['error' => 'Stock insuffisant pour cette couleur.']);
                    }
                } elseif ($color !== '') {
                    respond(409, ['error' => 'Cette couleur n’est plus disponible.']);
                }
                $productQuantities[$productId] =
                    ($productQuantities[$productId] ?? 0) + $quantity;
                if ($productQuantities[$productId] > (int)$product['stock']) {
                    respond(409, ['error' => 'Un article est indisponible ou en stock insuffisant.']);
                }
                $price = $product['promo_price'] === null
                    ? (float)$product['price']
                    : (float)$product['promo_price'];
                $total += $price * $quantity;
                $count += $quantity;
                $validated[] = [$product, $quantity, $price, $color];
            }

            $number = 'CMD-' . strtoupper(bin2hex(random_bytes(5)));
            $insertOrder = $pdo->prepare(
                "INSERT INTO orders
                    (number, user_id, total, item_count, shipping_nom, shipping_prenom,
                     shipping_address, shipping_postal_code, shipping_city, status)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'En préparation')"
            );
            $insertOrder->execute([
                $number,
                $user['id'],
                $total,
                $count,
                ...$shippingValues,
            ]);
            $orderId = (int)$pdo->lastInsertId();
            $insertItem = $pdo->prepare(
                'INSERT INTO order_items (order_id, product_id, product_name, color, quantity, unit_price)
                 VALUES (?, ?, ?, ?, ?, ?)'
            );
            foreach ($validated as [$product, $quantity, $price, $color]) {
                $insertItem->execute([
                    $orderId,
                    $product['id'],
                    $product['name'],
                    $color,
                    $quantity,
                    $price,
                ]);
                $deleteCart = $pdo->prepare(
                    'DELETE FROM cart_items WHERE user_id = ? AND product_id = ? AND color = ?'
                );
                $deleteCart->execute([$user['id'], $product['id'], $color]);
            }
            $updateStock = $pdo->prepare(
                'UPDATE products SET stock = stock - ?, color_stock = ? WHERE id = ?'
            );
            foreach ($productQuantities as $productId => $quantity) {
                $product = $lockedProducts[$productId];
                $colorStock = is_string($product['color_stock'] ?? null)
                    ? json_decode($product['color_stock'], true)
                    : ($product['color_stock'] ?? []);
                if (!is_array($colorStock)) {
                    $colorStock = [];
                }
                foreach ($validated as [$itemProduct, $itemQuantity, $price, $color]) {
                    if ((int)$itemProduct['id'] === (int)$productId && $color !== '') {
                        $colorStock[$color] -= $itemQuantity;
                    }
                }
                $updateStock->execute([
                    $quantity,
                    json_encode((object)$colorStock, JSON_UNESCAPED_UNICODE),
                    $productId,
                ]);
            }
            $pdo->commit();
            respond(201, [
                'order' => [
                    'number' => $number,
                    'total' => $total,
                    'item_count' => $count,
                    'status' => 'En préparation',
                    'created_at' => gmdate('Y-m-d H:i:s'),
                    'shipping_nom' => $shippingValues[0],
                    'shipping_prenom' => $shippingValues[1],
                    'shipping_address' => $shippingValues[2],
                    'shipping_postal_code' => $shippingValues[3],
                    'shipping_city' => $shippingValues[4],
                ],
            ]);
        } catch (Throwable $exception) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $exception;
        }
    }

    if (str_starts_with(implode('/', $segments), 'admin/')) {
        require_admin($pdo);
    }

    if ($segments === ['admin', 'categories'] && $method === 'GET') {
        $rows = $pdo->query(
            'SELECT id, name, is_published FROM product_categories ORDER BY name'
        )->fetchAll();
        respond(200, ['categories' => array_map(
            static fn(array $category): array => [
                'id' => (int)$category['id'],
                'name' => $category['name'],
                'is_published' => (bool)$category['is_published'],
            ],
            $rows
        )]);
    }

    if ($segments === ['admin', 'categories'] && $method === 'POST') {
        $name = required_string($input, 'name', 100);
        $existingNames = $pdo->query(
            'SELECT name FROM product_categories'
        )->fetchAll(PDO::FETCH_COLUMN);
        foreach ($existingNames as $existingName) {
            if (canonical_category_key((string)$existingName) === canonical_category_key($name)) {
                respond(409, ['error' => 'Cette catégorie existe déjà.']);
            }
        }
        try {
            $query = $pdo->prepare(
                'INSERT INTO product_categories (name, is_published) VALUES (?, 0)'
            );
            $query->execute([$name]);
        } catch (PDOException $exception) {
            if ($exception->getCode() === '23000') {
                respond(409, ['error' => 'Cette catégorie existe déjà.']);
            }
            throw $exception;
        }
        respond(201, ['id' => (int)$pdo->lastInsertId(), 'name' => $name]);
    }

    if (count($segments) === 3 && $segments[0] === 'admin' &&
        $segments[1] === 'categories' && filter_var($segments[2], FILTER_VALIDATE_INT) &&
        $method === 'PUT') {
        $id = (int)$segments[2];
        $published = filter_var(
            $input['is_published'] ?? null,
            FILTER_VALIDATE_BOOLEAN,
            FILTER_NULL_ON_FAILURE
        );
        if ($published === null) {
            respond(422, ['error' => 'État de publication invalide.']);
        }
        $query = $pdo->prepare(
            'UPDATE product_categories SET is_published = ? WHERE id = ?'
        );
        $query->execute([$published ? 1 : 0, $id]);
        if ($query->rowCount() === 0) {
            $exists = $pdo->prepare('SELECT 1 FROM product_categories WHERE id = ?');
            $exists->execute([$id]);
            if (!$exists->fetchColumn()) {
                respond(404, ['error' => 'Catégorie introuvable.']);
            }
        }
        respond(200, ['ok' => true, 'is_published' => $published]);
    }

    if ($segments === ['admin', 'users'] && $method === 'GET') {
        $rows = $pdo->query(
            'SELECT id, nom, prenom, birth_date, phone, email, username, role,
                    is_active, last_login_at, created_at,
                    (SELECT COUNT(*) FROM login_history h
                     WHERE h.user_id = users.id AND h.succeeded = 1) AS successful_login_count
             FROM users ORDER BY id DESC'
        )->fetchAll();
        respond(200, ['users' => array_map(
            static fn(array $user): array => public_user($user) + [
                'created_at' => $user['created_at'],
                'last_login_at' => $user['last_login_at'],
                'successful_login_count' => (int)$user['successful_login_count'],
            ],
            $rows
        )]);
    }
    if (count($segments) === 4 && $segments[0] === 'admin' &&
        $segments[1] === 'users' && $segments[3] === 'history' && $method === 'GET') {
        $userId = filter_var($segments[2], FILTER_VALIDATE_INT);
        if ($userId === false) {
            respond(400, ['error' => 'Utilisateur invalide.']);
        }
        $exists = $pdo->prepare('SELECT email FROM users WHERE id = ?');
        $exists->execute([$userId]);
        if ($exists->fetchColumn() === false) {
            respond(404, ['error' => 'Utilisateur introuvable.']);
        }
        $logins = $pdo->prepare(
            'SELECT email, succeeded, occurred_at FROM login_history
             WHERE user_id = ? ORDER BY id DESC LIMIT 100'
        );
        $logins->execute([$userId]);
        $actions = $pdo->prepare(
            'SELECT a.target_email, a.action, a.details, a.occurred_at,
                    u.prenom AS admin_prenom, u.nom AS admin_nom
             FROM admin_user_actions a
             LEFT JOIN users u ON u.id = a.admin_user_id
             WHERE a.target_user_id = ? ORDER BY a.id DESC LIMIT 100'
        );
        $actions->execute([$userId]);
        $actionRows = $actions->fetchAll();
        foreach ($actionRows as &$action) {
            $action['details'] = $action['details'] === null
                ? null
                : json_decode($action['details'], true);
        }
        unset($action);
        respond(200, ['logins' => $logins->fetchAll(), 'actions' => $actionRows]);
    }
    if ($segments === ['admin', 'users'] && $method === 'POST') {
        $actor = current_user($pdo);
        $role = ($input['role'] ?? 'user') === 'admin' ? 'admin' : 'user';
        $email = strtolower(required_string($input, 'email', 254));
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            respond(422, ['error' => 'Adresse e-mail invalide.']);
        }
        $birthDate = required_string($input, 'birth_date', 10);
        if (!valid_date($birthDate)) {
            respond(422, ['error' => 'Date de naissance invalide.']);
        }
        $query = $pdo->prepare(
            'INSERT INTO users (nom, prenom, birth_date, phone, email, username, password_hash, role)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
        );
        try {
            $query->execute([
                required_string($input, 'nom', 120),
                required_string($input, 'prenom', 120),
                $birthDate,
                required_string($input, 'phone', 40),
                $email,
                required_string($input, 'username', 80),
                password_hash(validated_password($input), PASSWORD_DEFAULT),
                $role,
            ]);
        } catch (PDOException $exception) {
            if ($exception->getCode() === '23000') {
                respond(409, ['error' => 'Cet e-mail ou cet identifiant est déjà utilisé.']);
            }
            throw $exception;
        }
        $userId = (int)$pdo->lastInsertId();
        log_admin_user_action(
            $pdo,
            (int)$actor['id'],
            $userId,
            $email,
            'created',
            ['role' => $role]
        );
        respond(201, ['id' => (string)$userId]);
    }
    if (count($segments) === 3 && $segments[0] === 'admin' && $segments[1] === 'users' &&
        filter_var($segments[2], FILTER_VALIDATE_INT)) {
        $id = (int)$segments[2];
        if ($method === 'PUT') {
            $role = ($input['role'] ?? 'user') === 'admin' ? 'admin' : 'user';
            $actor = current_user($pdo);
            $targetQuery = $pdo->prepare(
                'SELECT role, is_active, email, nom, prenom, birth_date, phone, username
                 FROM users WHERE id = ?'
            );
            $targetQuery->execute([$id]);
            $target = $targetQuery->fetch();
            if (!$target) {
                respond(404, ['error' => 'Utilisateur introuvable.']);
            }
            $currentRole = $target['role'];
            $currentActive = (bool)$target['is_active'];
            $isActive = filter_var(
                $input['is_active'] ?? true,
                FILTER_VALIDATE_BOOLEAN,
                FILTER_NULL_ON_FAILURE
            );
            if ($isActive === null) {
                respond(422, ['error' => 'Statut du compte invalide.']);
            }
            if ($id === (int)$actor['id'] && $role !== 'admin') {
                respond(409, ['error' => 'Vous ne pouvez pas retirer votre propre rôle administrateur.']);
            }
            if ($id === (int)$actor['id'] && !$isActive) {
                respond(409, ['error' => 'Vous ne pouvez pas suspendre votre propre compte.']);
            }
            if ($currentRole === 'admin' && $role !== 'admin' &&
                (int)$pdo->query("SELECT COUNT(*) FROM users WHERE role = 'admin'")->fetchColumn() <= 1) {
                respond(409, ['error' => 'Impossible de retirer le rôle du dernier administrateur.']);
            }
            if ($currentRole === 'admin' && $isActive === false &&
                (int)$pdo->query("SELECT COUNT(*) FROM users WHERE role = 'admin' AND is_active = 1")->fetchColumn() <= 1) {
                respond(409, ['error' => 'Impossible de suspendre le dernier administrateur actif.']);
            }
            $email = strtolower(required_string($input, 'email', 254));
            if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
                respond(422, ['error' => 'Adresse e-mail invalide.']);
            }
            $fields = [
                required_string($input, 'nom', 120),
                required_string($input, 'prenom', 120),
                required_string($input, 'birth_date', 10),
                required_string($input, 'phone', 40),
                $email,
                required_string($input, 'username', 80),
                $role,
            ];
            if (!valid_date($fields[2])) {
                respond(422, ['error' => 'Date de naissance invalide.']);
            }
            $sql = 'UPDATE users SET nom = ?, prenom = ?, birth_date = ?, phone = ?, email = ?, username = ?, role = ?, is_active = ?';
            $fields[] = $isActive ? 1 : 0;
            if (trim((string)($input['password'] ?? '')) !== '') {
                $sql .= ', password_hash = ?';
                $fields[] = password_hash(validated_password($input), PASSWORD_DEFAULT);
            }
            $sql .= ' WHERE id = ?';
            $fields[] = $id;
            try {
                $query = $pdo->prepare($sql);
                try {
                    $query->execute($fields);
                } catch (PDOException $exception) {
                    if ($exception->getCode() === '23000') {
                        respond(409, ['error' => 'Cet e-mail ou cet identifiant est déjà utilisé.']);
                    }
                    throw $exception;
                }
            } catch (PDOException $exception) {
                if ($exception->getCode() === '23000') {
                    respond(409, ['error' => 'Cet e-mail ou cet identifiant est déjà utilisé.']);
                }
                throw $exception;
            }
            $newEmail = $email;
            $changedFields = [];
            if ($target['email'] !== $email) $changedFields[] = 'email';
            if ($target['nom'] !== $fields[0]) $changedFields[] = 'nom';
            if ($target['prenom'] !== $fields[1]) $changedFields[] = 'prenom';
            if ($target['birth_date'] !== $fields[2]) $changedFields[] = 'birth_date';
            if ($target['phone'] !== $fields[3]) $changedFields[] = 'phone';
            if ($target['username'] !== $fields[5]) $changedFields[] = 'username';
            if ($currentRole !== $role) $changedFields[] = 'role';
            if ($currentActive !== $isActive) $changedFields[] = 'status';
            if (trim((string)($input['password'] ?? '')) !== '') {
                $changedFields[] = 'password';
            }
            if ($changedFields !== []) {
                $action = !$isActive && $currentActive
                    ? 'suspended'
                    : ($isActive && !$currentActive ? 'reactivated' : 'updated');
                log_admin_user_action(
                    $pdo,
                    (int)$actor['id'],
                    $id,
                    $newEmail,
                    $action,
                    ['changed_fields' => $changedFields]
                );
            }
            if ($currentRole !== $role) {
                log_admin_user_action(
                    $pdo,
                    (int)$actor['id'],
                    $id,
                    $newEmail,
                    'role_changed',
                    ['from' => $currentRole, 'to' => $role]
                );
            }
            if ($currentActive && !$isActive) {
                $revoke = $pdo->prepare('DELETE FROM api_tokens WHERE user_id = ?');
                $revoke->execute([$id]);
            }
            respond(200, ['ok' => true]);
        }
        if ($method === 'DELETE') {
            $admin = current_user($pdo);
            $target = $pdo->prepare('SELECT role, email FROM users WHERE id = ?');
            $target->execute([$id]);
            $targetUser = $target->fetch();
            if (!$targetUser) {
                respond(404, ['error' => 'Utilisateur introuvable.']);
            }
            if ($id === (int)$admin['id']) {
                respond(409, ['error' => 'Vous ne pouvez pas supprimer votre propre compte.']);
            }
            if ($targetUser['role'] === 'admin' &&
                (int)$pdo->query("SELECT COUNT(*) FROM users WHERE role = 'admin'")->fetchColumn() <= 1) {
                respond(409, ['error' => 'Impossible de supprimer le dernier administrateur.']);
            }
            $query = $pdo->prepare('DELETE FROM users WHERE id = ?');
            try {
                $query->execute([$id]);
            } catch (PDOException $exception) {
                if ($exception->getCode() === '23000') {
                    respond(409, ['error' => 'Impossible de supprimer un utilisateur qui possède des commandes.']);
                }
                throw $exception;
            }
            log_admin_user_action(
                $pdo,
                (int)$admin['id'],
                $id,
                $targetUser['email'],
                'deleted'
            );
            respond(200, ['ok' => true]);
        }
    }

    if ($segments === ['admin', 'products'] && $method === 'POST') {
        $query = $pdo->prepare(
            'INSERT INTO products (name, brand, category, description, price, promo_price, stock, color_stock, icon, image_url, image_urls, specs)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        );
        $query->execute(product_values($input, $settings));
        respond(201, ['id' => (int)$pdo->lastInsertId()]);
    }
    if (count($segments) === 3 && $segments[0] === 'admin' && $segments[1] === 'products' &&
        filter_var($segments[2], FILTER_VALIDATE_INT)) {
        $id = (int)$segments[2];
        if ($method === 'PUT' || $method === 'POST') {
            find_product($pdo, $id);
            $values = product_values($input, $settings);
            $values[] = $id;
            $query = $pdo->prepare(
                'UPDATE products SET name = ?, brand = ?, category = ?, description = ?, price = ?,
                 promo_price = ?, stock = ?, color_stock = ?, icon = ?, image_url = ?, image_urls = ?, specs = ? WHERE id = ?'
            );
            $query->execute($values);
            respond(200, ['ok' => true]);
        }
        if ($method === 'DELETE') {
            $query = $pdo->prepare('DELETE FROM products WHERE id = ?');
            try {
                $query->execute([$id]);
            } catch (PDOException $exception) {
                if ($exception->getCode() === '23000') {
                    respond(409, ['error' => 'Cet article figure déjà dans une commande et ne peut pas être supprimé.']);
                }
                throw $exception;
            }
            respond(200, ['ok' => true]);
        }
    }

    if ($segments === ['admin', 'orders'] && $method === 'GET') {
        $orders = $pdo->query(
            'SELECT o.*, u.nom, u.prenom, u.email
             FROM orders o JOIN users u ON u.id = o.user_id ORDER BY o.id DESC'
        )->fetchAll();
        foreach ($orders as &$order) {
            $items = $pdo->prepare(
                'SELECT product_name, color, quantity, unit_price FROM order_items WHERE order_id = ?'
            );
            $items->execute([$order['id']]);
            $order['items'] = $items->fetchAll();
        }
        unset($order);
        respond(200, ['orders' => $orders]);
    }
    if (count($segments) === 3 && $segments[0] === 'admin' && $segments[1] === 'orders' &&
        filter_var($segments[2], FILTER_VALIDATE_INT) && $method === 'PUT') {
        $status = required_string($input, 'status', 40);
        if (!in_array($status, ['En préparation', 'Expédiée', 'Livrée', 'Annulée'], true)) {
            respond(422, ['error' => 'Statut de commande invalide.']);
        }
        $query = $pdo->prepare('UPDATE orders SET status = ? WHERE id = ?');
        $query->execute([$status, (int)$segments[2]]);
        respond(200, ['ok' => true]);
    }

    respond(404, ['error' => 'Route API introuvable.']);
} catch (Throwable $exception) {
    error_log($exception->__toString());
    respond(500, ['error' => 'Erreur interne du serveur.']);
}
