<?php
/**
 * OAuth configuration for SLU/Artdatabanken authentication.
 * Copy this file to config.php and fill in the client_secret.
 *
 * Auth server: https://useradmin-auth.slu.se
 * OIDC discovery: https://useradmin-auth.slu.se/.well-known/openid-configuration
 *
 * NOTE: The auth files live at /krysslista/ on the server, but are used by
 * the fågeldagbok backend at /fageldagbok/ via shared token storage.
 */

return [
    'client_id'     => 'pierrea.se',
    'client_secret' => 'FILL_IN_YOUR_SECRET_HERE',

    'auth_endpoint'   => 'https://useradmin-auth.slu.se/connect/authorize',
    'token_endpoint'  => 'https://useradmin-auth.slu.se/connect/token',
    'logout_endpoint' => 'https://useradmin-auth.slu.se/connect/endsession',
    'userinfo_endpoint' => 'https://useradmin-auth.slu.se/connect/userinfo',

    'redirect_uri'    => 'https://pierrea.se/krysslista/auth-callback.php',
    'post_logout_uri' => 'https://pierrea.se/krysslista/logout.php',

    'scopes' => 'openid offline_access SOS.Observations.Protected pierrea.se email profile',

    'token_file' => __DIR__ . '/tokens.json',
];
