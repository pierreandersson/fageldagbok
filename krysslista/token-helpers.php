<?php
/**
 * Shared OAuth token management.
 * Used by both the krysslista auth scripts and the fageldagbok backend.
 */

/**
 * Load stored tokens from disk.
 * Returns array with access_token, refresh_token, expires_at, id_token – or null.
 */
function loadTokens(string $tokenFile): ?array {
    if (!file_exists($tokenFile)) {
        return null;
    }
    $data = json_decode(file_get_contents($tokenFile), true);
    if (!is_array($data) || empty($data['access_token'])) {
        return null;
    }
    return $data;
}

/**
 * Save tokens to disk (atomic write).
 */
function saveTokens(string $tokenFile, array $tokens): void {
    $tmp = $tokenFile . '.tmp';
    file_put_contents($tmp, json_encode($tokens, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
    rename($tmp, $tokenFile);
}

/**
 * Refresh the access token using the refresh_token grant.
 * Returns updated token array, or null on failure.
 */
function refreshTokens(array $config, array $tokens): ?array {
    if (empty($tokens['refresh_token'])) {
        return null;
    }

    $ch = curl_init($config['token_endpoint']);
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => ['Content-Type: application/x-www-form-urlencoded'],
        CURLOPT_POSTFIELDS => http_build_query([
            'grant_type'    => 'refresh_token',
            'refresh_token' => $tokens['refresh_token'],
            'client_id'     => $config['client_id'],
            'client_secret' => $config['client_secret'],
        ]),
        CURLOPT_TIMEOUT => 15,
    ]);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($httpCode !== 200) {
        return null;
    }

    $data = json_decode($response, true);
    if (empty($data['access_token'])) {
        return null;
    }

    return [
        'access_token'  => $data['access_token'],
        'refresh_token' => $data['refresh_token'] ?? $tokens['refresh_token'],
        'id_token'      => $data['id_token'] ?? $tokens['id_token'] ?? null,
        'expires_at'    => time() + ($data['expires_in'] ?? 3600),
        'token_type'    => $data['token_type'] ?? 'Bearer',
        'scope'         => $data['scope'] ?? $tokens['scope'] ?? '',
        'refreshed_at'  => date('c'),
    ];
}

/**
 * Get a valid access token, refreshing if expired.
 * Returns the access_token string, or null if no valid token is available.
 */
function getValidAccessToken(array $config): ?string {
    $tokens = loadTokens($config['token_file']);
    if (!$tokens) {
        return null;
    }

    // Still valid (with 60s margin)
    if (time() < ($tokens['expires_at'] ?? 0) - 60) {
        return $tokens['access_token'];
    }

    // Try refresh
    $refreshed = refreshTokens($config, $tokens);
    if (!$refreshed) {
        return null;
    }

    saveTokens($config['token_file'], $refreshed);
    return $refreshed['access_token'];
}
