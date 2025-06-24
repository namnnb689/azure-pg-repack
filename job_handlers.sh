#!/bin/bash

# ✅ Hàm ánh xạ JOB_TYPE → tên hàm xử lý
get_handler() {
  case "$1" in
    REPACK) echo handle_repack ;;
    DUMP) echo handle_dump ;;
    SQL) echo handle_sql ;;
    *) echo "" ;;
  esac
}

# ✅ Xử lý REPACK bằng pg_repack
handle_repack() {
  echo "⚙️  Running pg_repack..." | tee -a "$LOG_FILE"
  OUTPUT=$(pg_repack -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -t "$SCHEMA.$TABLE" $OPTIONS 2>&1)
  EXIT_CODE=${PIPESTATUS[0]}
}

# ✅ Xử lý DUMP bằng pg_dump
handle_dump() {
  echo "⚙️  Running pg_dump..." | tee -a "$LOG_FILE"
  TIMESTAMP=$(date +%Y%m%d%H%M%S)
  FILENAME="dbdump_${TIMESTAMP}.dump"
  OUTPUT=$(pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" $OPTIONS -f "$SCRIPT_DIR/$FILENAME" 2>&1)
  EXIT_CODE=${PIPESTATUS[0]}
}

# ✅ Xử lý SQL tùy chỉnh
handle_sql() {
  echo "⚙️  Running custom SQL..." | tee -a "$LOG_FILE"
  OUTPUT=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -c "$CUSTOM_SQL" 2>&1)
  EXIT_CODE=${PIPESTATUS[0]}
}
