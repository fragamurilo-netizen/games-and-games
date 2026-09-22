<?php
/** Offline regression: unequal measurement rates and missing denominators. */
if ( 'cli' !== PHP_SAPI ) { exit; }
define( 'ABSPATH', __DIR__ . '/' );
$root = isset( $argv[1] ) ? rtrim( $argv[1], '/' ) : dirname( __DIR__ );
require_once $root . '/inc/ads-center/includes/class-goac-stats.php';
require_once $root . '/inc/ads-center/includes/class-goac-learning.php';
$checks = 0;
$failures = array();
function av_check( $condition, $label ) {
	global $checks, $failures;
	$checks++;
	if ( ! $condition ) { $failures[] = $label; }
}
function av_near( $expected, $actual, $label ) {
	av_check( null !== $actual && abs( $expected - $actual ) < 0.0000001, $label );
}
$rows = array(
	array( 'earnings' => 2, 'page_views' => 100, 'impressions' => 1000, 'viewability' => 0.8, 'measurability' => 1.0 ),
	array( 'earnings' => 1, 'page_views' => 200, 'impressions' => 1000, 'viewability' => 0.2, 'measurability' => 0.1 ),
);
$sum = GOAC_Stats::sum( $rows );
av_near( 820 / 1100, $sum['viewability'], 'Viewability uses 1,100 reconstructed measurable impressions, not 2,000 total impressions.' );
av_near( 0.55, $sum['measurability'], 'Measurability keeps the total-impression denominator.' );
av_near( 10.0, $sum['page_rpm'], 'Page RPM remains the ratio of additive totals.' );
av_near( 1.5, $sum['impression_rpm'], 'Impression RPM remains the ratio of additive totals.' );
av_check( 'reconstructed_measurable_impression_weighted_available_rows' === ( $sum['viewability_aggregation'] ?? '' ), 'Reconstruction is identified as such.' );
av_near( 1.0, $sum['viewability_data_coverage'] ?? null, 'Complete compatible rows have full data coverage.' );

$mixed = array_merge( $rows, array(
	array( 'impressions' => 5000, 'viewability' => 1.0, 'measurability' => null ),
	array( 'impressions' => 3000, 'viewability' => null, 'measurability' => 0.5 ),
	array( 'impressions' => 100, 'viewability' => 1.0, 'measurability' => 0.0 ),
) );
$sum = GOAC_Stats::sum( $mixed );
av_near( 820 / 1100, $sum['viewability'], 'Null rates are excluded and zero measurable impressions add no weight.' );
av_near( 2100 / 10100, $sum['viewability_data_coverage'] ?? null, 'Missing compatible denominators remain visible in data coverage.' );
foreach ( array(
	array( array( 'impressions' => 100, 'viewability' => 0.5, 'measurability' => null ) ),
	array( array( 'impressions' => 100, 'viewability' => 0.5, 'measurability' => 0.0 ) ),
	array( array( 'impressions' => 100, 'viewability' => 0.5, 'measurability' => 1.5 ) ),
	array( array( 'impressions' => 0, 'viewability' => 1.0, 'measurability' => 1.0 ) ),
	array(),
) as $i => $fixture ) {
	$sum = GOAC_Stats::sum( $fixture );
	av_check( null === $sum['viewability'], 'No reconstructed denominator returns null, fixture ' . $i );
}

if ( class_exists( 'SQLite3' ) ) {
	$db = new SQLite3( ':memory:' );
	$db->exec( 'CREATE TABLE rows (viewability REAL, measurability REAL, impressions REAL)' );
	foreach ( $mixed as $row ) {
		$stmt = $db->prepare( 'INSERT INTO rows VALUES (:v,:m,:i)' );
		$stmt->bindValue( ':v', $row['viewability'], null === $row['viewability'] ? SQLITE3_NULL : SQLITE3_FLOAT );
		$stmt->bindValue( ':m', $row['measurability'], null === $row['measurability'] ? SQLITE3_NULL : SQLITE3_FLOAT );
		$stmt->bindValue( ':i', $row['impressions'], SQLITE3_FLOAT );
		$stmt->execute();
	}
	$value = $db->querySingle( 'SELECT ' . GOAC_Learning::driver_viewability_sql() . ' FROM rows' );
	av_near( 820 / 1100, $value, 'The actual Data Lab SQL shares the measurable denominator and null behavior.' );
} else {
	echo "SQL execution not checked here: SQLite3 is unavailable; use test-active-view-sql.py.\n";
}
echo ( $checks - count( $failures ) ) . '/' . $checks . " Active View checks passed.\n";
if ( $failures ) { fwrite( STDERR, implode( "\n", $failures ) . "\n" ); exit( 1 ); }
