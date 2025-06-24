#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
  echo "✅ Loaded config from .env"
else
  echo "⚠️  No .env found — using environment variables only."
fi

LOG_FILE="$SCRIPT_DIR/maintenance_runner.log"
LOCKFILE="/tmp/maintenance_runner.lock"

exec 200>$LOCKFILE
flock -n 200 || {
  echo "⏳ Another instance is running. Exiting."
  exit 1
}

echo "---------------------------------------------" | tee -a "$LOG_FILE"
echo "🔑 Starting maintenance runner at $(date)" | tee -a "$LOG_FILE"

source "$SCRIPT_DIR/job_handlers.sh"

JOB=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -Atc "
  SELECT job_id || '|' || job_type || '|' || COALESCE(schema_name,'') || '|' || COALESCE(table_name,'') || '|' ||
         COALESCE(array_to_string(options, ' '), '') || '|' || COALESCE(custom_sql,'')
  FROM maintenance_job_queue
  WHERE status = 'PENDING'
  ORDER BY requested_at
  LIMIT 1;
")


echo "DEBUG: Raw job string: $JOB"


if [ -z "$JOB" ]; then
  echo "✅ No PENDING jobs. Exiting." | tee -a "$LOG_FILE"
  exit 0
fi

IFS='|' read -r JOB_ID JOB_TYPE SCHEMA TABLE OPTIONS CUSTOM_SQL <<< "$JOB"

echo "📌 Job ID=$JOB_ID | Type=$JOB_TYPE | Schema=$SCHEMA | Table=$TABLE | Options='$OPTIONS'" | tee -a "$LOG_FILE"

psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -c "
  UPDATE maintenance_job_queue
  SET status = 'RUNNING', started_at = NOW()
  WHERE job_id = $JOB_ID;
"

EXIT_CODE=0
OUTPUT=""
HANDLER=$(get_handler "$JOB_TYPE")

if [ -z "$HANDLER" ]; then
  echo "❌ Unknown JOB_TYPE: $JOB_TYPE" | tee -a "$LOG_FILE"
  EXIT_CODE=1
else
  $HANDLER
fi

STATUS="DONE"
[ $EXIT_CODE -ne 0 ] && STATUS="FAILED"

psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -c "
  UPDATE maintenance_job_queue
  SET status = '$STATUS',
      finished_at = NOW(),
      output = \$\$${OUTPUT}\$\$
  WHERE job_id = $JOB_ID;
"

echo "✅ Job $JOB_ID finished with status $STATUS" | tee -a "$LOG_FILE"
echo "---------------------------------------------" | tee -a "$LOG_FILE"

exit $EXIT_CODE