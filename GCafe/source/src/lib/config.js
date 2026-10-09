// 0JAYSHOP Client — Runtime Configuration
// ponytail: localStorage storage; upgrade to encrypted store if security tokens required.

// Values from <GCafe>\config.json arrive through the Electron preload as window.appConfig.
// An empty API url means offline mode: the game menu runs from data\games.json and the
// other services return empty results without waiting for a server.
function appConfig() {
  return (typeof window !== 'undefined' && window.appConfig) || {};
}

export const CONFIG = {
  DEFAULT_API_URL: process.env.NEXT_PUBLIC_API_URL || '',
  DEFAULT_MACHINE_ID: 'PC-01',
  DEFAULT_BRAND_NAME: '0JAYSHOP',
  DEFAULT_BRAND_BADGE: 'VIP',
  DEFAULT_BRAND_LOGO: '',
  REQUEST_TIMEOUT_MS: 4000,
};

// ── API Base URL ──

export function getApiBaseUrl() {
  if (typeof window !== 'undefined') {
    return window.localStorage?.getItem('gcafe_api_url') || appConfig().apiUrl || CONFIG.DEFAULT_API_URL;
  }
  return CONFIG.DEFAULT_API_URL;
}

export function isOnline() {
  return !!getApiBaseUrl();
}

export function setApiBaseUrl(url) {
  if (typeof window !== 'undefined') {
    window.localStorage?.setItem('gcafe_api_url', url);
  }
}

// ── Machine ID ──

export function getMachineId() {
  if (typeof window !== 'undefined') {
    return window.localStorage?.getItem('gcafe_machine_id') || appConfig().machineId || CONFIG.DEFAULT_MACHINE_ID;
  }
  return CONFIG.DEFAULT_MACHINE_ID;
}

export function setMachineId(id) {
  if (typeof window !== 'undefined') {
    window.localStorage?.setItem('gcafe_machine_id', id);
  }
}

// ── Brand Config ──

// Order: values saved in the hidden settings form > config.json > defaults (each field on its own).
export function getBrandConfig() {
  const c = appConfig();
  let p = {};
  if (typeof window !== 'undefined') {
    try { p = JSON.parse(window.localStorage?.getItem('gcafe_brand') || '{}') || {}; } catch { /* ignore */ }
  }
  return {
    name: (p.name && p.name !== 'G-CAFE' && p.name) || c.brandName || CONFIG.DEFAULT_BRAND_NAME,
    badge: p.badge || c.brandBadge || CONFIG.DEFAULT_BRAND_BADGE,
    logoUrl: p.logoUrl || c.brandLogo || CONFIG.DEFAULT_BRAND_LOGO,
  };
}

export function setBrandConfig(brand) {
  if (typeof window !== 'undefined') {
    window.localStorage?.setItem('gcafe_brand', JSON.stringify(brand));
  }
}

// ── Auth Token ──

export function getAuthToken() {
  if (typeof window !== 'undefined') {
    return window.localStorage?.getItem('gcafe_auth_token') || '';
  }
  return '';
}

export function setAuthToken(token) {
  if (typeof window !== 'undefined') {
    if (token) {
      window.localStorage?.setItem('gcafe_auth_token', token);
    } else {
      window.localStorage?.removeItem('gcafe_auth_token');
    }
  }
}
