# 報修登記系統
用於登記報修問題並追蹤處理進度。

## 欄位

- 報修人姓名
- 地點或部門
- 類別：設備、網路、環境、其他
- 問題說明
- 負責人
- 照片網址（選填）
- 緊急程度：低、中、高
- 處理狀態：待處理、處理中、已完成
- 登記時間（系統自動產生）
雲端任務測試
[報修欄位表（Excel）](文件/報修欄位表.xlsx)

## 網頁與發佈

首頁為根目錄的 `index.html`，使用純 HTML/CSS/JavaScript 與 CDN 提供的 supabase-js v2。
`config.js` 僅包含可公開的 Supabase 網址及 publishable key，不得放入 secret 或 service_role 金鑰。

在 GitHub 的 Settings → Pages 選擇「Deploy from a branch」，來源設為 `main`、`/ (root)`。
預期網址：https://cj2vum4.github.io/repair-system/ （需先啟用 Pages 並等待部署完成）。

請先在 Supabase 建立 `supabase/schema.sql` 所定義的資料表與權限；加入 SQL 檔或部署前端不會自動執行 SQL。
表單僅新增七個輸入欄位，`id`、`created_at`、`status` 使用資料庫預設值；清單公開顯示最近 20 筆。

## 002：新增負責人與照片網址（既有資料庫）

新增 `assignee`（負責人）與 `photo_url`（照片網址）兩個文字欄位。新版表單負責人必填、最多 100 字元；照片網址可留白（存為 NULL），最多 2048 字元，只接受 HTTP／HTTPS。
清單仍顯示最新 20 筆，舊資料的 NULL 分別顯示「未指定」「未提供」。照片以網址連結呈現，不自動下載或預覽外部圖片；連結另開分頁且不傳送來源網址，點擊仍會連線到第三方網站。

### 部署順序

1. 先備份／匯出 Supabase 的 `repair_requests`，保留原有八欄全部資料（包含 id），並記錄筆數；請避開有人新增的時段，以便精確比對。
2. 到 Supabase Dashboard → SQL Editor，新建查詢，貼上 `supabase/002_add_assignee_photo.sql` 全文並執行。**不要刪表，也不要重跑 `supabase/schema.sql`。** 本次開發只產生 SQL，未代為執行。
3. 確認兩個新欄位及 anon 的 INSERT 欄位授權已出現，再合併這次 PR、部署新版前端；在遷移之前部署新版會因缺少欄位而無法載入或新增。

遷移僅使用 `ADD COLUMN IF NOT EXISTS` 與補充欄位 GRANT，不含 UPDATE、DELETE、TRUNCATE、DROP 或舊欄位變更。新欄位允許 NULL，不回填既有資料，也不影響舊版表單送出；RLS 與禁止修改／刪除的規則保持原樣。
若欄位已存在，本檔不會修改該欄位的型態、內容或限制，請先確認它符合本次定義；若發生錯誤，交易會回滾，應檢查錯誤後重試，勿刪資料排除問題。

### 驗收：確認舊資料與權限

- 執行前後各匯出原有八欄 `id, created_at, reporter_name, location, category, description, urgency, status`，依 id 排序逐筆比對；無同時新增時，筆數、id 與每個原值都應完全相同。有同時新增時，應以執行前的 id 集合逐筆核對。
- 第一次遷移後，原有資料的新欄位應為 NULL；網頁仍能顯示這些紀錄，並顯示「未指定」「未提供」。若欄位本來就存在，既有值應維持不變。
- 在新版頁面以虛構資料新增一筆：負責人可儲存，照片留白可成功；再新增含有效照片網址的紀錄，確認清單連結正確。這兩筆會增加資料筆數，請在舊資料比對完成後進行。
- 在瀏覽器開發工具 Network 檢查新增請求僅有七個輸入欄位，不含 id、created_at、status；新紀錄的 status 應仍為「待處理」。確認 anon 無 UPDATE／DELETE 權限，並保留既有 RLS 政策。
