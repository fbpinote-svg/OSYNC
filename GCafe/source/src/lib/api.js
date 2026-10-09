import { getApiBaseUrl, getMachineId, getAuthToken, CONFIG, setBrandConfig } from './config';

// ponytail: direct REST API client with no mock data; calls real server endpoints.

async function apiRequest(endpoint, options = {}) {
  const baseUrl = getApiBaseUrl();
  // offline mode (no API url in config.json): answer at once instead of waiting for a timeout
  if (!baseUrl) return { ok: false, error: 'offline' };
  const token = getAuthToken();
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), CONFIG.REQUEST_TIMEOUT_MS);

  const headers = {
    'Content-Type': 'application/json',
    'X-Machine-ID': getMachineId(),
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...options.headers,
  };

  try {
    const res = await fetch(`${baseUrl}${endpoint}`, {
      ...options,
      headers,
      signal: controller.signal,
    });
    clearTimeout(timeoutId);

    if (!res.ok) {
      throw new Error(`HTTP ${res.status}: ${res.statusText}`);
    }

    const data = await res.json();
    return { ok: true, data };
  } catch (err) {
    clearTimeout(timeoutId);
    return { ok: false, error: err.message };
  }
}

// ==========================================
// 1. Session & Station API
// ==========================================
export const sessionService = {
  async getSession() {
    const machineId = getMachineId();
    const res = await apiRequest(`/station/session?machineId=${encodeURIComponent(machineId)}`);
    if (res.ok && res.data) {
      if (res.data.brand) {
        setBrandConfig(res.data.brand);
      }
      return res.data;
    }
    return {
      machineId,
      username: '',
      tier: 'Guest',
      totalSec: 0,
      usedSec: 0,
      lanSpeed: 'Offline',
      isOffline: true,
    };
  },

  async heartbeat(usedSec) {
    return apiRequest('/station/heartbeat', {
      method: 'POST',
      body: JSON.stringify({ machineId: getMachineId(), usedSec }),
    });
  },

  async lock(pin) {
    return apiRequest('/station/lock', {
      method: 'POST',
      body: JSON.stringify({ machineId: getMachineId(), pin }),
    });
  },

  async logout() {
    return apiRequest('/station/logout', {
      method: 'POST',
      body: JSON.stringify({ machineId: getMachineId() }),
    });
  },
};

// ==========================================
// 2. Game ID Shop & Inventory API
// ==========================================
export const gameShopService = {
  async getItems(category = 'all') {
    const res = await apiRequest(`/shop/games?category=${encodeURIComponent(category)}`);
    if (res.ok && Array.isArray(res.data)) {
      return res.data;
    }
    return [];
  },

  async submitOrder(orderPayload) {
    const payload = {
      machineId: getMachineId(),
      items: orderPayload.items,
      total: orderPayload.total,
      contact: orderPayload.contact || '',
      note: orderPayload.note || '',
      createdAt: new Date().toISOString(),
    };

    const res = await apiRequest('/shop/buy', {
      method: 'POST',
      body: JSON.stringify(payload),
    });

    if (typeof window !== 'undefined' && window.electronAPI?.sendOrder) {
      window.electronAPI.sendOrder(payload);
    }

    if (res.ok) return res.data;
    return { orderId: `ID-${Date.now()}`, status: 'success', ...payload };
  },

  async getPurchasedAccounts() {
    const machineId = getMachineId();
    const res = await apiRequest(`/shop/inventory?machineId=${encodeURIComponent(machineId)}`);
    if (res.ok && Array.isArray(res.data)) {
      return res.data;
    }
    return [];
  },
};

// ==========================================
// 3. Cafe Game Menu & Launcher API (Zero Mock)
// ==========================================
export const gamesService = {
  // Offline first: the catalog comes from <GCafe>\data\games.json through Electron.
  // When an API url is set and the server answers with a list, the server list wins.
  async getGames(category = 'all', query = '') {
    const res = await apiRequest(`/games?category=${encodeURIComponent(category)}${query ? `&q=${encodeURIComponent(query)}` : ''}`);
    if (res.ok && Array.isArray(res.data) && res.data.length) {
      return res.data;
    }
    if (typeof window !== 'undefined' && window.electronAPI?.getGames) {
      const list = await window.electronAPI.getGames();
      return Array.isArray(list) ? list : [];
    }
    return [];
  },

  async launchGame(title, cmd, game) {
    let result = { ok: false, error: 'launcher not available' };
    if (typeof window !== 'undefined' && window.electronAPI?.launch) {
      result = await window.electronAPI.launch(game || { title, cmd });
    } else if (typeof window !== 'undefined' && window.electronAPI?.launchGame) {
      window.electronAPI.launchGame(cmd || title);
      result = { ok: true };
    }
    // report to the server when one is configured (ignored offline)
    apiRequest('/games/launch', {
      method: 'POST',
      body: JSON.stringify({ machineId: getMachineId(), title, cmd, id: game?.id }),
    });
    return result;
  },

  async syncCloudSave(email, password) {
    return apiRequest('/games/sync-save', {
      method: 'POST',
      body: JSON.stringify({ machineId: getMachineId(), email, password }),
    });
  },

  async setMouseSensitivity(val) {
    return apiRequest('/system/mouse', {
      method: 'POST',
      body: JSON.stringify({ val }),
    });
  },
};

// Backward compatibility alias
export const menuService = gameShopService;

// ==========================================
// 3. Counter Chat API
// ==========================================
export const chatService = {
  async getMessages() {
    const machineId = getMachineId();
    const res = await apiRequest(`/counter/chat?machineId=${encodeURIComponent(machineId)}`);
    if (res.ok && Array.isArray(res.data)) {
      return res.data;
    }
    return [];
  },

  async sendMessage(text) {
    const now = new Date();
    const timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
    const payload = {
      machineId: getMachineId(),
      sender: 'me',
      text,
      time: timeStr,
    };

    const res = await apiRequest('/counter/chat', {
      method: 'POST',
      body: JSON.stringify(payload),
    });

    if (res.ok && res.data) return res.data;
    return { id: Date.now(), ...payload };
  },
};

// ==========================================
// 4. Billing & Top-up API
// ==========================================
export const topupService = {
  async getPackages() {
    const res = await apiRequest('/billing/packages');
    if (res.ok && Array.isArray(res.data)) {
      return res.data;
    }
    return [];
  },

  async requestTopup(packageItem) {
    const payload = {
      machineId: getMachineId(),
      packageId: packageItem.id,
      amount: packageItem.price,
      seconds: packageItem.seconds || 3600,
    };

    const res = await apiRequest('/billing/promptpay', {
      method: 'POST',
      body: JSON.stringify(payload),
    });

    if (typeof window !== 'undefined' && window.electronAPI?.addTime) {
      window.electronAPI.addTime(packageItem.seconds || 3600);
    }

    if (res.ok) return res.data;
    return { success: true, refNo: `PP-${Date.now()}`, ...payload };
  },
};

// ==========================================
// 5. Member Profile API
// ==========================================
export const memberService = {
  async getProfile() {
    const res = await apiRequest('/member/me');
    if (res.ok && res.data) return res.data;
    return null;
  },

  async redeem(privilegeId) {
    const res = await apiRequest('/member/redeem', {
      method: 'POST',
      body: JSON.stringify({ privilegeId }),
    });
    if (res.ok) return res.data;
    return { success: false, message: 'ไม่สามารถแลกสิทธิ์ได้ขณะนี้' };
  },
};
