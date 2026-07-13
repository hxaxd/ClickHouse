#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

db=$CLICKHOUSE_DATABASE
user="user_${CLICKHOUSE_DATABASE}"

$CLICKHOUSE_CLIENT -m -q "
    CREATE TABLE \`ns.t\` (x UInt8) ENGINE = Memory;
    CREATE TABLE \`ns.sub.t2\` (x UInt8) ENGINE = Memory;
    CREATE TABLE \`other.t3\` (x UInt8) ENGINE = Memory;
    CREATE TABLE plain (x UInt8) ENGINE = Memory;
    DROP USER IF EXISTS $user;
    CREATE USER $user NOT IDENTIFIED;
"

echo "-- GRANT ON * under a namespace covers the namespace recursively and nothing else"
$CLICKHOUSE_CLIENT -m -q "USE $db.ns; GRANT SELECT ON * TO $user"
$CLICKHOUSE_CLIENT --user "$user" -q "SELECT count() FROM $db.\`ns.t\`"
$CLICKHOUSE_CLIENT --user "$user" -q "SELECT count() FROM $db.\`ns.sub.t2\`"
$CLICKHOUSE_CLIENT --user "$user" -q "SELECT count() FROM $db.\`other.t3\`" 2>&1 | grep -c "ACCESS_DENIED"
$CLICKHOUSE_CLIENT --user "$user" -q "SELECT count() FROM $db.plain" 2>&1 | grep -c "ACCESS_DENIED"

echo "-- the stored grant shows the namespace scope"
$CLICKHOUSE_CLIENT -q "SHOW GRANTS FOR $user" | grep -c "ns."

$CLICKHOUSE_CLIENT -q "DROP USER $user"
