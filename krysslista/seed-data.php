<?php
/**
 * Seed Fågeldagbok database with Pierre's observations from the Tåkern database.
 * Run once: php seed-data.php
 */

$TAKERN_DB = __DIR__ . '/../../takern-birds/deploy/takern_observations.db';
$FAGEL_DB  = __DIR__ . '/fageldagbok.db';
$REPORTER  = 'Pierre Andersson';

if (!file_exists($TAKERN_DB)) {
    echo "Tåkern database not found: $TAKERN_DB\n";
    exit(1);
}

// Create Fågeldagbok database
$db = new SQLite3($FAGEL_DB);
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

// Copy Pierre's observations from Tåkern DB
$src = new SQLite3($TAKERN_DB, SQLITE3_OPEN_READONLY);

$cols = 'occurrence_id, taxon_id, scientific_name, vernacular_name,
    individual_count, event_start_date, event_end_date, start_time,
    latitude, longitude, locality, municipality, parish, county,
    recorded_by, reported_by, remarks, activity, bird_nest_activity_id,
    sex, life_stage, family, taxonomic_order,
    is_redlisted, redlist_category, verification_status, url, dataset_name';

$result = $src->query("SELECT $cols FROM observations WHERE recorded_by = '$REPORTER' ORDER BY event_start_date DESC");

$count = 0;
$stmt = $db->prepare("INSERT OR REPLACE INTO observations ($cols) VALUES (
    :occurrence_id, :taxon_id, :scientific_name, :vernacular_name,
    :individual_count, :event_start_date, :event_end_date, :start_time,
    :latitude, :longitude, :locality, :municipality, :parish, :county,
    :recorded_by, :reported_by, :remarks, :activity, :bird_nest_activity_id,
    :sex, :life_stage, :family, :taxonomic_order,
    :is_redlisted, :redlist_category, :verification_status, :url, :dataset_name
)");

$db->exec('BEGIN');
while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
    $stmt->reset();
    foreach ($row as $key => $value) {
        $stmt->bindValue(":$key", $value);
    }
    $stmt->execute();
    $count++;
}
$db->exec('COMMIT');

$src->close();

// Print summary
$totalObs = $db->querySingle("SELECT COUNT(*) FROM observations");
$totalSpecies = $db->querySingle("SELECT COUNT(DISTINCT taxon_id) FROM observations");
$totalLocalities = $db->querySingle("SELECT COUNT(DISTINCT locality) FROM observations");
$dateRange = $db->querySingle("SELECT MIN(event_start_date) || ' – ' || MAX(event_start_date) FROM observations");

echo "Seeded $count observations from Tåkern database.\n";
echo "  Species: $totalSpecies\n";
echo "  Localities: $totalLocalities\n";
echo "  Date range: $dateRange\n";

$db->close();
