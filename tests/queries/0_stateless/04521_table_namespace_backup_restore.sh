#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

db=$CLICKHOUSE_DATABASE

$CLICKHOUSE_CLIENT -m -q "
    CREATE TABLE \`ns.src\` (x UInt32) ENGINE = MergeTree ORDER BY x;
    INSERT INTO \`ns.src\` VALUES (1), (2);
"

echo "-- BACKUP a table by its namespace path"
$CLICKHOUSE_CLIENT -q "BACKUP TABLE ns.src TO Disk('backups', '${db}_ns.zip')" | grep -m1 -c "BACKUP_CREATED"

echo "-- RESTORE it under a different namespace-path name"
$CLICKHOUSE_CLIENT -q "RESTORE TABLE ns.src AS ns.restored FROM Disk('backups', '${db}_ns.zip')" | grep -m1 -c "RESTORED"
$CLICKHOUSE_CLIENT -q "SELECT count() FROM \`ns.restored\`"
$CLICKHOUSE_CLIENT -q "EXISTS TABLE $db.\`ns.restored\`"
