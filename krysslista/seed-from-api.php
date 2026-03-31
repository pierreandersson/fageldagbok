<?php
/**
 * Seed Fågeldagbok database with ALL of Pierre's observations from the SOS API.
 * Replaces the Tåkern-only seed with full Artportalen data.
 *
 * Run on server: php seed-from-api.php
 * Safe to re-run (INSERT OR REPLACE on occurrence_id).
 */

$config = require __DIR__ . '/config.php';
require __DIR__ . '/token-helpers.php';

$DB_FILE = __DIR__ . '/fageldagbok.db';
$SOS_API = 'https://api.artdatabanken.se/species-observation-system/v1/Observations/Search';
// SOS API FAQ: max 1000 per page, skip+take <= 10000
// skip and take are URL query parameters, not body params
$PAGE_SIZE = 500;

// ── 1. Get valid access token ──

$accessToken = getValidAccessToken($config);
if (!$accessToken) {
    echo "ERROR: No valid access token. Run auth-start.php first.\n";
    exit(1);
}
echo "Access token OK.\n";

// ── 2. Open/create database ──

$db = new SQLite3($DB_FILE);
$db->busyTimeout(5000);
$db->exec('PRAGMA journal_mode=WAL');

$db->exec("CREATE TABLE IF NOT EXISTS observations (
    occurrence_id TEXT PRIMARY KEY,
    taxon_id INTEGER,
    scientific_name TEXT,
    vernacular_name TEXT,
    individual_count INTEGER,
    event_start_date TEXT,
    event_end_date TEXT,
    start_time TEXT,
    latitude REAL,
    longitude REAL,
    locality TEXT,
    municipality TEXT,
    parish TEXT,
    county TEXT,
    recorded_by TEXT,
    reported_by TEXT,
    remarks TEXT,
    activity TEXT,
    bird_nest_activity_id INTEGER,
    sex TEXT,
    life_stage TEXT,
    family TEXT,
    taxonomic_order TEXT,
    is_redlisted INTEGER,
    redlist_category TEXT,
    verification_status TEXT,
    url TEXT,
    dataset_name TEXT
)");

$db->exec("CREATE INDEX IF NOT EXISTS idx_date ON observations(event_start_date)");
$db->exec("CREATE INDEX IF NOT EXISTS idx_taxon ON observations(taxon_id)");
$db->exec("CREATE INDEX IF NOT EXISTS idx_locality ON observations(locality)");
$db->exec("CREATE INDEX IF NOT EXISTS idx_county ON observations(county)");
$db->exec("CREATE INDEX IF NOT EXISTS idx_taxon_date ON observations(taxon_id, event_start_date)");

// ── 3. Prepare insert statement ──

$stmt = $db->prepare("INSERT OR REPLACE INTO observations (
    occurrence_id, taxon_id, scientific_name, vernacular_name,
    individual_count, event_start_date, event_end_date, start_time,
    latitude, longitude, locality, municipality, parish, county,
    recorded_by, reported_by, remarks, activity, bird_nest_activity_id,
    sex, life_stage, family, taxonomic_order,
    is_redlisted, redlist_category, verification_status, url, dataset_name
) VALUES (
    :occurrence_id, :taxon_id, :scientific_name, :vernacular_name,
    :individual_count, :event_start_date, :event_end_date, :start_time,
    :latitude, :longitude, :locality, :municipality, :parish, :county,
    :recorded_by, :reported_by, :remarks, :activity, :bird_nest_activity_id,
    :sex, :life_stage, :family, :taxonomic_order,
    :is_redlisted, :redlist_category, :verification_status, :url, :dataset_name
)");

// ── 4. Fetch and insert in pages ──

echo "Fetching observations from SOS API...\n";

$body = json_encode([
    'output' => [
        'fieldSet' => 'Extended',
    ],
    'dataProvider' => [
        'ids' => [1],
    ],
    'reportedByMe' => true,
]);

$headers = [
    'Content-Type: application/json',
    'Authorization: Bearer ' . $accessToken,
    'Ocp-Apim-Subscription-Key: ' . ($config['subscription_key'] ?? ''),
];

// Fetch all pages
$allRecords = [];
$totalFromApi = null;
$skip = 0;
$maxPages = 20; // Safety limit: 20 pages * 500 = 10000 max

for ($page = 1; $page <= $maxPages; $page++) {
    $url = $SOS_API . '?skip=' . $skip . '&take=' . $PAGE_SIZE;

    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_POSTFIELDS => $body,
        CURLOPT_TIMEOUT => 60,
    ]);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_error($ch);
    curl_close($ch);

    if ($httpCode !== 200) {
        echo "ERROR: SOS API returned HTTP $httpCode on page $page\n";
        echo $curlError ?: $response;
        echo "\n";
        exit(1);
    }

    $data = json_decode($response, true);
    $records = $data['records'] ?? [];
    $totalFromApi = $data['totalCount'] ?? $totalFromApi;

    echo "  Page $page: got " . count($records) . " records (skip=$skip, total=$totalFromApi)\n";

    if (empty($records)) {
        break;
    }

    $allRecords = array_merge($allRecords, $records);

    // Stop if we got everything
    if (count($allRecords) >= $totalFromApi) {
        break;
    }

    // Stop if page was not full (last page)
    if (count($records) < $PAGE_SIZE) {
        break;
    }

    $skip += $PAGE_SIZE;
}

echo "  Total fetched: " . count($allRecords) . " of $totalFromApi\n";

if (count($allRecords) === 0) {
    echo "ERROR: No records fetched. Aborting.\n";
    exit(1);
}

// Only clear DB if we got all records
if (count($allRecords) >= $totalFromApi) {
    $db->exec("DELETE FROM observations");
    echo "  Cleared old data (got all records).\n";
} else {
    echo "  WARNING: Got fewer than totalCount. Merging with existing data.\n";
}

$db->exec('BEGIN');

$totalInserted = 0;
foreach ($allRecords as $rec) {
    $row = mapRecord($rec);
    $stmt->reset();
    foreach ($row as $key => $value) {
        $stmt->bindValue(":$key", $value);
    }
    $stmt->execute();
    $totalInserted++;
}

$db->exec('COMMIT');

// ── 5. Print summary ──

$totalObs = $db->querySingle("SELECT COUNT(*) FROM observations");
$totalSpecies = $db->querySingle("SELECT COUNT(DISTINCT taxon_id) FROM observations");
$totalLocalities = $db->querySingle("SELECT COUNT(DISTINCT locality) FROM observations");
$dateRange = $db->querySingle("SELECT MIN(event_start_date) || ' – ' || MAX(event_start_date) FROM observations");

echo "\nDone! Inserted $totalInserted observations from SOS API.\n";
echo "  Total in DB: $totalObs\n";
echo "  Species: $totalSpecies\n";
echo "  Localities: $totalLocalities\n";
echo "  Date range: $dateRange\n";

$db->close();

// ── Field mapping ──

function mapRecord(array $rec): array {
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
        'activity'              => nonEmpty($rec['occurrence']['activity']['value'] ?? null),
        'bird_nest_activity_id' => $rec['occurrence']['birdNestActivityId'] ?? null,
        'sex'                   => nonEmpty($rec['occurrence']['sex']['value'] ?? null),
        'life_stage'            => nonEmpty($rec['occurrence']['lifeStage']['value'] ?? null),
        'family'                => $rec['taxon']['family'] ?? null,
        'taxonomic_order'       => $rec['taxon']['order'] ?? null,
        'is_redlisted'          => ($rec['taxon']['attributes']['isRedlisted'] ?? false) ? 1 : 0,
        'redlist_category'      => $rec['taxon']['attributes']['redlistCategory'] ?? null,
        'verification_status'   => $rec['identification']['verificationStatus']['value'] ?? null,
        'url'                   => $rec['occurrence']['url'] ?? null,
        'dataset_name'          => $rec['datasetName'] ?? null,
    ];
}

/** Return null for empty strings (SOS API returns "" for unset fields) */
function nonEmpty(?string $val): ?string {
    return ($val !== null && $val !== '') ? $val : null;
}
