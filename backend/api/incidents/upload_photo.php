<?php
// POST /incidents/upload_photo.php
// multipart/form-data, field: photo
// Returns: {"url": "https://..."}
require __DIR__ . '/../config.php';
$auth = require_auth();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('Method not allowed', 405);

if (empty($_FILES['photo']) || $_FILES['photo']['error'] !== UPLOAD_ERR_OK) {
    $code = $_FILES['photo']['error'] ?? UPLOAD_ERR_NO_FILE;
    fail('Upload failed (error ' . $code . ')', 400);
}

$file = $_FILES['photo'];
$maxBytes = 5 * 1024 * 1024; // 5 MB

if ($file['size'] > $maxBytes) fail('Image must be under 5 MB', 400);

$finfo = new finfo(FILEINFO_MIME_TYPE);
$mime  = $finfo->file($file['tmp_name']);
$extMap = [
    'image/jpeg' => 'jpg',
    'image/png'  => 'png',
    'image/gif'  => 'gif',
    'image/webp' => 'webp',
];
if (!array_key_exists($mime, $extMap)) fail('Unsupported image type', 400);

$ext       = $extMap[$mime];
$filename  = bin2hex(random_bytes(16)) . '.' . $ext;
$uploadDir = rtrim($_SERVER['DOCUMENT_ROOT'], '/') . '/uploads/incident_photos/';

if (!is_dir($uploadDir) && !mkdir($uploadDir, 0755, true)) {
    fail('Could not create upload directory', 500);
}

if (!move_uploaded_file($file['tmp_name'], $uploadDir . $filename)) {
    fail('Could not save image', 500);
}

// cPanel shared hosting often terminates SSL at a proxy, so $_SERVER['HTTPS']
// can be 'off' even on HTTPS requests. Check the forwarded header too.
$isHttps = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
         || (!empty($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https');
$scheme  = $isHttps ? 'https' : 'http';
$url     = $scheme . '://' . $_SERVER['HTTP_HOST'] . '/uploads/incident_photos/' . $filename;

audit((int)$auth['sub'], 'upload', 'incident_photo', 0, $filename);

respond(['url' => $url], 201);
