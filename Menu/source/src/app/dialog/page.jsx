'use client';

import { useState, useEffect, useRef, Suspense } from 'react';
import { gamesService } from '../../lib/api';
import { getBrandConfig, getMachineId, applyUi, getIcons } from '../../lib/config';
import ShopTabs from '../../components/ShopTabs';
import Icon, { CATEGORY_ICON } from '../../components/Icons';

// 13 Nov (2nd look, the shop's choice): flat launcher - plain top bar with text tabs · search + launcher-icon category
// buttons · picture cards with the name on the bottom edge · promo / featured / notice column · status pill.
// Same functions as before: tabs, search (Ctrl+F / Esc), categories, featured, admin banner + notice, random, refresh, time left.

// launcher of each card (tells duplicates like Apex Steam / EA app apart); games started by their own exe show a PC icon
const PLATFORM_LABELS = { Steam: 'Steam', 'EA app': 'EA app', Riot: 'Riot', Epic: 'Epic', Ubisoft: 'Ubisoft', Rockstar: 'Rockstar', Garena: 'Garena', HoYoPlay: 'HoYoPlay', Discord: 'Discord', Launcher: 'Launcher' };

// category button fallback when this PC has no launcher icon for it: line icons (17 Nov: no emoji), see components/Icons.jsx

const TABS = [
  { key: 'gamemenu', label: 'เกม' },
  { key: 'shop', label: 'ซื้อไอดี' },
  { key: 'inventory', label: 'คลังรหัส' },
  { key: 'chat', label: 'แชทร้าน' },
  { key: 'topup', label: 'เติมเงิน/ต่อเวลา' },
  { key: 'account', label: 'บัญชี' },
];

const catOf = (g) => g.cat || g.category || 'Online';

function hms(s) {
  const v = Math.max(0, Math.floor(s));
  return `${String(Math.floor(v / 3600)).padStart(2, '0')}:${String(Math.floor((v % 3600) / 60)).padStart(2, '0')}:${String(v % 60).padStart(2, '0')}`;
}

const PcIcon = () => (
  <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21 3H3a2 2 0 0 0-2 2v11a2 2 0 0 0 2 2h7v2H8v2h8v-2h-2v-2h7a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2zm0 13H3V5h18z" /></svg>
);

/** picture with a letter behind it: a missing / broken picture shows the letter */
function Poster({ src, title }) {
  const [bad, setBad] = useState(false);
  return (
    <>
      <span className="gc-fb">{(title || '?').charAt(0).toUpperCase()}</span>
      {src && !bad ? <img className="gc-img" src={src} alt="" loading="lazy" draggable={false} onError={() => setBad(true)} /> : null}
    </>
  );
}

/** small icon (launcher / program); broken → PC icon */
function SmallIcon({ src }) {
  const [bad, setBad] = useState(false);
  return src && !bad ? <img src={src} alt="" draggable={false} onError={() => setBad(true)} /> : <PcIcon />;
}

function DialogContent() {
  const [activeTab, setActiveTab] = useState('gamemenu');

  // Shop system connected (Cooper Agent 1.20+): top-up / extend / ID shop / code inventory come from the shop web
  // (components/ShopTabs.jsx). Not connected = those tabs show a notice (no made-up data).
  const [agent, setAgent] = useState(null);
  const shopLinked = !!(agent && agent.integrated);
  const shopSite = (agent && agent.site) || '';
  useEffect(() => {
    const a = typeof window !== 'undefined' && window.electronAPI?.agent;
    if (!a) return;
    a.get().then(setAgent);
    a.onUpdate(setAgent);
  }, []);
  // banner / notice / accent set by the shop at admin → หน้าจอเครื่องลูก (older webs: none)
  const [menuLook, setMenuLook] = useState(null);
  useEffect(() => {
    if (!shopLinked || typeof window === 'undefined' || !window.electronAPI?.agent?.api) return undefined;
    const load = () => window.electronAPI.agent.api('GET', 'state').then((r) => { if (r.ok && r.data && r.data.screen) setMenuLook(r.data.screen.menu || null); }).catch(() => {});
    load();
    const t = setInterval(load, 60000);
    return () => clearInterval(t);
  }, [shopLinked]);

  // ==========================================
  // GAME LAUNCHER STATE (Zero Mock)
  // ==========================================
  const [launcherCategory, setLauncherCategory] = useState('ทั้งหมด');
  const [launcherGames, setLauncherGames] = useState([]);
  const [loadingLauncher, setLoadingLauncher] = useState(true);
  const [launcherSearch, setLauncherSearch] = useState('');
  const [noticeOpen, setNoticeOpen] = useState(false);
  const [noticeLong, setNoticeLong] = useState(false);
  const noticeRef = useRef(null);
  const [nowMs, setNowMs] = useState(0);   // 0 until mounted (the page is pre-rendered: a time here would not match)

  // Station info, look & toast
  const [machineId, setMachineId] = useState('PC-12');
  const [brand, setBrand] = useState({ name: '0JAYSHOP', badge: 'ESPORTS' });
  const [ui, setUi] = useState(null);
  const [icons, setIcons] = useState({});
  const [toastMsg, setToastMsg] = useState('');
  const [toastVisible, setToastVisible] = useState(false);

  function showToast(msg) {
    setToastMsg(msg);
    setToastVisible(true);
    setTimeout(() => setToastVisible(false), 3200);
  }

  useEffect(() => {
    setBrand(getBrandConfig());
    setMachineId(getMachineId());
    setUi(applyUi('menu'));
    setIcons(getIcons());
  }, []);

  useEffect(() => {
    setNowMs(Date.now());
    const t = setInterval(() => setNowMs(Date.now()), 1000);
    return () => clearInterval(t);
  }, []);

  // Listen to tabs from URL query & Electron IPC
  useEffect(() => {
    if (typeof window !== 'undefined') {
      try {
        const params = new URLSearchParams(window.location.search);
        const t = params.get('tab');
        if (t) setActiveTab(t === 'order' ? 'shop' : t);
      } catch {}
      if (window.electronAPI?.onSwitchTab) {
        window.electronAPI.onSwitchTab((tab) => {
          if (tab) setActiveTab(tab === 'order' ? 'shop' : tab);
        });
      }
    }
  }, []);

  // Ctrl+F = search games, Esc = clear the search
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.ctrlKey && e.key.toLowerCase() === 'f') {
        e.preventDefault();
        setActiveTab('gamemenu');
        setTimeout(() => { const el = document.getElementById('launcher-search-input'); if (el) el.focus(); }, 0);
      } else if (e.key === 'Escape' && launcherSearch) {
        setLauncherSearch('');
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [launcherSearch]);

  const loadLauncherGames = () => {
    setLoadingLauncher(true);
    gamesService.getGames().then((data) => {
      setLauncherGames(Array.isArray(data) ? data : []);
      setLoadingLauncher(false);
    }).catch(() => {
      setLauncherGames([]);
      setLoadingLauncher(false);
    });
  };

  useEffect(() => {
    loadLauncherGames();
  }, []);

  // notice: 3 lines; "อ่านต่อ" only when it does not fit
  const notice = (menuLook && menuLook.notice) || '';
  useEffect(() => {
    const el = noticeRef.current;
    if (!el || noticeOpen) return;
    setNoticeLong(el.scrollHeight > el.clientHeight + 1);
  }, [notice, noticeOpen, activeTab, loadingLauncher]);

  function handleCloseDialog() {
    if (typeof window !== 'undefined' && window.electronAPI?.closeDialog) window.electronAPI.closeDialog();
  }
  function handleMinimizeDialog() {
    if (typeof window !== 'undefined' && window.electronAPI?.minimizeDialog) window.electronAPI.minimizeDialog();
  }
  function handleMaximizeDialog() {
    if (typeof window !== 'undefined' && window.electronAPI?.maximizeDialog) window.electronAPI.maximizeDialog();
  }

  async function handleLaunchGame(title, cmd, game) {
    showToast(`กำลังเปิด: ${title}...`);
    try {
      const res = await gamesService.launchGame(title, cmd, game);
      if (res && res.ok === false) showToast(`เปิดไม่สำเร็จ: ${res.error || ''}`);
    } catch (err) {
      showToast(`เปิดไม่สำเร็จ: ${err.message}`);
    }
  }
  // 17 Nov (owner): GTA V / FiveM ask the graphics level every time they are played (config.json ui.graphicsPicker);
  // FiveM also offers ReShade + mods (Tools\FiveM-ReShade, Tools\FiveM-Mods) in the same window
  const [gfx, setGfx] = useState(null);   // { g, sel, info, five, extras }
  const [sreq, setSreq] = useState(false);   // 19 Nov: the "ขอเกม Steam" window is open
  const pickerIds = (ui && ui.graphicsPicker) || [];
  function openGfx(g) {
    setGfx({ g, sel: 'low', info: null, five: null, extras: {} });
    window.electronAPI.gtaInfo().then((info) => setGfx((cur) => (cur && cur.g === g ? { ...cur, info } : cur))).catch(() => {});
    if (window.electronAPI.fivemState) {
      window.electronAPI.fivemState(g).then((five) => {
        if (!five || !five.ok) return;
        const mods = {};
        for (const m of five.mods || []) mods[m.name] = !!m.on;
        setGfx((cur) => (cur && cur.g === g ? { ...cur, five, extras: { reshade: !!(five.reshade && five.reshade.on), mods } } : cur));
      }).catch(() => {});
    }
  }
  async function playGfx(level) {
    const cur = gfx;
    const g = cur && cur.g;
    if (!g) return;
    setGfx(null);
    const title = g.title || g.name || 'Game';
    showToast(`กำลังเปิด: ${title} (ภาพ${GFX_LEVELS.find((l) => l.id === level)?.name || ''})...`);
    try {
      const res = await window.electronAPI.launchGta(g, level, cur.five ? cur.extras : null);
      if (res && res.ok === false) showToast(`เปิดไม่สำเร็จ: ${res.error || ''}`);
    } catch (err) {
      showToast(`เปิดไม่สำเร็จ: ${err.message}`);
    }
  }
  const launch = (g) => {
    if (g && pickerIds.includes(g.id) && typeof window !== 'undefined' && window.electronAPI?.launchGta) { openGfx(g); return; }
    handleLaunchGame(g.title || g.name || 'Game', g.cmd || '', g);
  };

  // ── 16 Nov: right-click on a game → small menu: play · open file location · copy the path (for everyone) ──
  const [ctx, setCtx] = useState(null);   // { x, y, g, path, err, copied }
  function openCtx(e, g) {
    e.preventDefault();
    e.stopPropagation();
    const api = typeof window !== 'undefined' ? window.electronAPI : null;
    setCtx({ x: e.clientX, y: e.clientY, g, path: '', err: api?.gameLocation ? '' : 'เปิดตำแหน่งไฟล์ได้เฉพาะในโปรแกรมเกมเมนู', copied: false });
    if (api?.gameLocation) {
      api.gameLocation(g.id).then((r) => setCtx((c) => (c && c.g === g ? { ...c, path: r && r.ok ? r.path : '', err: r && r.ok ? '' : (r && r.error) || 'ไม่พบตำแหน่งไฟล์' } : c))).catch(() => {});
    }
  }
  useEffect(() => {
    if (!ctx) return undefined;
    const close = () => setCtx(null);
    const onKey = (e) => { if (e.key === 'Escape') close(); };
    window.addEventListener('mousedown', close);
    window.addEventListener('blur', close);
    window.addEventListener('resize', close);
    window.addEventListener('wheel', close, { passive: true });
    window.addEventListener('keydown', onKey);
    return () => {
      window.removeEventListener('mousedown', close);
      window.removeEventListener('blur', close);
      window.removeEventListener('resize', close);
      window.removeEventListener('wheel', close);
      window.removeEventListener('keydown', onKey);
    };
  }, [ctx]);
  async function revealCtx() {
    const g = ctx && ctx.g;
    setCtx(null);
    if (!g || !window.electronAPI?.revealGame) return;
    const r = await window.electronAPI.revealGame(g.id);
    showToast(r && r.ok ? `เปิดตำแหน่งไฟล์: ${g.title || g.name}` : `เปิดตำแหน่งไฟล์ไม่ได้: ${(r && r.error) || ''}`);
  }
  function copyCtx() {
    if (!ctx || !ctx.path) return;
    try { navigator.clipboard?.writeText(ctx.path); } catch { /* clipboard blocked - the path is on screen */ }
    setCtx((c) => (c ? { ...c, copied: true } : c));
    setTimeout(() => setCtx(null), 700);
  }

  function handleLaunchRandom() {
    const pool = launcherGames.filter((g) => catOf(g) !== 'Launchers' && catOf(g) !== 'Apps');
    const list = pool.length ? pool : launcherGames;
    if (!list.length) { showToast('ยังไม่มีข้อมูลเกมในระบบ'); return; }
    launch(list[Math.floor(Math.random() * list.length)]);
  }

  // ── time left (same clock as the HUD: server time = local + agent offset) ──
  const sess = shopLinked ? agent.session : null;
  let leftText = '';
  if (sess && sess.endsAt && nowMs) leftText = hms((sess.endsAt - (nowMs + (Number(agent.serverOffsetMs) || 0))) / 1000);
  const machineText = (shopLinked && agent.machineName) || machineId;
  const clock = nowMs ? new Date(nowMs).toLocaleTimeString('th-TH', { hour: '2-digit', minute: '2-digit' }) : '';

  // ── categories in the game-list order, names from config ──
  const catNames = (ui && ui.categoryNames) || {};
  const catName = (c) => (c === 'ทั้งหมด' ? 'ทั้งหมด' : catNames[c] || c);
  const counts = {};
  const categoriesList = ['ทั้งหมด'];
  for (const g of launcherGames) {
    const c = catOf(g);
    if (!counts[c]) { counts[c] = 0; categoriesList.push(c); }
    counts[c] += 1;
  }
  const quickApps = launcherGames.filter((g) => catOf(g) === 'Apps').slice(0, 4);

  const q = launcherSearch.trim().toLowerCase();
  const filteredLauncherGames = launcherGames.filter((g) => {
    const cat = catOf(g);
    const matchCat = launcherCategory === 'ทั้งหมด' || cat === launcherCategory;
    const title = (g.title || g.name || '').toLowerCase();
    const matchQ = !q || title.includes(q) || cat.toLowerCase().includes(q) || catName(cat).toLowerCase().includes(q) || String(g.platform || '').toLowerCase().includes(q);
    return matchCat && matchQ;
  });

  const featured = ((ui && ui.featured) || []).map((id) => launcherGames.find((g) => g.id === id)).filter(Boolean);
  const accent = (menuLook && /^#[0-9a-f]{6}$/i.test(menuLook.accent || '') && menuLook.accent) || '';
  const adminBanner = menuLook && (menuLook.banner || menuLook.bannerText) ? menuLook : null;
  const promoImg = ui && ui.hudBanner && ui.hudBanner !== 'off' ? ui.hudBanner : '';
  const badgeIcon = (g) => icons[g.platform] || (g.platform === 'Launcher' || !g.platform ? g.icon : '') || '';
  const catIcon = (c) => icons[c] || '';
  // 17 Nov (owner): menuOnly = only the game menu (no shop tabs, no time left, no HUD - main.js); sidePanel false = no right column
  const menuOnly = !!(ui && ui.menuOnly);
  const sidePanel = !(ui && ui.sidePanel === false);
  const tabs = menuOnly ? [] : TABS;

  return (
    <div className="dialog-window" style={accent ? { '--gm-acc': accent } : undefined}>
      {/* Top bar: logo · text tabs · (time left on the shop tabs) · window buttons. ✕ closes and goes back to the HUD */}
      <div className="dialog-header drag-zone">
        <div className="dlg-brand" title={brand.name}>
          {brand.markUrl || brand.logoUrl ? <img src={brand.markUrl || brand.logoUrl} alt="" /> : null}
          <span>{brand.name}</span>
        </div>
        <div className="dialog-tabs no-drag">
          {tabs.map((t) => (
            <button key={t.key} className={`dialog-tab ${activeTab === t.key ? 'active' : ''}`} onClick={() => setActiveTab(t.key)}>
              {t.key === 'topup' && sess && sess.source === 'guest' ? 'ต่อเวลา' : t.label}
            </button>
          ))}
        </div>
        <span className="dialog-spacer" />
        {!menuOnly && leftText && activeTab !== 'gamemenu' ? <span className="time-chip" title="เวลาคงเหลือ">เหลือ<b>{leftText}</b></span> : null}
        <div className="win-controls no-drag">
          <button className="wc-btn" title="ย่อหน้าต่าง" onClick={handleMinimizeDialog}>
            <svg viewBox="0 0 12 12"><path d="M2 6.5h8" /></svg>
          </button>
          <button className="wc-btn" title="ขยาย / คืนขนาด" onClick={handleMaximizeDialog}>
            <svg viewBox="0 0 12 12"><rect x="2.5" y="2.5" width="7" height="7" rx="1" /></svg>
          </button>
          <button className="wc-btn close" title={menuOnly ? 'ปิด (ย่อเมนูไว้ที่แถบงาน)' : 'ปิด (กลับหน้าหลัก)'} onClick={handleCloseDialog}>
            <svg viewBox="0 0 12 12"><path d="M3 3l6 6M9 3l-6 6" /></svg>
          </button>
        </div>
      </div>

      <div className="dialog-body">
        {(activeTab === 'gamemenu' || menuOnly) && (
          <div className={`gamemenu-wrapper${sidePanel ? '' : ' no-side'}`}>
            <main className="gm-main">
              {/* toolbar: search · categories (launcher icons, name + count on hover) · programs · random · refresh */}
              <div className="gm-bar">
                <label className="gamemenu-search">
                  <svg className="search-icon" viewBox="0 0 24 24"><path d="M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z" /></svg>
                  <input
                    id="launcher-search-input"
                    type="text"
                    placeholder="ค้นหาเกม (เช่น Valorant, FiveM)"
                    value={launcherSearch}
                    onChange={(e) => setLauncherSearch(e.target.value)}
                    spellCheck={false}
                    autoComplete="off"
                  />
                  {launcherSearch ? <button className="search-clear" onClick={() => setLauncherSearch('')} title="ล้างคำค้น (Esc)"><Icon name="x" size={16} /></button> : null}
                </label>
                <div className="gm-chips">
                  {categoriesList.map((cat) => {
                    const ic = cat === 'ทั้งหมด' ? null : catIcon(cat);
                    return (
                      <button
                        key={cat}
                        className={`cat-btn ${cat === launcherCategory ? 'active' : ''}`}
                        onClick={() => setLauncherCategory(cat)}
                        title={`${catName(cat)} (${cat === 'ทั้งหมด' ? launcherGames.length : counts[cat]})`}
                        data-cat={cat}
                      >
                        {cat === 'ทั้งหมด' ? (
                          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 4h7v7H4zm9 0h7v7h-7zM4 13h7v7H4zm9 0h7v7h-7z" /></svg>
                        ) : ic ? <SmallIcon src={ic} /> : <Icon name={CATEGORY_ICON[cat] || 'gamepad'} size={19} />}
                        <span className="sr">{catName(cat)} {cat === 'ทั้งหมด' ? launcherGames.length : counts[cat]}</span>
                      </button>
                    );
                  })}
                </div>
                <span className="dialog-spacer" />
                <div className="gm-quick">
                  {quickApps.map((a) => (
                    <button key={a.id} className="gm-chip" onClick={() => launch(a)} onContextMenu={(e) => openCtx(e, a)} title={`เปิด ${a.title || a.name}`}>
                      <SmallIcon src={icons[a.platform] || a.icon} />
                    </button>
                  ))}
                  {ui && ui.steamRequest ? <button className="gm-chip txt steamreq-open" onClick={() => setSreq(true)} title="ขอให้ร้านโหลดเกม Steam ที่ยังไม่มีในเมนู"><Icon name="download" size={16} /> ขอเกม</button> : null}
                  <button className="gm-chip txt" onClick={handleLaunchRandom} title="สุ่มเกมที่ติดตั้งแล้วมาเล่น"><Icon name="shuffle" size={16} /> สุ่ม</button>
                  <button className="gm-chip" onClick={loadLauncherGames} title="โหลดรายชื่อเกมใหม่"><Icon name="refresh" size={17} /></button>
                </div>
              </div>

              <div className="gm-head">
                {q ? `ผลการค้นหา “${launcherSearch.trim()}”` : launcherCategory === 'ทั้งหมด' ? 'เกมทั้งหมด' : catName(launcherCategory)}
                <small>{filteredLauncherGames.length} เกม</small>
              </div>

              <div className="gamemenu-grid-container">
                {loadingLauncher ? (
                  <div className="loading-box">
                    <div className="spinner"></div>
                    <span>กำลังโหลดรายชื่อเกม…</span>
                  </div>
                ) : filteredLauncherGames.length === 0 ? (
                  <div className="empty-state">
                    <Icon name="gamepad" size={44} style={{ color: 'var(--gm-dim, #8b8b8b)' }} />
                    <span style={{ fontSize: '15px', fontWeight: 700 }}>{launcherSearch ? 'ไม่พบเกมที่ตรงกับคำค้นหา' : 'ยังไม่มีรายชื่อเกมในเครื่องนี้'}</span>
                    <small style={{ color: 'var(--text-muted)' }}>{launcherSearch ? 'ลองค้นหาด้วยคำอื่น หรือกดปุ่มด้านล่างเพื่อดูเกมทั้งหมด' : 'แจ้งพนักงานที่เคาน์เตอร์ได้เลย'}</small>
                    <button className="gm-chip txt" style={{ marginTop: '10px' }} onClick={launcherSearch ? () => setLauncherSearch('') : loadLauncherGames}>
                      {launcherSearch ? 'ดูเกมทั้งหมด' : <><Icon name="refresh" size={15} /> โหลดใหม่</>}
                    </button>
                  </div>
                ) : (
                  <div className="games-grid">
                    {filteredLauncherGames.map((game, idx) => {
                      const title = game.title || game.name || 'Game';
                      return (
                        <button key={game.id || idx} className="game-card" onClick={() => launch(game)} onContextMenu={(e) => openCtx(e, game)} title={`${title} · ${PLATFORM_LABELS[game.platform] || catName(catOf(game))}`}>
                          <Poster src={game.img} title={title} />
                          <span className="gc-badge"><SmallIcon src={badgeIcon(game)} /></span>
                          <span className="card-title">{title}</span>
                          <span className="play-overlay"><span className="play-btn"><Icon name="play" fill size={13} /> เล่นเกม</span></span>
                        </button>
                      );
                    })}
                  </div>
                )}
              </div>
            </main>

            {/* right column: shop banner (admin) · ID shop promo · featured · notice — hidden when the window is narrow, or ui.sidePanel=false */}
            {sidePanel ? (
            <aside className="gm-side">
              {adminBanner ? (
                <div className={`gm-ad${adminBanner.banner ? ' has-img' : ''}`} style={adminBanner.banner ? { backgroundImage: `url("${String(adminBanner.banner).replace(/"/g, '')}")` } : undefined}>
                  {adminBanner.bannerText ? <div className="gm-ad-cap">{adminBanner.bannerText}</div> : null}
                </div>
              ) : null}
              {ui && ui.hudBanner !== 'off' ? (
                <button className={`gm-ad promo${promoImg ? ' has-img' : ''}`} onClick={() => setActiveTab('shop')} style={promoImg ? { backgroundImage: `url("${String(promoImg).replace(/"/g, '')}")` } : undefined}>
                  <span className="gm-ad-tag">{ui.hudBannerTag}</span>
                  <span className="gm-ad-cap">{ui.hudBannerText}<small>กดเพื่อเปิดร้านไอดีเกม</small></span>
                </button>
              ) : null}
              {featured.length ? (
                <div className="gm-box">
                  <div className="gm-box-h"><Icon name="star" size={15} /> แนะนำจากร้าน</div>
                  {featured.map((g) => (
                    <button key={g.id} className="gm-feat" onClick={() => launch(g)} onContextMenu={(e) => openCtx(e, g)} title={g.title}>
                      <span className="gm-feat-img"><Poster src={g.img} title={g.title} /></span>
                      <span className="gm-feat-t">{g.title}</span>
                      <span className="gm-feat-go"><Icon name="play" fill size={12} /></span>
                    </button>
                  ))}
                </div>
              ) : null}
              {notice ? (
                <div className={`gm-box gm-notice ${noticeOpen ? 'open' : ''}`}>
                  <span className="gm-notice-text" ref={noticeRef}><Icon name="megaphone" size={15} /> {notice}</span>
                  {noticeLong || noticeOpen ? <button className="gm-more" onClick={() => setNoticeOpen(!noticeOpen)}>{noticeOpen ? 'ย่อ' : 'อ่านต่อ'}</button> : null}
                </div>
              ) : null}
            </aside>
            ) : null}

            {/* status pill: connection · PC · time left (or clock) · chat with the shop (not in menu-only / no right column) */}
            {sidePanel && !menuOnly ? (
            <div className="gm-pill">
              <span className={`gm-dot ${shopLinked ? 'on' : ''}`} title={shopLinked ? 'เชื่อมระบบร้านแล้ว' : 'เกมเมนูอย่างเดียว (ยังไม่เชื่อมระบบร้าน)'} />
              <span className="gm-pill-pc">{machineText}</span>
              {leftText ? <span>เหลือ <b className="gm-pill-time">{leftText}</b></span> : <span className="gm-pill-clock">{clock}</span>}
              <button className="gm-help" onClick={() => setActiveTab('chat')}>แชทร้าน</button>
            </div>
            ) : null}
          </div>
        )}

        {activeTab !== 'gamemenu' && !menuOnly && (
          <ShopTabs tab={activeTab} linked={shopLinked} site={shopSite} offsetMs={agent && agent.serverOffsetMs} onToast={showToast} onTab={setActiveTab} />
        )}
      </div>

      {ctx ? <GameCtxMenu ctx={ctx} onPlay={() => { const g = ctx.g; setCtx(null); launch(g); }} onReveal={revealCtx} onCopy={copyCtx} /> : null}

      {gfx ? <GfxPicker gfx={gfx} onSel={(sel) => setGfx((cur) => (cur ? { ...cur, sel } : cur))} onExtras={(extras) => setGfx((cur) => (cur ? { ...cur, extras } : cur))} onPlay={playGfx} onCancel={() => setGfx(null)} /> : null}
      {sreq ? <SteamReqModal onClose={() => setSreq(false)} /> : null}

      <div className={`toast-box ${toastVisible ? 'visible' : ''}`}>{toastMsg}</div>
    </div>
  );
}

// right-click menu of a game card: kept inside the window (flips left/up near the edges)
const CTX_W = 300;
const CTX_ITEM = { display: 'flex', alignItems: 'center', gap: 10, width: '100%', padding: '9px 12px', border: 'none', borderRadius: 9, background: 'transparent', color: '#e2e8f0', fontFamily: 'inherit', fontSize: 14, textAlign: 'left', cursor: 'pointer' };
function GameCtxMenu({ ctx, onPlay, onReveal, onCopy }) {
  const [hover, setHover] = useState('');
  const box = useRef(null);
  const [h, setH] = useState(200);   // real height after the first paint (a long path wraps to more lines)
  useEffect(() => { if (box.current) setH(box.current.offsetHeight); }, [ctx.path, ctx.err]);
  const vw = typeof window !== 'undefined' ? window.innerWidth : 1080;
  const vh = typeof window !== 'undefined' ? window.innerHeight : 680;
  const left = Math.max(8, Math.min(ctx.x, vw - CTX_W - 8));
  const top = Math.max(8, Math.min(ctx.y + h > vh ? ctx.y - h : ctx.y, vh - h - 8));
  const item = (key, on, label, icon, click) => (
    <button
      style={{ ...CTX_ITEM, opacity: on ? 1 : 0.45, cursor: on ? 'pointer' : 'default', background: on && hover === key ? 'rgba(0,240,255,0.12)' : 'transparent' }}
      disabled={!on}
      onMouseEnter={() => setHover(key)}
      onMouseLeave={() => setHover('')}
      onClick={click}
    >
      <span style={{ width: 20, textAlign: 'center' }}>{icon}</span>{label}
    </button>
  );
  return (
    <div
      ref={box}
      onMouseDown={(e) => e.stopPropagation()}
      onContextMenu={(e) => e.preventDefault()}
      style={{ position: 'fixed', left, top, width: CTX_W, zIndex: 200, padding: 6, borderRadius: 12, background: '#0c121e', border: '1px solid rgba(255,255,255,0.14)', boxShadow: '0 12px 32px rgba(0,0,0,0.55)', display: 'flex', flexDirection: 'column', gap: 2 }}
    >
      <div style={{ padding: '6px 12px 8px', borderBottom: '1px solid rgba(255,255,255,0.08)', marginBottom: 4 }}>
        <div style={{ fontWeight: 800, fontSize: 14, color: '#f8fafc', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{ctx.g.title || ctx.g.name}</div>
        <div style={{ fontSize: 12, color: ctx.err ? '#fca5a5' : '#94a3b8', wordBreak: 'break-all', marginTop: 2, userSelect: 'text', WebkitUserSelect: 'text' }}>{ctx.err || ctx.path || 'กำลังหาตำแหน่งไฟล์…'}</div>
      </div>
      {item('play', true, 'เล่นเกม', <Icon name="play" fill size={15} />, onPlay)}
      {item('reveal', !!ctx.path, 'เปิดตำแหน่งไฟล์', <Icon name="folder" size={16} />, onReveal)}
      {item('copy', !!ctx.path, ctx.copied ? 'คัดลอกแล้ว' : 'คัดลอกที่อยู่', <Icon name={ctx.copied ? 'check' : 'copy'} size={16} />, onCopy)}
    </div>
  );
}

// ── 17 Nov: graphics picker for GTA V / FiveM (owner: asked every time, 3 levels, lowest = the shop file, Enter = play).
// Look (owner's picture): rows with an icon tile, title + hint, check / switch on the right; line icons, no emoji.
const GFX_LEVELS = [
  { id: 'low', name: 'ต่ำสุด', hint: 'ลื่นที่สุด FPS สูงสุด เหมาะกับทุกเครื่อง', tag: 'แนะนำ', icon: 'bolt' },
  { id: 'medium', name: 'กลาง', hint: 'ภาพสวยขึ้น ยังลื่นบนการ์ดจอระดับกลาง', tag: '', icon: 'sliders' },
  { id: 'high', name: 'สูง', hint: 'สวยที่สุด สำหรับเครื่องสเปคแรง', tag: '', icon: 'diamond' },
];
const GFX = {
  acc: 'var(--gm-acc, #f7931e)',
  overlay: { position: 'fixed', inset: 0, zIndex: 300, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(5,4,3,0.66)', backdropFilter: 'blur(4px)' },
  panel: { width: 600, maxWidth: '94vw', maxHeight: '94vh', overflowY: 'auto', padding: 22, borderRadius: 20, fontFamily: 'var(--ui-font), inherit', color: '#f5f5f4',
    background: 'radial-gradient(120% 80% at 0% 0%, rgba(247,147,30,0.10), rgba(0,0,0,0) 55%), linear-gradient(180deg, #1b1612 0%, #110e0c 100%)',
    border: '1px solid rgba(255,255,255,0.07)', boxShadow: '0 30px 80px rgba(0,0,0,0.65)', outline: 'none' },
  label: { fontSize: 12, fontWeight: 600, letterSpacing: 0.6, color: 'rgba(245,245,244,0.45)', margin: '16px 2px 8px' },
  row: (on, dim) => ({ display: 'flex', alignItems: 'center', gap: 14, width: '100%', padding: '12px 14px', marginBottom: 8, borderRadius: 14, cursor: dim ? 'default' : 'pointer',
    textAlign: 'left', fontFamily: 'inherit', color: 'inherit', outline: 'none', opacity: dim ? 0.5 : 1, transition: 'background .15s, border-color .15s',
    background: on ? 'linear-gradient(90deg, rgba(247,147,30,0.20), rgba(247,147,30,0.05))' : 'rgba(255,255,255,0.025)',
    border: `1px solid ${on ? 'rgba(247,147,30,0.55)' : 'rgba(255,255,255,0.06)'}` }),
  tile: (on) => ({ flex: 'none', width: 44, height: 44, borderRadius: 12, display: 'flex', alignItems: 'center', justifyContent: 'center',
    color: on ? '#fff' : 'rgba(245,245,244,0.8)', boxShadow: on ? '0 6px 18px rgba(217,72,15,0.35)' : 'none',
    background: on ? 'linear-gradient(135deg, #f7931e, #d9480f)' : 'rgba(255,255,255,0.06)', border: on ? 'none' : '1px solid rgba(255,255,255,0.07)' }),
  title: { display: 'block', fontSize: 16, fontWeight: 700, lineHeight: 1.5 },
  hint: { display: 'block', fontSize: 13, lineHeight: 1.5, color: 'rgba(245,245,244,0.55)' },
  chip: { display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 12.5, lineHeight: 1.5, padding: '4px 10px', borderRadius: 999, background: 'rgba(255,255,255,0.05)', color: 'rgba(245,245,244,0.7)' },
};
function GfxRow({ icon, title, hint, on, right, onClick, onDoubleClick, className }) {
  return (
    <button className={className} style={GFX.row(on, false)} onClick={onClick} onDoubleClick={onDoubleClick}>
      <span style={GFX.tile(on)}><Icon name={icon} size={22} /></span>
      <span style={{ flex: 1, minWidth: 0 }}>
        <span style={GFX.title}>{title}</span>
        <span style={GFX.hint}>{hint}</span>
      </span>
      {right}
    </button>
  );
}
function GfxCheck({ on }) {
  return (
    <span style={{ flex: 'none', width: 24, height: 24, borderRadius: 999, display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: on ? GFX.acc : 'transparent', border: on ? 'none' : '1.5px solid rgba(255,255,255,0.22)', color: '#140b03' }}>
      {on ? <Icon name="check" size={15} style={{ strokeWidth: 2.6 }} /> : null}
    </span>
  );
}
function GfxSwitch({ on }) {
  return (
    <span style={{ flex: 'none', width: 44, height: 24, borderRadius: 999, position: 'relative', transition: 'background .15s', background: on ? GFX.acc : 'rgba(255,255,255,0.12)' }}>
      <span style={{ position: 'absolute', top: 3, left: on ? 23 : 3, width: 18, height: 18, borderRadius: 999, background: '#fff', transition: 'left .15s', boxShadow: '0 1px 4px rgba(0,0,0,0.4)' }} />
    </span>
  );
}
function GfxPicker({ gfx, onSel, onExtras, onPlay, onCancel }) {
  const box = useRef(null);
  useEffect(() => { if (box.current) box.current.focus(); }, []);
  useEffect(() => {
    const key = (e) => {
      const i = GFX_LEVELS.findIndex((l) => l.id === gfx.sel);
      if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); onCancel(); }
      else if (e.key === 'Enter') { e.preventDefault(); e.stopPropagation(); onPlay(gfx.sel); }
      else if (e.key === 'ArrowDown' || e.key === 'ArrowRight') { e.preventDefault(); onSel(GFX_LEVELS[Math.min(GFX_LEVELS.length - 1, i + 1)].id); }
      else if (e.key === 'ArrowUp' || e.key === 'ArrowLeft') { e.preventDefault(); onSel(GFX_LEVELS[Math.max(0, i - 1)].id); }
    };
    window.addEventListener('keydown', key, true);
    return () => window.removeEventListener('keydown', key, true);
  }, [gfx.sel, onSel, onPlay, onCancel]);
  const info = gfx.info;
  const five = gfx.five;
  const ex = gfx.extras || {};
  const setEx = (patch) => onExtras({ ...ex, ...patch });
  const level = GFX_LEVELS.find((l) => l.id === gfx.sel) || GFX_LEVELS[0];
  const showFive = !!(five && five.ok && ((five.reshade && five.reshade.available) || (five.mods && five.mods.length)));
  return (
    <div className="gfx-picker" style={GFX.overlay} onMouseDown={(e) => { if (e.target === e.currentTarget) onCancel(); }}>
      <div ref={box} tabIndex={-1} style={GFX.panel}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <span style={{ flex: 'none', width: 92, height: 58, borderRadius: 12, overflow: 'hidden', background: '#000', border: '1px solid rgba(255,255,255,0.08)' }}>
            {gfx.g.img ? <img src={gfx.g.img} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} draggable={false} /> : null}
          </span>
          <span style={{ flex: 1, minWidth: 0 }}>
            <span style={{ display: 'block', fontSize: 22, fontWeight: 800, lineHeight: 1.4 }}>เลือกระดับภาพ</span>
            <span style={{ display: 'block', fontSize: 14, color: 'rgba(245,245,244,0.6)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', lineHeight: 1.5 }}>{gfx.g.title || gfx.g.name}</span>
          </span>
          <button onClick={onCancel} title="ปิด (Esc)" style={{ flex: 'none', width: 34, height: 34, borderRadius: 10, border: '1px solid rgba(255,255,255,0.08)', background: 'rgba(255,255,255,0.04)', color: 'rgba(245,245,244,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <Icon name="x" size={16} />
          </button>
        </div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 12 }}>
          <span style={GFX.chip}><Icon name="monitor" size={14} />{!info ? 'กำลังตรวจจอ...' : info.error ? 'ตรวจจอไม่ได้ ใช้ค่าของร้าน' : `${info.width}x${info.height}${info.hz > 1 ? ` · ${info.hz}Hz` : ''}`}</span>
          {info && info.gpu ? <span style={GFX.chip}><Icon name="chip" size={14} />{info.gpu}</span> : null}
        </div>

        <div style={GFX.label}>ระดับภาพ</div>
        {GFX_LEVELS.map((l) => (
          <GfxRow key={l.id} className={`gfx-level gfx-${l.id}`} icon={l.icon} title={l.name} hint={l.hint} on={gfx.sel === l.id}
            onClick={() => onSel(l.id)} onDoubleClick={() => onPlay(l.id)}
            right={<span style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              {l.tag ? <span style={{ fontSize: 11.5, fontWeight: 700, lineHeight: 1.5, padding: '2px 9px', borderRadius: 999, background: 'rgba(247,147,30,0.16)', color: '#fbb04f' }}>{l.tag}</span> : null}
              <GfxCheck on={gfx.sel === l.id} />
            </span>} />
        ))}

        {showFive ? (
          <>
            <div style={GFX.label}>เสริมสำหรับ FiveM</div>
            {five.reshade && five.reshade.available ? (
              <GfxRow className="gfx-reshade" icon="aperture" title="ReShade ภาพสวย" on={!!ex.reshade}
                hint={ex.reshade ? 'สีสด คมชัดขึ้น · ในเกมกด Home ตั้งค่า / End เปิด-ปิดเอฟเฟกต์' : 'ปิดอยู่ · กดเพื่อติดตั้งตอนเข้าเกม (รีบูตเครื่องแล้วหายเอง)'}
                onClick={() => setEx({ reshade: !ex.reshade })} right={<GfxSwitch on={!!ex.reshade} />} />
            ) : null}
            {(five.mods || []).map((m) => {
              const on = !!(ex.mods && ex.mods[m.name]);
              return (
                <GfxRow key={m.name} className="gfx-mod" icon="road" title={`Mod ${m.name}`} on={on}
                  hint={on ? 'ติดตั้งลงเกมตอนกดเล่น · ปิดแล้วลบเฉพาะไฟล์ของม็อดนี้' : 'ปิดอยู่ · กดเพื่อติดตั้งลงในเกม'}
                  onClick={() => setEx({ mods: { ...(ex.mods || {}), [m.name]: !on } })} right={<GfxSwitch on={on} />} />
              );
            })}
          </>
        ) : null}

        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, marginTop: 14 }}>
          <span style={{ fontSize: 12.5, color: 'rgba(245,245,244,0.45)', lineHeight: 1.5 }}>Enter = เล่น · Esc = ยกเลิก · รีบูตแล้วกลับเป็นต่ำสุด</span>
          <span style={{ display: 'flex', gap: 8, flex: 'none' }}>
            <button onClick={onCancel} style={{ padding: '10px 16px', borderRadius: 12, border: '1px solid rgba(255,255,255,0.1)', background: 'transparent', color: 'rgba(245,245,244,0.75)', fontFamily: 'inherit', fontSize: 14, cursor: 'pointer' }}>ยกเลิก</button>
            <button className="gfx-play" onClick={() => onPlay(gfx.sel)} style={{ display: 'inline-flex', alignItems: 'center', gap: 8, padding: '10px 20px', borderRadius: 12, border: 'none', cursor: 'pointer', fontFamily: 'inherit', fontSize: 15, fontWeight: 800, color: '#fff', background: 'linear-gradient(135deg, #f7931e, #d9480f)', boxShadow: '0 8px 22px rgba(217,72,15,0.35)' }}>
              <Icon name="play" fill size={15} /> เล่น · ภาพ{level.name}
            </button>
          </span>
        </div>
      </div>
    </div>
  );
}

// ── 19 Nov (owner): "ขอเกม Steam" ── the customer sends a Steam link / AppID, the master downloads it after the customer
// approves the sign-in QR with the Steam app on their phone (their own account), then the game is in the menu after a reboot
const SR_ACTIVE = ['queued', 'checking', 'waiting-qr', 'downloading', 'verifying', 'importing'];
const SR_STATE = {
  queued: 'รอคิว', checking: 'กำลังตรวจ', 'waiting-qr': 'รอสแกน QR', downloading: 'กำลังโหลด', verifying: 'กำลังตรวจไฟล์',
  importing: 'กำลังเพิ่มเข้าคลัง', done: 'เสร็จแล้ว', exists: 'มีเกมนี้แล้ว', failed: 'ไม่สำเร็จ', canceled: 'ยกเลิกแล้ว',
};
function SrQr({ rows, size = 236 }) {
  const n = rows.length, q = 3, tot = n + q * 2;
  let d = '';
  rows.forEach((r, y) => { for (let x = 0; x < r.length; x++) if (r[x] === '1') d += `M${x + q} ${y + q}h1v1h-1z`; });
  return (
    <svg className="steamreq-qr" viewBox={`0 0 ${tot} ${tot}`} width={size} height={size} shapeRendering="crispEdges"
      style={{ display: 'block', background: '#fff', borderRadius: 14, flex: 'none' }}>
      <path d={d} fill="#000" />
    </svg>
  );
}
function SteamReqModal({ onClose }) {
  const api = typeof window !== 'undefined' && window.electronAPI ? window.electronAPI.steamReq : null;
  const [text, setText] = useState('');
  const [job, setJob] = useState(null);
  const [msg, setMsg] = useState('');
  const [busy, setBusy] = useState(false);
  const [fresh, setFresh] = useState(false);   // "ขอเกมอื่น": show the form even though a finished job is still listed
  const [kick, setKick] = useState(0);         // poll again now (after send / cancel)
  const [now, setNow] = useState(0);
  const box = useRef(null);
  const inp = useRef(null);
  useEffect(() => {
    let stop = false, timer = null;
    const tick = async () => {
      if (!api) return;
      const r = await api.job().catch(() => null);
      if (stop) return;
      if (r && r.ok) { setJob(r.job || null); if (r.on === false) setMsg('ร้านปิดระบบขอเกมไว้'); }
      else if (r && r.message) setMsg(r.message);
      timer = setTimeout(tick, r && r.job && SR_ACTIVE.includes(r.job.state) ? 1500 : 5000);
    };
    tick();
    return () => { stop = true; if (timer) clearTimeout(timer); };
  }, [api, kick]);
  useEffect(() => { setNow(Date.now()); const t = setInterval(() => setNow(Date.now()), 1000); return () => clearInterval(t); }, []);
  useEffect(() => {
    const key = (e) => { if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); onClose(); } };
    window.addEventListener('keydown', key, true);
    return () => window.removeEventListener('keydown', key, true);
  }, [onClose]);
  const active = !!(job && SR_ACTIVE.includes(job.state));
  const view = active ? job : (fresh ? null : job);
  useEffect(() => { if (!view && inp.current) inp.current.focus(); else if (box.current) box.current.focus(); }, [!!view]);
  async function send() {
    if (!api || busy || !text.trim()) return;
    setBusy(true); setMsg('');
    const r = await api.send(text.trim()).catch(() => null);
    setBusy(false);
    if (r && r.job) { setJob(r.job); setFresh(false); }
    if (!r) setMsg('ติดต่อเครื่องแม่ไม่ได้');
    else if (!r.ok) setMsg(r.message || 'ส่งคำขอไม่สำเร็จ');
    else setText('');
    setKick((k) => k + 1);
  }
  async function cancel() {
    if (!api || busy) return;
    setBusy(true);
    const r = await api.cancel().catch(() => null);
    setBusy(false);
    if (r && r.message) setMsg(r.message);
    setKick((k) => k + 1);
  }
  let left = '';
  if (view && view.state === 'waiting-qr' && view.qrUntil && now) {
    const s = Math.max(0, Math.round((new Date(String(view.qrUntil).replace(' ', 'T')).getTime() - now) / 1000));
    left = `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
  }
  const bar = view && (view.state === 'downloading' || view.state === 'verifying' || view.state === 'importing');
  const good = view && (view.state === 'done' || view.state === 'exists');
  const bad = view && (view.state === 'failed' || view.state === 'canceled');
  const btn = { padding: '10px 16px', borderRadius: 12, border: '1px solid rgba(255,255,255,0.1)', background: 'transparent', color: 'rgba(245,245,244,0.75)', fontFamily: 'inherit', fontSize: 14, cursor: 'pointer' };
  const main = { display: 'inline-flex', alignItems: 'center', gap: 8, padding: '10px 20px', borderRadius: 12, border: 'none', cursor: 'pointer', fontFamily: 'inherit', fontSize: 15, fontWeight: 800, color: '#fff', background: 'linear-gradient(135deg, #f7931e, #d9480f)', boxShadow: '0 8px 22px rgba(217,72,15,0.35)' };
  return (
    <div className="steamreq" style={GFX.overlay} onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div ref={box} tabIndex={-1} style={{ ...GFX.panel, width: 620 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <span style={GFX.tile(true)}><Icon name="download" size={22} /></span>
          <span style={{ flex: 1, minWidth: 0 }}>
            <span style={{ display: 'block', fontSize: 22, fontWeight: 800, lineHeight: 1.4 }}>ขอเกม Steam</span>
            <span style={{ display: 'block', fontSize: 14, color: 'rgba(245,245,244,0.6)', lineHeight: 1.5 }}>เกมที่ยังไม่มีในร้าน ร้านโหลดให้ด้วยบัญชี Steam ของคุณ</span>
          </span>
          <button onClick={onClose} title="ปิด (Esc)" style={{ flex: 'none', width: 34, height: 34, borderRadius: 10, border: '1px solid rgba(255,255,255,0.08)', background: 'rgba(255,255,255,0.04)', color: 'rgba(245,245,244,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <Icon name="x" size={16} />
          </button>
        </div>

        {!view ? (
          <>
            <div style={GFX.label}>ลิงก์หน้าเกม Steam หรือเลข AppID</div>
            <input ref={inp} className="steamreq-input" value={text} onChange={(e) => setText(e.target.value)} spellCheck={false} autoComplete="off"
              onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); send(); } }}
              placeholder="เช่น https://store.steampowered.com/app/570/Dota_2/ หรือ 570"
              style={{ width: '100%', boxSizing: 'border-box', padding: '12px 14px', borderRadius: 12, fontFamily: 'inherit', fontSize: 15, color: '#f5f5f4', outline: 'none', background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.12)' }} />
            <div style={GFX.label}>ขั้นตอน</div>
            {[['download', 'ส่งลิงก์หรือ AppID ของเกม', 'คัดลอกลิงก์จากหน้าเกมใน Steam (store.steampowered.com/app/...)'],
              ['scan', 'สแกน QR ด้วยแอป Steam บนมือถือ', 'ต้องเป็นบัญชีที่มีเกมนี้ · ยืนยันเพื่อให้ร้านโหลดครั้งนี้เท่านั้น ร้านไม่เก็บบัญชีหรือรหัสผ่าน'],
              ['refresh', 'โหลดเสร็จแล้วรีบูตเครื่อง', 'เกมจะขึ้นในเมนูหลังรีบูต (เกมใหญ่ใช้เวลานาน ปิดหน้าต่างนี้ได้ เปิดกลับมาดูสถานะได้)']].map(([ic, t, h]) => (
              <div key={t} style={{ ...GFX.row(false, false), cursor: 'default' }}>
                <span style={GFX.tile(false)}><Icon name={ic} size={22} /></span>
                <span style={{ flex: 1, minWidth: 0 }}><span style={GFX.title}>{t}</span><span style={GFX.hint}>{h}</span></span>
              </div>
            ))}
          </>
        ) : (
          <div className={`steamreq-job steamreq-${view.state}`} style={{ marginTop: 16, padding: 16, borderRadius: 16, background: 'rgba(255,255,255,0.03)', border: `1px solid ${good ? 'rgba(74,222,128,0.35)' : bad ? 'rgba(248,113,113,0.35)' : 'rgba(255,255,255,0.07)'}` }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <span style={{ flex: 1, minWidth: 0, fontSize: 17, fontWeight: 800, lineHeight: 1.5, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{view.name || `AppID ${view.app}`}</span>
              <span style={{ ...GFX.chip, flex: 'none', color: good ? '#86efac' : bad ? '#fca5a5' : '#fbb04f', background: good ? 'rgba(74,222,128,0.12)' : bad ? 'rgba(248,113,113,0.12)' : 'rgba(247,147,30,0.14)' }}>
                {SR_STATE[view.state] || view.state}{view.state === 'queued' && view.queuePos > 1 ? ` · คิวที่ ${view.queuePos}` : ''}
              </span>
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 8 }}>
              <span style={GFX.chip}>AppID {view.app}</span>
              {view.sizeGB ? <span style={GFX.chip}>ประมาณ {view.sizeGB} GB</span> : null}
              {view.drive ? <span style={GFX.chip}>ไดรฟ์ {view.drive}</span> : null}
            </div>
            {view.state === 'waiting-qr' && view.qr && view.qr.length ? (
              <div style={{ display: 'flex', gap: 18, alignItems: 'center', marginTop: 14 }}>
                <SrQr rows={view.qr} />
                <span style={{ flex: 1, minWidth: 0, fontSize: 14, lineHeight: 1.7, color: 'rgba(245,245,244,0.8)' }}>
                  <b style={{ display: 'block', fontSize: 16, color: '#f5f5f4' }}>สแกนด้วยแอป Steam บนมือถือ</b>
                  1. เปิดแอป Steam (บัญชีที่มีเกมนี้)<br />2. แตะไอคอนโล่ Steam Guard<br />3. สแกน QR นี้ แล้วกดอนุมัติ
                  {left ? <span style={{ display: 'block', marginTop: 8, color: '#fbb04f' }}>QR หมดเวลาใน {left}</span> : null}
                </span>
              </div>
            ) : null}
            <div style={{ fontSize: 14, lineHeight: 1.6, marginTop: 12, color: good ? '#bbf7d0' : bad ? '#fecaca' : 'rgba(245,245,244,0.75)' }}>{view.message}</div>
            {bar ? (
              <div style={{ marginTop: 10 }}>
                <div style={{ height: 10, borderRadius: 999, background: 'rgba(255,255,255,0.08)', overflow: 'hidden' }}>
                  <div className="steamreq-bar" style={{ width: `${Math.max(2, Math.min(100, view.progress || 0))}%`, height: '100%', borderRadius: 999, background: 'linear-gradient(90deg, #f7931e, #d9480f)', transition: 'width .6s' }} />
                </div>
                <div style={{ fontSize: 12.5, color: 'rgba(245,245,244,0.5)', marginTop: 4 }}>{view.progress || 0}%</div>
              </div>
            ) : null}
          </div>
        )}

        {msg ? <div className="steamreq-msg" style={{ marginTop: 12, fontSize: 14, lineHeight: 1.6, color: '#fecaca' }}>{msg}</div> : null}

        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, marginTop: 16 }}>
          <span style={{ fontSize: 12.5, color: 'rgba(245,245,244,0.45)', lineHeight: 1.5 }}>Esc = ปิดหน้าต่าง (งานยังโหลดต่อ)</span>
          <span style={{ display: 'flex', gap: 8, flex: 'none' }}>
            {active ? <button className="steamreq-cancel" onClick={cancel} disabled={busy} style={btn}>ยกเลิกคำขอ</button> : null}
            {!view ? (
              <button className="steamreq-send" onClick={send} disabled={busy || !text.trim()} style={{ ...main, opacity: busy || !text.trim() ? 0.55 : 1 }}>
                <Icon name="download" size={16} /> {busy ? 'กำลังส่ง…' : 'ส่งคำขอ'}
              </button>
            ) : !active ? (
              <button className="steamreq-again" onClick={() => { setFresh(true); setMsg(''); }} style={main}>ขอเกมอื่น</button>
            ) : (
              <button onClick={onClose} style={main}>ปิด</button>
            )}
          </span>
        </div>
      </div>
    </div>
  );
}

export default function DialogPage() {
  return (
    <Suspense fallback={<div style={{ color: '#fff', padding: 20 }}>กำลังโหลด...</div>}>
      <DialogContent />
    </Suspense>
  );
}
