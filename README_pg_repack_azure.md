# 🧰 PostgreSQL Table Repacking on Azure (Without Superuser)

## ⚠️ Lưu ý
Trên **Azure Database for PostgreSQL**, quyền `superuser` bị hạn chế nên **không thể dùng `pg_repack`** thông thường.  
Thay vào đó, chúng ta sẽ sử dụng kỹ thuật `Zero-Downtime Table Swap`.

---

## 🎯 Mục tiêu
Reclaim disk space sau khi xóa nhiều bản ghi khỏi bảng mà **không cần downtime và không dùng superuser**.

---

## 📁 Bước 1: Tạo bảng mẫu (ví dụ `orders`)

```sql
CREATE TABLE public.orders (
  order_id SERIAL PRIMARY KEY,
  product_name TEXT,
  quantity INT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Thêm dữ liệu mẫu
INSERT INTO public.orders (product_name, quantity)
SELECT 'Sample Product', generate_series(1, 100000);
```

---

## 🧹 Bước 2: Xóa dữ liệu (để tạo "bloat")

```sql
DELETE FROM public.orders WHERE order_id % 2 = 0;
```

---

## 📏 Bước 3: Kiểm tra kích thước bảng

```sql
SELECT pg_size_pretty(pg_total_relation_size('public.orders')) AS size;
```

---

## 🛠️ Bước 4: Repack bằng cách sao chép và hoán đổi bảng

```sql
-- 1. Tạo bảng mới từ bảng cũ
CREATE TABLE public.orders_new (LIKE public.orders INCLUDING ALL);

-- 2. Copy dữ liệu sạch từ bảng cũ sang bảng mới
INSERT INTO public.orders_new SELECT * FROM public.orders;

-- 3. (Tuỳ chọn) Rebuild index nếu cần
-- Index sẽ tự copy nếu dùng INCLUDING ALL

-- 4. Đổi tên bảng
ALTER TABLE public.orders RENAME TO orders_old;
ALTER TABLE public.orders_new RENAME TO orders;
```

---

## 🧪 Bước 5: Xác nhận giảm kích thước

```sql
SELECT 
  'orders_old' AS table, pg_size_pretty(pg_total_relation_size('public.orders_old')) AS size
UNION
SELECT 
  'orders' AS table, pg_size_pretty(pg_total_relation_size('public.orders')) AS size;
```

---

## 🧼 Bước 6: Xoá bảng cũ (sau khi kiểm tra)

```sql
DROP TABLE public.orders_old;
```

---

## ✅ Ưu điểm

- Không cần quyền superuser
- Giảm size đáng kể
- Gần như **zero downtime**

---

## ❌ Nhược điểm

- Cần xử lý ứng dụng để tạm dừng ghi trong lúc hoán đổi bảng
- Không phù hợp với bảng có foreign key phức tạp (phải xử lý thêm)

---

## 📌 Ghi chú

Bạn có thể tích hợp quy trình trên vào file `job_handlers.sh` để chạy tự động thông qua job queue nếu muốn.

---
