<?php
/**
 * OAuth 2.0 callback handler.
 * Exchanges the authorization code for tokens and stores them.
 */

$config = require __DIR__ . '/config.php';
require __DIR__ . '/token-helpers.php';

session_start();

// Check for errors from the auth server
if (isset($_GET['error'])) {
    http_response_code(400);
    $error = htmlspecialchars($_GET['error']);
    $desc = htmlspecialchars($_GET['error_description'] ?? 'No details');
    echo "<!DOCTYPE html><html><head><meta charset='utf-8'><title>Auth Error</title></head><body>";
    echo "<h2>Authentication failed</h2>";
    echo "<p><strong>Error:</strong> {$error}</p>";
    echo "<p><strong>Description:</strong> {$desc}</p>";
    echo "<p><a href='auth-start.php'>Try again</a></p>";
    echo "</body></html>";
    exit;
}

// Validate state
$state = $_GET['state'] ?? '';
$expectedState = $_SESSION['oauth_state'] ?? '';
if (empty($state) || $state !== $expectedState) {
    http_response_code(403);
    echo "<!DOCTYPE html><html><head><meta charset='utf-8'><title>Auth Error</title></head><body>";
    echo "<h2>Invalid state parameter</h2>";
    echo "<p>CSRF check failed. <a href='auth-start.php'>Try again</a></p>";
    echo "</body></html>";
    exit;
}

// Get the authorization code
$code = $_GET['code'] ?? '';
if (empty($code)) {
    http_response_code(400);
    echo "<!DOCTYPE html><html><head><meta charset='utf-8'><title>Auth Error</title></head><body>";
    echo "<h2>No authorization code received</h2>";
    echo "<p><a href='auth-start.php'>Try again</a></p>";
    echo "</body></html>";
    exit;
}

// Retrieve PKCE code_verifier from session
$codeVerifier = $_SESSION['oauth_code_verifier'] ?? '';

// Clean up session
unset($_SESSION['oauth_state'], $_SESSION['oauth_code_verifier']);

// Exchange code for tokens
$postFields = [
    'grant_type'    => 'authorization_code',
    'code'          => $code,
    'redirect_uri'  => $config['redirect_uri'],
    'client_id'     => $config['client_id'],
    'client_secret' => $config['client_secret'],
];

if (!empty($codeVerifier)) {
    $postFields['code_verifier'] = $codeVerifier;
}

$ch = curl_init($config['token_endpoint']);
curl_setopt_array($ch, [
    CURLOPT_POST => true,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER => ['Content-Type: application/x-www-form-urlencoded'],
    CURLOPT_POSTFIELDS => http_build_query($postFields),
    CURLOPT_TIMEOUT => 15,
]);
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlError = curl_error($ch);
curl_close($ch);

if ($httpCode !== 200) {
    http_response_code(502);
    $errorDetail = htmlspecialchars($response ?: $curlError);
    echo "<!DOCTYPE html><html><head><meta charset='utf-8'><title>Token Error</title></head><body>";
    echo "<h2>Token exchange failed</h2>";
    echo "<p>HTTP {$httpCode}</p>";
    echo "<pre>{$errorDetail}</pre>";
    echo "<p><a href='auth-start.php'>Try again</a></p>";
    echo "</body></html>";
    exit;
}

$data = json_decode($response, true);
if (empty($data['access_token'])) {
    http_response_code(502);
    echo "<!DOCTYPE html><html><head><meta charset='utf-8'><title>Token Error</title></head><body>";
    echo "<h2>No access token in response</h2>";
    echo "<pre>" . htmlspecialchars($response) . "</pre>";
    echo "<p><a href='auth-start.php'>Try again</a></p>";
    echo "</body></html>";
    exit;
}

// Store tokens
$tokens = [
    'access_token'  => $data['access_token'],
    'refresh_token' => $data['refresh_token'] ?? null,
    'id_token'      => $data['id_token'] ?? null,
    'expires_at'    => time() + ($data['expires_in'] ?? 3600),
    'token_type'    => $data['token_type'] ?? 'Bearer',
    'scope'         => $data['scope'] ?? '',
    'created_at'    => date('c'),
];

saveTokens($config['token_file'], $tokens);

// Success page
$expiresAt = date('Y-m-d H:i:s', $tokens['expires_at']);
$hasRefresh = !empty($tokens['refresh_token']) ? 'Yes' : 'No';

echo "<!DOCTYPE html><html><head><meta charset='utf-8'><title>Auth Success</title></head><body>";
echo "<h2>Authentication successful!</h2>";
echo "<p><strong>Token expires:</strong> {$expiresAt}</p>";
echo "<p><strong>Refresh token:</strong> {$hasRefresh}</p>";
echo "<p><strong>Scope:</strong> " . htmlspecialchars($tokens['scope']) . "</p>";
echo "<p>You can close this page. The fågeldagbok app will now use the token to fetch data from Artportalen.</p>";
echo "</body></html>";
