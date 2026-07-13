#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

db=$CLICKHOUSE_DATABASE

$CLICKHOUSE_CLIENT -m -q "
    CREATE TABLE \`ns.t\` (x UInt32) ENGINE = MergeTree ORDER BY x;
    INSERT INTO \`ns.t\` VALUES (1), (2), (3);
"

echo "-- currentDatabase reports the logical name"
$CLICKHOUSE_CLIENT -m -q "USE $db.ns; SELECT currentDatabase() == '$db.ns'"
$CLICKHOUSE_CLIENT -q "SELECT currentDatabase() == '$db'"

echo "-- INSERT under the namespace"
$CLICKHOUSE_CLIENT -m -q "USE $db.ns; INSERT INTO t VALUES (4); SELECT count() FROM t"

echo "-- DESCRIBE under the namespace"
$CLICKHOUSE_CLIENT -m -q "USE $db.ns; DESCRIBE TABLE t" | wc -l

echo "-- lightweight DELETE under the namespace"
$CLICKHOUSE_CLIENT -m -q "USE $db.ns; DELETE FROM t WHERE x = 4; SELECT count() FROM t"

echo "-- RENAME under the namespace stays inside it"
$CLICKHOUSE_CLIENT -m -q "USE $db.ns; RENAME TABLE t TO renamed"
$CLICKHOUSE_CLIENT -m -q "EXISTS TABLE $db.\`ns.renamed\`"
$CLICKHOUSE_CLIENT -m -q "EXISTS TABLE $db.renamed"

echo "-- TRUNCATE and DROP under the namespace"
$CLICKHOUSE_CLIENT -m -q "USE $db.ns; TRUNCATE TABLE renamed; SELECT count() FROM renamed"
$CLICKHOUSE_CLIENT -m -q "
    USE $db.ns;
    CREATE TABLE droppable (x Int8) ENGINE = Memory;
    DROP TABLE droppable;
    SELECT count() FROM system.tables WHERE database = '$db' AND name = 'ns.droppable';
"
