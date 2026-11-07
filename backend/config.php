<?php

$localConfig = __DIR__ . '/config.local.php';

if (!is_file($localConfig)) {
    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['error' => 'Backend non configuré. Crée backend/config.local.php.']);
    exit;
}

$config = require $localConfig;
$db = $config['database'] ?? [];

try {
    $pdo = new PDO(
        sprintf(
            'mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4',
            $db['host'] ?? '127.0.0.1',
            $db['port'] ?? 3306,
            $db['name'] ?? 'voltora'
        ),
        $db['user'] ?? '',
        $db['password'] ?? '',
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]
    );
} catch (PDOException $exception) {
    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['error' => 'Connexion à la base de données impossible.']);
    exit;
}

return ['pdo' => $pdo, 'settings' => $config];
