#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

db=$CLICKHOUSE_DATABASE

$CLICKHOUSE_CLIENT -m -q "
    CREATE TABLE \`ns.t\` (x UInt32, s String) ENGINE = MergeTree ORDER BY x;
    INSERT INTO \`ns.t\` VALUES (1, 'a'), (2, 'b');
"

for analyzer in 0 1
do
    echo "-- enable_analyzer = $analyzer"

    echo "-- column qualified by the namespace path"
    $CLICKHOUSE_CLIENT --enable_analyzer=$analyzer -q "SELECT ns.t.x FROM ns.t ORDER BY x"

    echo "-- column qualified by database and namespace path"
    $CLICKHOUSE_CLIENT --enable_analyzer=$analyzer -q "SELECT $db.ns.t.x FROM $db.ns.t ORDER BY x"

    echo "-- qualified asterisk with a namespace path"
    $CLICKHOUSE_CLIENT --enable_analyzer=$analyzer -q "SELECT ns.t.* FROM ns.t ORDER BY x"

    echo "-- qualified asterisk with database and namespace path"
    $CLICKHOUSE_CLIENT --enable_analyzer=$analyzer -q "SELECT $db.ns.t.* FROM $db.ns.t ORDER BY x"

    echo "-- alias wins over the path"
    $CLICKHOUSE_CLIENT --enable_analyzer=$analyzer -q "SELECT a.x FROM $db.ns.t AS a ORDER BY a.x"

    echo "-- IN with a table path on the right-hand side"
    $CLICKHOUSE_CLIENT --enable_analyzer=$analyzer -q "SELECT count() FROM \`ns.t\` WHERE x IN $db.ns.t"
    $CLICKHOUSE_CLIENT --enable_analyzer=$analyzer -q "SELECT count() FROM \`ns.t\` WHERE x IN ns.t"

    echo "-- join of two namespace tables"
    $CLICKHOUSE_CLIENT --enable_analyzer=$analyzer -m -q "
        CREATE TABLE IF NOT EXISTS \`ns.u\` (x UInt32, v UInt32) ENGINE = Memory;
        TRUNCATE TABLE \`ns.u\`;
        INSERT INTO \`ns.u\` VALUES (1, 10), (2, 20);
        SELECT ns.t.x, ns.u.v FROM ns.t JOIN ns.u ON ns.t.x = ns.u.x ORDER BY ns.t.x;
    "
done

echo "-- identifiers from query parameters"
$CLICKHOUSE_CLIENT --param_d="$db" --param_n="ns" --param_t="t" \
    -q "SELECT count() FROM {d:Identifier}.{n:Identifier}.{t:Identifier}"
$CLICKHOUSE_CLIENT --param_n="ns" --param_t="t" \
    -q "SELECT count() FROM {n:Identifier}.{t:Identifier}"

echo "-- SHOW COLUMNS with a separate namespaced FROM"
$CLICKHOUSE_CLIENT -q "SHOW COLUMNS FROM t FROM $db.ns" | wc -l

echo "-- UNDROP parses a multipart table path"
$CLICKHOUSE_CLIENT -q "SELECT formatQuery('UNDROP TABLE a.b.c')"

echo "-- JSON subcolumn delimiters are untouched in column context"
$CLICKHOUSE_CLIENT -m -q "
    SET enable_json_type = 1;
    CREATE TABLE \`ns.j\` (json JSON) ENGINE = Memory;
    INSERT INTO \`ns.j\` VALUES ('{\"a\": 7}');
    SELECT json.a.:Int64 FROM ns.j;
"

echo "-- JSON subcolumn delimiters are not part of a table path"
$CLICKHOUSE_CLIENT -q "SELECT * FROM ns.j.:x" 2>&1 | grep -c "Syntax error"
