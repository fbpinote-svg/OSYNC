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
    // logo without text for small spots (HUD header, game menu corner); none = the normal logo
    markUrl: c.brandMark || p.logoUrl || c.brandLogo || CONFIG.DEFAULT_BRAND_LOGO,
  };
}

export function setBrandConfig(brand) {
  if (typeof window !== 'undefined') {
    window.localStorage?.setItem('gcafe_brand', JSON.stringify(brand));
  }
}

// ── Look set by the shop (config.json "ui", checked again in electron/main.js) ──
// font: one of FONT_CHOICES (bundled in public/fonts, or built into Windows)
// hudSize / menuSize / lockSize: % zoom of the HUD / game menu dialog / lock screen (whole screen, so nothing overflows)
// hudBanner: picture under the HUD buttons ('' = card without picture, 'off' = hidden) · featured: game ids on top of the game menu
export const FONT_CHOICES = ['Kanit', 'Prompt', 'Chakra Petch', 'Leelawadee UI', 'Tahoma'];

// category names shown in the game menu (config.json ui.categoryNames adds / overrides)
export const CATEGORY_NAMES = {
  Online: 'เกมออนไลน์', Apps: 'โปรแกรม', Launchers: 'ตัวเปิดเกม', 'Single Player': 'เกมเนื้อเรื่อง',
  Mobile: 'เกมมือถือ', Emulator: 'อีมูเลเตอร์', Gacha: 'เกมกาชา', Riot: 'Riot Games', 'Battle.net': 'Battle.net',
};

export function getUiConfig() {
  const u = (appConfig().ui && typeof appConfig().ui === 'object' && appConfig().ui) || {};
  const pct = (v) => { const n = Number(v); return n >= 80 && n <= 130 ? n : 100; };
  return {
    font: FONT_CHOICES.includes(u.font) ? u.font : 'Kanit',
    hudSize: pct(u.hudSize),
    menuSize: pct(u.menuSize),
    lockSize: pct(u.lockSize),
    hudBanner: typeof u.hudBanner === 'string' ? u.hudBanner : '',
    hudBannerTag: typeof u.hudBannerTag === 'string' && u.hudBannerTag ? u.hudBannerTag : 'HOT ID SALE',
    hudBannerText: typeof u.hudBannerText === 'string' && u.hudBannerText ? u.hudBannerText : 'ไอดี Valorant / ROV / Steam สกินแรร์ พร้อมส่ง',
    featured: Array.isArray(u.featured) ? u.featured.map(String) : [],
    categoryNames: { ...CATEGORY_NAMES, ...(u.categoryNames && typeof u.categoryNames === 'object' ? u.categoryNames : {}) },
    // games that ask "graphics low / medium / high" before they start (17 Nov: GTA V Legacy + FiveM)
    graphicsPicker: Array.isArray(u.graphicsPicker) ? u.graphicsPicker.map(String) : ['steam-271590', 'fivem'],
    // 17 Nov (owner): menuOnly = only the game menu (no HUD / time left / shop tabs); sidePanel false = no right column
    menuOnly: u.menuOnly === true,
    sidePanel: u.sidePanel !== false,
    // 19 Nov (owner): the "ขอเกม Steam" button (main.js decides: config.json ui.steamRequest)
    steamRequest: u.steamRequest === true,
  };
}

/** build time of this menu ("2026-11-13 11:40", electron/main.js), '' outside the app */
export function getBuildStamp() {
  return typeof appConfig().build === 'string' ? appConfig().build : '';
}

/** launcher icons found on this PC (electron/main.js): { Steam: url, Riot: url, 'EA app': url, ... } */
export function getIcons() {
  const i = appConfig().icons;
  return i && typeof i === 'object' ? i : {};
}

/** apply the shop's font and the zoom of this screen ('hud' | 'menu' | 'lock') to the page; returns the ui settings */
export function applyUi(kind) {
  const u = getUiConfig();
  if (typeof document !== 'undefined') {
    const root = document.documentElement;
    root.style.setProperty('--ui-font', `'${u.font}'`);
    const z = (kind === 'hud' ? u.hudSize : kind === 'lock' ? u.lockSize : u.menuSize) / 100;
    root.style.zoom = z === 1 ? '' : String(z);
  }
  return u;
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
