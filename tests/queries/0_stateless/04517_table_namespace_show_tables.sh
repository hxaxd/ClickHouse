#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

db=$CLICKHOUSE_DATABASE

$CLICKHOUSE_CLIENT -m -q "
    CREATE TABLE \`ns.alpha\` (x UInt8) ENGINE = Memory;
    CREATE TABLE \`ns.beta\` (x UInt8) ENGINE = Memory;
    CREATE TABLE \`ns.sub.gamma\` (x UInt8) ENGINE = Memory;
    CREATE TABLE \`other.delta\` (x UInt8) ENGINE = Memory;
    CREATE TABLE plain (x UInt8) ENGINE = Memory;
"

echo "-- SHOW TABLES under a namespace: relative names, direct children only"
$CLICKHOUSE_CLIENT -m -q "USE $db.ns; SHOW TABLES"

echo "-- LIKE applies to the relative name"
$CLICKHOUSE_CLIENT -m -q "USE $db.ns; SHOW TABLES LIKE 'al%'"

echo "-- SHOW TABLES FROM database.namespace"
$CLICKHOUSE_CLIENT -q "SHOW TABLES FROM $db.ns"

echo "-- nested namespace"
$CLICKHOUSE_CLIENT -q "SHOW TABLES FROM $db.ns.sub"

echo "-- without a namespace the full names are shown"
$CLICKHOUSE_CLIENT -q "SHOW TABLES FROM $db" | sort
