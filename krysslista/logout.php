<?php
/**
 * Post-logout redirect handler.
 * SLU redirects here after the user logs out.
 */

echo "<!DOCTYPE html><html><head><meta charset='utf-8'><title>Logged out</title></head><body>";
echo "<h2>Du har loggats ut</h2>";
echo "<p>Du har loggats ut från SLU:s autentiseringsserver.</p>";
echo "<p><a href='auth-start.php'>Logga in igen</a></p>";
echo "</body></html>";
