# 報修登記系統
用於登記報修問題並追蹤處理進度。

## 欄位

- 報修人姓名
- 地點或部門
- 類別：設備、網路、環境、其他
- 問題說明
- 負責人
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
表單僅新增五個輸入欄位，`id`、`created_at`、`status` 使用資料庫預設值；清單公開顯示最近 20 筆。
