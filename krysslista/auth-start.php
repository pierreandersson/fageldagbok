<?php
/**
 * Initiates the OAuth 2.0 Authorization Code flow with PKCE.
 * Visit this page to log in via SLU's auth server.
 *
 * If a valid token already exists, shows status instead.
 */

$config = require __DIR__ . '/config.php';
require __DIR__ . '/token-helpers.php';

// Check if we already have a valid token
$tokens = loadTokens($config['token_file']);
$hasValidToken = $tokens && time() < ($tokens['expires_at'] ?? 0) - 60;

if (!isset($_GET['force']) && $hasValidToken) {
    $expiresAt = date('Y-m-d H:i:s', $tokens['expires_at']);
    echo "<!DOCTYPE html><html><head><meta charset='utf-8'><title>Auth Status</title></head><body>";
    echo "<h2>Token is valid</h2>";
    echo "<p>Expires: {$expiresAt}</p>";
    echo "<p><a href='?force=1'>Log in again</a></p>";
    echo "</body></html>";
    exit;
}

// Generate PKCE code_verifier (43-128 chars, URL-safe)
$codeVerifier = bin2hex(random_bytes(32));
$codeChallenge = rtrim(strtr(base64_encode(hash('sha256', $codeVerifier, true)), '+/', '-_'), '=');

// Generate state for CSRF protection
$state = bin2hex(random_bytes(16));

// Store in session
session_start();
$_SESSION['oauth_code_verifier'] = $codeVerifier;
$_SESSION['oauth_state'] = $state;

// Build authorization URL
$params = http_build_query([
    'client_id'             => $config['client_id'],
    'redirect_uri'          => $config['redirect_uri'],
    'response_type'         => 'code',
    'scope'                 => $config['scopes'],
    'state'                 => $state,
    'code_challenge'        => $codeChallenge,
    'code_challenge_method' => 'S256',
]);

$authUrl = $config['auth_endpoint'] . '?' . $params;

header('Location: ' . $authUrl);
exit;
