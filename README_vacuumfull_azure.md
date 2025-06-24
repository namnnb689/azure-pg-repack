
# VACUUM FULL for Azure Database for PostgreSQL

This guide explains how to safely run `VACUUM FULL` on tables in Azure Database for PostgreSQL, especially when pg_repack is not available or cannot be used due to the lack of superuser privileges.

---

## ⚠️ Important Notes

- `VACUUM FULL` **requires an exclusive lock** on the table.
- During the operation, all reads/writes to the table will be blocked.
- Use during **maintenance windows** or low-traffic periods.

---

## ✅ Use Case

- You have deleted a large number of rows and want to reclaim disk space.
- You **cannot use `pg_repack`** due to lack of superuser.
- You are okay with short **downtime** on the target table.

---

## 📦 Setup

Ensure your environment is configured with the following variables, either exported or inside `.env`:

```bash
export PGHOST=your-db.postgres.database.azure.com
export PGUSER=youruser
export PGPORT=5432
export PGDATABASE=yourdb
export PGPASSWORD=yourpassword
export PGSSLMODE=require
```

---

## 🛠️ SQL Example

Run this manually or through a job runner:

```sql
VACUUM FULL VERBOSE ANALYZE public.orders;
```

You can monitor table size before and after:

```sql
SELECT pg_size_pretty(pg_total_relation_size('public.orders')) AS size;
```

---

## 💡 Tips

- Combine `VACUUM FULL` with `ANALYZE` to update planner stats.
- Use `pg_stat_activity` to ensure no other queries are locking the table before you begin:

```sql
SELECT * FROM pg_stat_activity WHERE datname = current_database();
```

- Log the downtime to evaluate impact and improve future maintenance plans.

---

## 📜 Automating with job queue

Insert into your maintenance job queue table like so:

```sql
INSERT INTO maintenance_job_queue (job_type, schema_name, table_name, options, custom_sql, status, requested_at)
VALUES (
  'SQL',
  'public',
  'orders',
  NULL,
  'VACUUM FULL VERBOSE ANALYZE public.orders;',
  'PENDING',
  NOW()
);
```

Then run your maintenance runner to pick up and execute this job.

---

## 🧼 Alternatives

If you need **no downtime**, consider:

- Partitioning the table
- Using `pg_repack` (requires superuser)
- Creating a new table and swapping (manual workaround)

---

## 🔚 Summary

| Method         | Downtime | Superuser Required | Disk Reclaimed |
|----------------|----------|--------------------|----------------|
| VACUUM FULL    | ✅ Yes   | ❌ No               | ✅ Yes         |
| pg_repack      | ❌ No    | ✅ Yes              | ✅ Yes         |

---

Always test on a non-production environment first.
