'use strict';

(() => {
  const form = document.querySelector('#repair-form');
  const fields = document.querySelector('#form-fields');
  const submitButton = document.querySelector('#submit-button');
  const refreshButton = document.querySelector('#refresh-button');
  const formMessage = document.querySelector('#form-message');
  const listMessage = document.querySelector('#list-message');
  const list = document.querySelector('#request-list');
  const count = document.querySelector('#request-count');
  const filters = document.querySelector('#urgency-filters');
  let requests = [];
  let selectedUrgency = '全部';
  let client;
  let submitting = false;
  let loading = false;

  function message(element, text, kind = '') {
    element.textContent = text;
    element.className = `message ${kind}`.trim();
  }

  // 資料內容只透過 textContent 寫入，避免報修內容被當成 HTML 執行。
  function element(tag, className, text) {
    const node = document.createElement(tag);
    node.className = className;
    node.textContent = text;
    return node;
  }

  function displayDate(value) {
    if (!value) return '時間未提供';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return '時間格式不明';
    return new Intl.DateTimeFormat('zh-TW', {
      dateStyle: 'medium', timeStyle: 'short'
    }).format(date);
  }

  function render() {
    const rows = selectedUrgency === '全部'
      ? requests
      : requests.filter((row) => row.urgency === selectedUrgency);
    list.replaceChildren();
    count.textContent = String(rows.length);
    if (!rows.length) {
      list.append(element('p', 'empty-state', requests.length
        ? `最近 20 筆中沒有緊急程度為「${selectedUrgency}」的報修。`
        : '目前還沒有報修紀錄，有問題時歡迎在上方登記。'));
      return;
    }
    for (const row of rows) {
      const card = element('article', 'request-card', '');
      const top = element('div', 'card-top', '');
      top.append(element('h3', 'card-title', row.location));
      const badge = element('span', 'badge', row.status);
      badge.dataset.status = row.status;
      top.append(badge);
      const meta = element('div', 'card-meta', '');
      meta.append(element('span', '', `類別：${row.category}`));
      meta.append(element('span', row.urgency === '高' ? 'urgency-high' : '', `緊急程度：${row.urgency}`));
      const bottom = element('div', 'card-bottom', '');
      bottom.append(element('span', '', `報修人：${row.reporter_name}`));
      bottom.append(element('span', '', displayDate(row.created_at)));
      card.append(top, meta, element('p', 'card-description', row.description), bottom);
      list.append(card);
    }
  }

  async function loadRequests() {
    if (loading) return;
    loading = true;
    refreshButton.disabled = true;
    submitButton.disabled = true;
    refreshButton.textContent = '載入中…';
    list.setAttribute('aria-busy', 'true');
    message(listMessage, '正在讀取最近的報修…');
    try {
      const { data, error } = await client.from('repair_requests')
        .select('id,created_at,reporter_name,location,category,description,urgency,status')
        .order('created_at', { ascending: false })
        .order('id', { ascending: false })
        .limit(20);
      if (error) throw error;
      requests = data || [];
      render();
      message(listMessage, '');
    } catch (error) {
      message(listMessage, `清單載入失敗，請重新整理再試。${errorText(error)}`, 'error');
    } finally {
      loading = false;
      submitButton.disabled = false;
      refreshButton.disabled = submitting;
      refreshButton.textContent = '重新整理';
      list.setAttribute('aria-busy', 'false');
    }
  }

  function errorText(error) {
    // 僅顯示服務回傳的文字，不輸出任何金鑰或 HTML。
    return error && typeof error.message === 'string' ? `（${error.message}）` : '';
  }

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (submitting || loading || !client) return;
    if (!form.reportValidity()) return;
    const values = new FormData(form);
    const payload = {
      reporter_name: String(values.get('reporter_name') || '').trim(),
      location: String(values.get('location') || '').trim(),
      category: String(values.get('category') || ''),
      description: String(values.get('description') || '').trim(),
      urgency: String(values.get('urgency') || '')
    };
    if (!payload.reporter_name || !payload.location || !payload.description) {
      message(formMessage, '報修人、地點與問題說明不可只填空白。', 'error');
      return;
    }
    if (!['設備', '網路', '環境', '其他'].includes(payload.category)
      || !['低', '中', '高'].includes(payload.urgency)) {
      message(formMessage, '請從清單選擇類別與緊急程度。', 'error');
      return;
    }
    submitting = true;
    fields.disabled = true;
    // 送出期間暫停手動載入，避免成功後清單刷新被較早的查詢覆蓋。
    refreshButton.disabled = true;
    submitButton.textContent = '送出中…';
    message(formMessage, '正在送出報修，請稍候…');
    try {
      // 只傳送獲授 INSERT 權限的五個欄位；不送 status、id、created_at。
      const { error } = await client.from('repair_requests').insert(payload);
      if (error) throw error;
      form.reset();
      message(formMessage, '報修已成功登記，狀態為「待處理」。', 'success');
      await loadRequests();
    } catch (error) {
      message(formMessage, `未能確認送出成功，請先查看清單再決定是否重送。${errorText(error)}`, 'error');
    } finally {
      submitting = false;
      fields.disabled = false;
      refreshButton.disabled = loading;
      submitButton.textContent = '送出報修 ↗';
    }
  });

  filters.addEventListener('click', (event) => {
    const button = event.target.closest('button[data-urgency]');
    if (!button || !filters.contains(button)) return;
    selectedUrgency = button.dataset.urgency;
    for (const filter of filters.querySelectorAll('button')) {
      filter.setAttribute('aria-pressed', String(filter === button));
    }
    render();
  });

  refreshButton.addEventListener('click', loadRequests);
  try {
    const config = window.REPAIR_CONFIG;
    if (!window.supabase || !config || !config.supabasePublishableKey.startsWith('sb_publishable_')) {
      throw new Error('公開連線設定或 Supabase 程式庫未載入，請重新整理頁面。');
    }
    client = window.supabase.createClient(config.supabaseUrl, config.supabasePublishableKey, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
    });
    // 首次載入完成前禁止送出，確保新增後的重新讀取不會被略過。
    fields.disabled = true;
    loadRequests().finally(() => { fields.disabled = false; });
  } catch (error) {
    fields.disabled = true;
    refreshButton.disabled = true;
    message(formMessage, `無法連線。${errorText(error)}`, 'error');
    message(listMessage, '清單暫時無法使用。', 'error');
  }
})();
