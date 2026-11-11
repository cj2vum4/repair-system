-- 報修登記系統：供 Supabase 全新建表使用，僅提供 SQL，不會自動執行。
-- 本檔不是既有資料表的升級腳本；同名資料表存在時應停止並另行設計遷移。
-- 不使用 IF NOT EXISTS，以免沿用不符合本檔權限與 CHECK 要求的既有資料表。
-- BEGIN／COMMIT 讓建表、約束與授權在同一交易完成；本次僅儲存檔案，不執行。
-- 實作選擇：姓名、地點、問題說明均必填；字數上限分別為 100、200、5000 字元。
-- 字數與必填規則為本設計採用的限制，正式上線前仍需確認是否符合業務需求。
BEGIN;

-- 建立資料表：識別碼與建立時間由資料庫產生，時間使用含時區型態。
CREATE TABLE public.repair_requests (
    -- 系統欄位：UUID 主鍵與建立時間自動產生，不授予 anon 指定值的權限。
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at timestamptz NOT NULL DEFAULT now(),
    -- 使用者輸入欄位：必填，文字長度及允許值由下方 CHECK 驗證。
    reporter_name text NOT NULL,
    location text NOT NULL,
    category text NOT NULL,
    description text NOT NULL,
    -- 緊急程度可省略並預設為「中」；匿名新增的狀態由資料庫預設為「待處理」。
    -- status 的預設值本身不會阻止指定其他值，另以 GRANT 與 RLS 限制匿名新增。
    urgency text NOT NULL DEFAULT '中',
    status text NOT NULL DEFAULT '待處理',

    -- CHECK 層：文字不可只有空白，並限制實際儲存的字元數。
    CONSTRAINT repair_requests_reporter_name_check CHECK (
        char_length(reporter_name) BETWEEN 1 AND 100
        AND reporter_name ~ '[^[:space:]]'
    ),
    CONSTRAINT repair_requests_location_check CHECK (
        char_length(location) BETWEEN 1 AND 200
        AND location ~ '[^[:space:]]'
    ),
    CONSTRAINT repair_requests_description_check CHECK (
        char_length(description) BETWEEN 1 AND 5000
        AND description ~ '[^[:space:]]'
    ),

    -- CHECK 層：列舉值只能使用指定內容，也自然限制了這些欄位的長度。
    CONSTRAINT repair_requests_category_check CHECK (
        category IN ('設備', '網路', '環境', '其他')
    ),
    CONSTRAINT repair_requests_urgency_check CHECK (
        urgency IN ('低', '中', '高')
    ),
    CONSTRAINT repair_requests_status_check CHECK (
        status IN ('待處理', '處理中', '已完成')
    )
);

-- GRANT 層：不依賴專案自動授權；先清除一般用戶角色的資料表權限。
-- PUBLIC 代表所有角色；authenticated 不在本次授權範圍內。
-- 新建資料表尚無個別欄位授權，這裡的撤銷也涵蓋可能的預設資料表授權。
REVOKE ALL PRIVILEGES ON TABLE public.repair_requests
    FROM PUBLIC, anon, authenticated;

-- GRANT 層：anon 可讀全部欄位，但只能新增使用者實際填寫的五個欄位。
-- id、created_at、status 不開放新增權限，必須使用資料庫預設值。
-- 不授予 UPDATE、DELETE、TRUNCATE 或其他資料表權限。
GRANT USAGE ON SCHEMA public TO anon;
GRANT SELECT ON TABLE public.repair_requests TO anon;
GRANT INSERT (reporter_name, location, category, description, urgency)
    ON TABLE public.repair_requests TO anon;

-- RLS 層：開啟資料列安全，預設拒絕未被政策允許的操作。
ALTER TABLE public.repair_requests ENABLE ROW LEVEL SECURITY;

-- RLS 層：所有角色在具備 SELECT 權限的前提下，都可讀取全部清單。
-- 本檔僅授權 anon；政策本身不會賦予其他角色資料表權限。
CREATE POLICY repair_requests_public_select
    ON public.repair_requests
    FOR SELECT
    TO PUBLIC
    USING (true);

-- RLS 層：匿名新增必須保持初始狀態；WITH CHECK 會驗證套用預設值後的資料。
-- 即使未來有人放寬 status 的欄位新增權限，仍不能直接新增已處理的報修。
CREATE POLICY repair_requests_anon_insert
    ON public.repair_requests
    FOR INSERT
    TO anon
    WITH CHECK (status = '待處理');

-- 不建立 UPDATE 或 DELETE 政策；一般匿名用戶無法修改或刪除。
-- service_role、超級使用者及通常的資料表擁有者可繞過 RLS，金鑰不得放在前端。
-- 安全邊界：公開讀取會揭露所有報修內容，請勿儲存個資、密碼或其他敏感資訊。
-- 安全邊界：匿名新增沒有身分驗證、速率限制或防機器人機制，仍可能遭灌入垃圾資料。
-- 維運邊界：本檔未提供管理員更新流程；處理進度須另設可信任的後端與最小權限。
COMMIT;
