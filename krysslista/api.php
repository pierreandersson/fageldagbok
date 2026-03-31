<?php
/**
 * Fågeldagbok REST API – serves Pierre's bird observations from SQLite.
 * Consumed by the iOS app (and future web frontend).
 *
 * Endpoints:
 *   ?q=summary              → total obs, species, localities, year range
 *   ?q=observations         → paginated observations (+ filters)
 *   ?q=species              → species list with counts
 *   ?q=lifelist             → life list: unique species, first obs date+place
 *   ?q=localities           → localities with coordinates + counts
 *   ?q=stats                → per year, per month statistics
 *   ?q=live                 → today's obs from SOS API (requires OAuth)
 *   ?q=auth-status          → token validity (requires OAuth)
 *
 * Filters (for ?q=observations):
 *   &year=2026              → filter by year
 *   &county=Östergötland    → filter by county
 *   &species=103048         → filter by taxon_id
 *   &area=takern            → preset: 15km radius around Tåkern
 *   &limit=50&offset=0      → pagination
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

// Geographic area presets (bounding boxes)
const AREA_PRESETS = [
    'takern' => [
        'name' => 'Tåkern',
        'lat_min' => 58.21, 'lat_max' => 58.49,
        'lng_min' => 14.55, 'lng_max' => 15.07,
    ],
    'oland' => [
        'name' => 'Öland',
        'lat_min' => 56.19, 'lat_max' => 57.37,
        'lng_min' => 16.30, 'lng_max' => 17.16,
    ],
    'ottenby' => [
        'name' => 'Ottenby',
        'lat_min' => 56.19, 'lat_max' => 56.24,
        'lng_min' => 16.37, 'lng_max' => 16.42,
    ],
    'hornborgasjon' => [
        'name' => 'Hornborgasjön',
        'lat_min' => 58.28, 'lat_max' => 58.38,
        'lng_min' => 13.52, 'lng_max' => 13.68,
    ],
    'falsterbo' => [
        'name' => 'Falsterbo',
        'lat_min' => 55.38, 'lat_max' => 55.42,
        'lng_min' => 12.81, 'lng_max' => 12.90,
    ],
];

$DB_FILE = __DIR__ . '/fageldagbok.db';
$q = $_GET['q'] ?? '';

if (!file_exists($DB_FILE)) {
    jsonOut(['error' => 'Database not found']);
}

set_error_handler(function($severity, $msg, $file, $line) {
    throw new ErrorException($msg, 0, $severity, $file, $line);
});

try {
    $db = new SQLite3($DB_FILE, SQLITE3_OPEN_READONLY);
    $db->busyTimeout(5000);

    switch ($q) {
        case 'summary':     handleSummary($db); break;
        case 'observations': handleObservations($db); break;
        case 'species':     handleSpecies($db); break;
        case 'lifelist':    handleLifelist($db); break;
        case 'localities':  handleLocalities($db); break;
        case 'stats':       handleStats($db); break;
        case 'all':         handleAll($db); break;
        case 'areas':       handleAreas(); break;
        case 'live':        handleLive(); break;
        case 'auth-status': handleAuthStatus(); break;
        default:
            jsonOut(['error' => 'Unknown endpoint', 'endpoints' => [
                'summary', 'observations', 'species', 'lifelist',
                'localities', 'stats', 'live', 'auth-status'
            ]]);
    }
} catch (Exception $e) {
    http_response_code(500);
    jsonOut(['error' => $e->getMessage()]);
}

// ── Handlers ──

function handleSummary($db) {
    $total = $db->querySingle("SELECT COUNT(*) FROM observations");
    $species = $db->querySingle("SELECT COUNT(DISTINCT taxon_id) FROM observations");
    $localities = $db->querySingle("SELECT COUNT(DISTINCT locality) FROM observations");
    $minYear = $db->querySingle("SELECT MIN(SUBSTR(event_start_date, 1, 4)) FROM observations");
    $maxYear = $db->querySingle("SELECT MAX(SUBSTR(event_start_date, 1, 4)) FROM observations");

    jsonOut([
        'total_obs' => $total,
        'total_species' => $species,
        'total_localities' => $localities,
        'year_from' => $minYear ? intval($minYear) : null,
        'year_to' => $maxYear ? intval($maxYear) : null,
    ]);
}

function handleObservations($db) {
    $limit = min(intval($_GET['limit'] ?? 50), 500);
    $offset = intval($_GET['offset'] ?? 0);

    $where = [];
    $params = [];

    if (!empty($_GET['year'])) {
        $where[] = "SUBSTR(event_start_date, 1, 4) = :year";
        $params[':year'] = $_GET['year'];
    }
    if (!empty($_GET['county'])) {
        $where[] = "county = :county";
        $params[':county'] = $_GET['county'];
    }
    if (!empty($_GET['species'])) {
        $where[] = "taxon_id = :taxon_id";
        $params[':taxon_id'] = intval($_GET['species']);
    }
    $area = $_GET['area'] ?? '';
    $areaDef = AREA_PRESETS[$area] ?? null;
    if ($areaDef) {
        $where[] = "latitude BETWEEN {$areaDef['lat_min']} AND {$areaDef['lat_max']}";
        $where[] = "longitude BETWEEN {$areaDef['lng_min']} AND {$areaDef['lng_max']}";
    }

    $whereClause = $where ? 'WHERE ' . implode(' AND ', $where) : '';

    $countSql = "SELECT COUNT(*) FROM observations $whereClause";
    $stmt = $db->prepare($countSql);
    foreach ($params as $k => $v) $stmt->bindValue($k, $v);
    $total = $stmt->execute()->fetchArray()[0];

    $sql = "SELECT * FROM observations $whereClause
            ORDER BY event_start_date DESC, start_time DESC
            LIMIT :limit OFFSET :offset";
    $stmt = $db->prepare($sql);
    foreach ($params as $k => $v) $stmt->bindValue($k, $v);
    $stmt->bindValue(':limit', $limit, SQLITE3_INTEGER);
    $stmt->bindValue(':offset', $offset, SQLITE3_INTEGER);
    $result = $stmt->execute();

    $observations = [];
    while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
        $observations[] = $row;
    }

    jsonOut([
        'total' => $total,
        'limit' => $limit,
        'offset' => $offset,
        'observations' => $observations,
    ]);
}

function handleSpecies($db) {
    $sql = "SELECT taxon_id, vernacular_name, scientific_name, family,
                   COUNT(*) as observation_count,
                   MAX(event_start_date) as last_seen
            FROM observations
            GROUP BY taxon_id
            ORDER BY vernacular_name COLLATE NOCASE";
    $result = $db->query($sql);

    $species = [];
    while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
        $species[] = $row;
    }

    jsonOut(['total' => count($species), 'species' => $species]);
}

function handleLifelist($db) {
    $sql = "SELECT o.taxon_id, o.vernacular_name, o.scientific_name, o.family,
                   o.event_start_date as first_date, o.locality as first_locality,
                   o.county as first_county,
                   (SELECT COUNT(*) FROM observations WHERE taxon_id = o.taxon_id) as observation_count
            FROM observations o
            INNER JOIN (
                SELECT taxon_id, MIN(event_start_date) as min_date
                FROM observations
                GROUP BY taxon_id
            ) first ON o.taxon_id = first.taxon_id AND o.event_start_date = first.min_date
            GROUP BY o.taxon_id
            ORDER BY o.event_start_date DESC";
    $result = $db->query($sql);

    $lifelist = [];
    while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
        $lifelist[] = $row;
    }

    jsonOut(['total' => count($lifelist), 'lifelist' => $lifelist]);
}

function handleLocalities($db) {
    $sql = "SELECT locality, county, municipality,
                   AVG(latitude) as latitude, AVG(longitude) as longitude,
                   COUNT(*) as observation_count,
                   COUNT(DISTINCT taxon_id) as species_count,
                   MAX(event_start_date) as last_visit
            FROM observations
            WHERE latitude IS NOT NULL AND longitude IS NOT NULL
            GROUP BY locality
            ORDER BY observation_count DESC";
    $result = $db->query($sql);

    $localities = [];
    while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
        $row['latitude'] = round(floatval($row['latitude']), 5);
        $row['longitude'] = round(floatval($row['longitude']), 5);
        $localities[] = $row;
    }

    jsonOut(['total' => count($localities), 'localities' => $localities]);
}

function handleStats($db) {
    // Per year
    $result = $db->query("SELECT SUBSTR(event_start_date, 1, 4) as year,
                                  COUNT(*) as obs_count,
                                  COUNT(DISTINCT taxon_id) as species_count
                           FROM observations
                           GROUP BY year ORDER BY year");
    $perYear = [];
    while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
        $row['year'] = intval($row['year']);
        $perYear[] = $row;
    }

    // Per month (all years combined)
    $result = $db->query("SELECT CAST(SUBSTR(event_start_date, 6, 2) AS INTEGER) as month,
                                  COUNT(*) as obs_count,
                                  COUNT(DISTINCT taxon_id) as species_count
                           FROM observations
                           GROUP BY month ORDER BY month");
    $perMonth = [];
    while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
        $perMonth[] = $row;
    }

    // Top species
    $result = $db->query("SELECT vernacular_name, taxon_id, COUNT(*) as count
                           FROM observations
                           GROUP BY taxon_id ORDER BY count DESC LIMIT 10");
    $topSpecies = [];
    while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
        $topSpecies[] = $row;
    }

    // Top localities
    $result = $db->query("SELECT locality, COUNT(*) as count,
                                  COUNT(DISTINCT taxon_id) as species_count
                           FROM observations
                           GROUP BY locality ORDER BY count DESC LIMIT 10");
    $topLocalities = [];
    while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
        $topLocalities[] = $row;
    }

    jsonOut([
        'per_year' => $perYear,
        'per_month' => $perMonth,
        'top_species' => $topSpecies,
        'top_localities' => $topLocalities,
    ]);
}

function handleAreas() {
    $areas = [];
    foreach (AREA_PRESETS as $key => $def) {
        $areas[] = ['id' => $key, 'name' => $def['name']];
    }
    jsonOut(['areas' => $areas]);
}

function handleLive() {
    $config = getOAuthConfig();
    if (!$config) {
        jsonOut(['error' => 'OAuth not configured']);
    }

    require_once $config['_helpers_path'];
    $accessToken = getValidAccessToken($config);
    if (!$accessToken) {
        http_response_code(401);
        jsonOut([
            'error' => 'No valid token',
            'message' => 'Visit /krysslista/auth-start.php to authenticate',
        ]);
    }

    // Fetch observations from SOS API (reported by the authenticated user)
    $date = $_GET['date'] ?? date('Y-m-d');
    $body = json_encode([
        'output' => [
            'fieldSet' => 'Extended',
        ],
        'date' => [
            'startDate' => $date,
            'endDate' => $date,
            'dateFilterType' => 'BetweenStartDateAndEndDate',
        ],
        'dataProvider' => [
            'ids' => [1],
        ],
        'reportedByMe' => true,
    ]);

    $ch = curl_init('https://api.artdatabanken.se/species-observation-system/v1/Observations/Search');
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            'Content-Type: application/json',
            'Authorization: Bearer ' . $accessToken,
            'Ocp-Apim-Subscription-Key: ' . ($config['subscription_key'] ?? ''),
        ],
        CURLOPT_POSTFIELDS => $body,
        CURLOPT_TIMEOUT => 30,
    ]);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_error($ch);
    curl_close($ch);

    if ($httpCode !== 200) {
        http_response_code(502);
        jsonOut([
            'error' => 'SOS API error',
            'http_code' => $httpCode,
            'details' => $curlError ?: json_decode($response, true),
        ]);
    }

    $data = json_decode($response, true);
    $records = $data['records'] ?? [];

    // Transform SOS API nested format to flat format matching ?q=observations
    $observations = array_map('mapSosRecord', $records);

    jsonOut([
        'date' => $date,
        'total' => count($observations),
        'observations' => $observations,
    ]);
}

/**
 * Transform a SOS API record (nested) to flat format matching the DB schema.
 * Same mapping as seed-from-api.php's mapRecord().
 */
function mapSosRecord(array $rec): array {
    return [
        'occurrence_id'         => $rec['occurrence']['occurrenceId'] ?? null,
        'taxon_id'              => $rec['taxon']['id'] ?? null,
        'scientific_name'       => $rec['taxon']['scientificName'] ?? null,
        'vernacular_name'       => $rec['taxon']['vernacularName'] ?? null,
        'individual_count'      => intval($rec['occurrence']['organismQuantityInt'] ?? $rec['occurrence']['individualCount'] ?? 0) ?: null,
        'event_start_date'      => $rec['event']['plainStartDate'] ?? null,
        'event_end_date'        => $rec['event']['plainEndDate'] ?? null,
        'start_time'            => $rec['event']['plainStartTime'] ?? null,
        'latitude'              => $rec['location']['decimalLatitude'] ?? null,
        'longitude'             => $rec['location']['decimalLongitude'] ?? null,
        'locality'              => $rec['location']['locality'] ?? null,
        'municipality'          => $rec['location']['municipality']['name'] ?? null,
        'parish'                => $rec['location']['parish']['name'] ?? null,
        'county'                => $rec['location']['county']['name'] ?? null,
        'recorded_by'           => $rec['occurrence']['recordedBy'] ?? null,
        'reported_by'           => $rec['occurrence']['reportedBy'] ?? null,
        'remarks'               => $rec['occurrence']['occurrenceRemarks'] ?? null,
        'activity'              => ($rec['occurrence']['activity']['value'] ?? null) ?: null,
        'bird_nest_activity_id' => $rec['occurrence']['birdNestActivityId'] ?? null,
        'sex'                   => ($rec['occurrence']['sex']['value'] ?? null) ?: null,
        'life_stage'            => ($rec['occurrence']['lifeStage']['value'] ?? null) ?: null,
        'family'                => $rec['taxon']['family'] ?? null,
        'taxonomic_order'       => $rec['taxon']['order'] ?? null,
        'is_redlisted'          => ($rec['taxon']['attributes']['isRedlisted'] ?? false) ? 1 : 0,
        'redlist_category'      => $rec['taxon']['attributes']['redlistCategory'] ?? null,
        'verification_status'   => $rec['identification']['verificationStatus']['value'] ?? null,
        'url'                   => $rec['occurrence']['url'] ?? null,
        'dataset_name'          => $rec['datasetName'] ?? null,
    ];
}

function handleAuthStatus() {
    $config = getOAuthConfig();
    if (!$config) {
        jsonOut(['status' => 'not_configured', 'message' => 'OAuth not set up']);
    }

    require_once $config['_helpers_path'];
    $tokens = loadTokens($config['token_file']);
    if (!$tokens) {
        jsonOut(['status' => 'not_configured', 'message' => 'No tokens stored']);
    }

    $expiresAt = $tokens['expires_at'] ?? 0;
    $valid = time() < $expiresAt;
    $hasRefresh = !empty($tokens['refresh_token']);

    jsonOut([
        'status' => $valid ? 'valid' : 'expired',
        'expires_at' => $expiresAt,
        'has_refresh_token' => $hasRefresh,
        'scope' => $tokens['scope'] ?? '',
    ]);
}

/**
 * Load OAuth config (same directory).
 */
function getOAuthConfig(): ?array {
    $configFile = __DIR__ . '/config.php';
    $helpersFile = __DIR__ . '/token-helpers.php';
    if (!file_exists($configFile) || !file_exists($helpersFile)) {
        return null;
    }
    $config = require $configFile;
    $config['_helpers_path'] = $helpersFile;
    return $config;
}

// ── Helpers ──

function jsonOut($data) {
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    exit;
}
