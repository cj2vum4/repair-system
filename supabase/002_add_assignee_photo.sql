-- 既有 repair_requests 的增量遷移：只新增缺少的欄位，不重建資料表、不回填舊資料。
-- 請先備份並在 Supabase SQL Editor 執行本檔；不要重跑初始 schema.sql。
BEGIN;

-- 避免長時間等待資料表鎖；若逾時，整筆交易回滾，稍後於低流量時重試。
SET LOCAL lock_timeout = '5s';

-- 舊資料的新增欄位維持 NULL；不加 NOT NULL 或預設值，因此舊版表單仍可新增。
-- 新版表單要求負責人，資料庫允許 NULL 是為相容既有資料及舊版前端。
-- IF NOT EXISTS 只略過已存在的同名欄位，不修改其型態、限制或內容。
ALTER TABLE public.repair_requests
    ADD COLUMN IF NOT EXISTS assignee text
        CONSTRAINT repair_requests_assignee_check CHECK (
            assignee IS NULL OR (
                char_length(assignee) BETWEEN 1 AND 100
                AND assignee ~ '[^[:space:]]'
            )
        ),
    ADD COLUMN IF NOT EXISTS photo_url text
        CONSTRAINT repair_requests_photo_url_check CHECK (
            photo_url IS NULL OR (
                char_length(photo_url) BETWEEN 1 AND 2048
                AND photo_url ~* '^https?://[^[:space:]/?#]+[^[:space:]]*$'
            )
        );

-- 補上匿名新增的欄位權限；既有五欄 INSERT、整表 SELECT 與 RLS 政策保持原樣。
-- 既有整表 SELECT 自動涵蓋新欄位；不授予 UPDATE、DELETE 或 status 的 INSERT。
GRANT INSERT (assignee, photo_url)
    ON TABLE public.repair_requests TO anon;

-- 通知 Supabase REST API 更新欄位快取；交易提交後才會送出通知。
NOTIFY pgrst, 'reload schema';
COMMIT;
