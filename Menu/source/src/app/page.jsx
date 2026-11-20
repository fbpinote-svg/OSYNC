'use client';

import { useState, useEffect, useRef } from 'react';
import { sessionService } from '../lib/api';
import { getBrandConfig, applyUi } from '../lib/config';

export default function Home() {
  // ── Core State ──
  const [brand, setBrand] = useState({ name: '0JAYSHOP', badge: 'VIP', logoUrl: '' });
  const [session, setSession] = useState({ machineId: 'PC-12', tier: 'Guest', lanSpeed: '...' });
  const [loadingSession, setLoadingSession] = useState(true);
  const [totalSec, setTotalSec] = useState(0);
  const [usedSec, setUsedSec] = useState(0);
  // (the old mute button only flipped its own icon - removed)

  // ── Look (config.json "ui"): font + zoom; the window height follows the page so nothing sinks under the edge ──
  const [ui, setUi] = useState(null);
  const cardRef = useRef(null);
  useEffect(() => {
    setUi(applyUi('hud'));
    const el = cardRef.current;
    const fit = typeof window !== 'undefined' && window.electronAPI?.fitHud;
    if (!el || !fit) return undefined;
    let last = 0;
    const send = () => {
      const h = Math.ceil(el.getBoundingClientRect().height);   // window pixels (includes the zoom)
      if (h && h !== last) { last = h; fit(h); }
    };
    const ro = new ResizeObserver(send);
    ro.observe(el);
    document.fonts?.ready.then(send);
    return () => ro.disconnect();
  }, []);

  // ── UI State ──
  const [toastMsg, setToastMsg] = useState('');
  const [toastVisible, setToastVisible] = useState(false);
  const [showLogoutConfirm, setShowLogoutConfirm] = useState(false);

  // ── Shop system (Cooper Agent 1.20+): live rental from the agent; the hidden settings form is gone (customers could open it) ──
  const [agent, setAgent] = useState(null);
  const [nowMs, setNowMs] = useState(Date.now());
  useEffect(() => {
    const a = typeof window !== 'undefined' && window.electronAPI?.agent;
    if (a) {
      a.get().then(setAgent);
      a.onUpdate(setAgent);
    }
    const t = setInterval(() => setNowMs(Date.now()), 1000);
    return () => clearInterval(t);
  }, []);
  const integrated = !!(agent && agent.integrated);
  const sess = integrated ? agent.session : null;

  // ── Init Brand & Session ──
  useEffect(() => {
    const b = getBrandConfig();
    setBrand(b);

    sessionService.getSession().then((sess) => {
      setLoadingSession(false);
      if (sess) {
        setSession(sess);
        if (typeof sess.totalSec === 'number') setTotalSec(sess.totalSec);
        if (typeof sess.usedSec === 'number') setUsedSec(sess.usedSec);
      }
    });
  }, []);

  // ── Timer Tick + Heartbeat (every 30s) ──
  useEffect(() => {
    const timer = setInterval(() => {
      setUsedSec((prev) => {
        if (prev < totalSec) {
          const next = prev + 1;
          if (next % 30 === 0) sessionService.heartbeat(next).catch(() => {});
          return next;
        }
        return prev;
      });
    }, 1000);
    return () => clearInterval(timer);
  }, [totalSec]);

  // ── IPC Listeners (Order, TopUp, Settings) ──
  useEffect(() => {
    if (typeof window === 'undefined') return;
    if (window.electronAPI?.onOrderNotify) {
      window.electronAPI.onOrderNotify((d) => {
        if (d && d.text) showToast(`✓ ${d.text}`);
      });
    }
  }, []);

  // ── Computed ──
  // connected to the shop: times come from the rental (server clock = local clock + agent offset); offline: old counters
  let shownTotal = totalSec;
  let shownUsed = usedSec;
  let leftSec = Math.max(0, totalSec - usedSec);
  if (integrated) {
    if (sess && sess.startedAt) {
      const serverNow = nowMs + (Number(agent.serverOffsetMs) || 0);
      shownUsed = Math.max(0, Math.floor((serverNow - sess.startedAt) / 1000));
      leftSec = sess.endsAt ? Math.max(0, Math.floor((sess.endsAt - serverNow) / 1000)) : 0;
      shownTotal = shownUsed + leftSec;
    } else {
      shownTotal = 0; shownUsed = 0; leftSec = 0;
    }
  }
  const progressPct = shownTotal > 0 ? Math.min(100, (leftSec / shownTotal) * 100) : 0;
  const whoText = integrated ? (sess ? (sess.source === 'guest' ? (sess.coupon ? `คูปอง ${sess.coupon}` : 'ลูกค้าทั่วไป') : sess.user || 'สมาชิก') : 'ว่าง') : session.tier;
  const machineText = integrated ? agent.machineName : session.machineId;
  const statusText = integrated ? (agent.online ? (sess && sess.mode === 'credit' ? `เครดิต ${sess.balanceText}` : 'ONLINE') : 'ออฟไลน์') : loadingSession ? 'กำลังเชื่อมต่อ...' : session.lanSpeed || 'Online';
  const logoutNote = !integrated || !sess
    ? 'เวลาที่เหลือจะถูกบันทึกเก็บไว้ในบัญชีสมาชิก'
    : sess.source === 'pc'
      ? 'เวลาที่เหลือของแพ็กเกจจะเก็บเข้า “เวลาสะสม” ใช้ครั้งหน้ากับเครื่องราคาเท่าเครื่องนี้หรือถูกกว่า'
      : sess.source === 'guest'
        ? sess.coupon
          // 14 พ.ย.: บอกกติกาให้ครบ — เวลาที่เล่นไปคิดราคารายชั่วโมง (ไม่ใช่ราคาแพ็กเกจ) · เงินสดที่จ่ายเพิ่มไม่คืนเข้าคูปอง
          ? `คืนเงินเข้าคูปอง ${sess.coupon} = ยอดที่จ่ายด้วยคูปอง หักค่าเวลาที่เล่นไป (คิดราคารายชั่วโมง ไม่ใช่ราคาแพ็กเกจ) — ใช้ครั้งหน้าได้`
          : 'ลูกค้าทั่วไปเก็บเวลาไม่ได้ — เวลาที่เหลือจะหายไป'
        : 'จบการเช่าเหมือนกด “เลิกเล่น” บนเว็บร้าน';

  // ── Helpers ──
  function formatTime(s) {
    const h = String(Math.floor(s / 3600)).padStart(2, '0');
    const m = String(Math.floor((s % 3600) / 60)).padStart(2, '0');
    const sec = String(s % 60).padStart(2, '0');
    return `${h}:${m}:${sec}`;
  }

  function showToast(msg) {
    setToastMsg(msg);
    setToastVisible(true);
    setTimeout(() => setToastVisible(false), 2400);
  }

  function handleOpenDialog(tab) {
    if (window.electronAPI?.openDialog) {
      window.electronAPI.openDialog(tab);
    } else {
      showToast(`เปิดหน้าต่าง: ${tab}`);
    }
  }

  function handleMinimize() {
    if (window.electronAPI?.minimize) {
      window.electronAPI.minimize();
    }
  }

  function handleClose() {
    if (window.electronAPI?.close) {
      showToast('✓ ซ่อนไปที่ System Tray แล้ว');
      setTimeout(() => window.electronAPI.close(), 300);
    }
  }

  async function handleConfirmLogout() {
    setShowLogoutConfirm(false);
    if (integrated && sess) {
      // end the rental through the shop system; the lock screen comes back by itself when the agent sees it
      const call = () => window.electronAPI.agent.api('POST', 'logout', {});
      let r = await call();
      if (!r.ok && r.status === 409) { await new Promise((ok) => setTimeout(ok, 2500)); r = await call(); }   // menu token still being renewed
      if (r.ok) {
        const banked = Number(r.data && r.data.bankedSec) || 0;
        const back = Number(r.data && r.data.couponRefund) || 0;
        const fmt = (s) => `฿${(s / 100).toLocaleString('th-TH', { maximumFractionDigits: 2 })}`;
        showToast(
          back > 0
            ? `✓ ออกจากระบบแล้ว · คืนเข้าคูปอง ${fmt(back)} (ยอดตอนนี้ ${fmt(Number(r.data.couponBalance) || 0)})`
            : banked >= 60 ? `✓ ออกจากระบบแล้ว · เก็บเวลา ${Math.floor(banked / 60)} นาที (ใช้กับเครื่องราคาเท่านี้หรือถูกกว่า)` : '✓ ออกจากระบบแล้ว',
        );
      } else {
        showToast(`ออกจากระบบไม่สำเร็จ: ${(r.data && r.data.error) || 'ลองใหม่อีกครั้ง'}`);
      }
      return;
    }
    await sessionService.logout();
    handleClose();
  }

  // ── Render ──
  return (
    <div className="app-card hud" ref={cardRef}>
      {/* Header (long shop names end with … instead of wrapping) */}
      <div className="header drag-zone">
        <div className="brand" title={brand.name}>
          {brand.markUrl || brand.logoUrl ? (
            <img src={brand.markUrl || brand.logoUrl} alt="" className="brand-logo-img" />
          ) : (
            <div className="brand-icon">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="#ffffff">
                <path d="M21 6H3c-1.1 0-2 .9-2 2v8c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-10 7H8v3H6v-3H3v-2h3V8h2v3h3v2zm4.5 2c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zm4-3c-.83 0-1.5-.67-1.5-1.5S18.67 9 19.5 9s1.5.67 1.5 1.5-.67 1.5-1.5 1.5z" />
              </svg>
            </div>
          )}
          <span className="brand-text">{brand.name}</span>
          {brand.badge ? <span className="badge-admin">{brand.badge}</span> : null}
        </div>
        <div className="window-controls no-drag">
          <button className="win-btn" title="ย่อหน้าต่าง" onClick={handleMinimize}>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M19 13H5v-2h14v2z" /></svg>
          </button>
          <button className="win-btn close" title="ซ่อนไปที่ System Tray" onClick={handleClose}>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z" /></svg>
          </button>
        </div>
      </div>

      {/* Status Ribbon */}
      <div className="status-ribbon drag-zone" title={`เครื่อง ${machineText}${whoText ? ` · ${whoText}` : ''}`}>
        <span className="status-dot" />
        <span className="status-who">เครื่อง <b>{machineText}</b>{whoText ? ` · ${whoText}` : ''}</span>
        <span className="status-state">{statusText}</span>
      </div>

      {/* Time Dashboard: time left big, total / used on one small row */}
      <div className="time-hud">
        <div className="time-main">
          <span className="time-title">เวลาคงเหลือ</span>
          <span className="time-big">{formatTime(leftSec)}</span>
        </div>
        <div className="meter-bar">
          <div className="meter-fill" style={{ width: `${progressPct}%` }} />
        </div>
        <div className="time-mini">
          <span>ทั้งหมด<b>{formatTime(shownTotal)}</b></span>
          <span>ใช้ไป<b>{formatTime(shownUsed)}</b></span>
        </div>
      </div>

      {/* 6-Card Grid (3×2) */}
      <div className="menu-grid">
        <div className="item-card" onClick={() => handleOpenDialog('shop')}>
          <div className="icon-box c-shop">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="#fff"><path d="M21 6H3c-1.1 0-2 .9-2 2v8c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-10 7H8v3H6v-3H3v-2h3V8h2v3h3v2zm4.5 2c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zm4-3c-.83 0-1.5-.67-1.5-1.5S18.67 9 19.5 9s1.5.67 1.5 1.5-.67 1.5-1.5 1.5z" /></svg>
          </div>
          <span className="item-label">ซื้อไอดีเกม</span>
        </div>
        <div className="item-card" onClick={() => handleOpenDialog('inventory')}>
          <div className="icon-box c-inventory">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="#fff"><path d="M12.65 10C11.83 7.67 9.61 6 7 6c-3.31 0-6 2.69-6 6s2.69 6 6 6c2.61 0 4.83-1.67 5.65-4H17v4h4v-4h2v-4H12.65zM7 14c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2z" /></svg>
          </div>
          <span className="item-label">คลังรหัส</span>
        </div>
        <div className="item-card" onClick={() => handleOpenDialog('chat')}>
          <div className="icon-box c-chat">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="#fff"><path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-2 12H6v-2h12v2zm0-3H6V9h12v2zm0-3H6V6h12v2z" /></svg>
          </div>
          <span className="item-label">แชทแอดมิน</span>
        </div>
        <div className="item-card" onClick={() => handleOpenDialog('topup')}>
          <div className="icon-box c-topup">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="#fff"><path d="M21 18v1c0 1.1-.9 2-2 2H5c-1.11 0-2-.9-2-2V5c0-1.1.89-2 2-2h14c1.1 0 2 .9 2 2v1h-9c-1.11 0-2 .9-2 2v8c0 1.1.89 2 2 2h9zm-9-2h10V8H12v8zm4-2.5c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5z" /></svg>
          </div>
          <span className="item-label">{integrated && sess && sess.source === 'guest' ? 'ต่อเวลา' : 'เติมเงิน'}</span>
        </div>
        <div className="item-card" onClick={() => handleOpenDialog('gamemenu')}>
          <div className="icon-box c-gamemenu">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="#fff"><path d="M21.58 16.09l-1.09-7.66C20.21 6.46 18.52 5 16.53 5H7.47C5.48 5 3.79 6.46 3.51 8.43l-1.09 7.66C2.2 17.63 3.39 19 4.94 19c.68 0 1.32-.27 1.8-.75L9 16h6l2.25 2.25c.48.48 1.13.75 1.8.75 1.56 0 2.75-1.37 2.53-2.91zM11 11H9v2H8v-2H6v-1h2V8h1v2h2v1zm4-1c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1zm2 3c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1z" /></svg>
          </div>
          <span className="item-label">เกมเมนู</span>
        </div>
        <div className="item-card" onClick={() => setShowLogoutConfirm(true)}>
          <div className="icon-box c-logout">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="#fff"><path d="M10.09 15.59L11.5 17l5-5-5-5-1.41 1.41L12.67 11H3v2h9.67l-2.58 2.59zM19 3H5c-1.11 0-2 .9-2 2v4h2V5h14v14H5v-4H3v4c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z" /></svg>
          </div>
          <span className="item-label">ออกจากระบบ</span>
        </div>
      </div>

      {/* Promo Banner: the shop's own picture + text (config.json ui.hudBanner / hudBannerText), works offline.
          No picture set = gradient card · "off" = hidden (the window gets shorter by itself) */}
      {ui && ui.hudBanner !== 'off' ? (
        <div className={`ad-card${ui.hudBanner ? '' : ' no-img'}`} onClick={() => handleOpenDialog('shop')} title={ui.hudBannerText}>
          {ui.hudBanner ? <img src={ui.hudBanner} alt="" onError={(e) => { e.currentTarget.style.display = 'none'; }} /> : null}
          <span className="ad-tag">{ui.hudBannerTag}</span>
          <div className="ad-caption">{ui.hudBannerText}</div>
        </div>
      ) : null}

      {/* Dock Toolbar */}
      <div className="dock">
        <div className="dock-grp">
          <button className="dock-action" onClick={() => handleOpenDialog('account')} title="บัญชีของฉัน">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" /></svg>
            <span>บัญชีของฉัน</span>
          </button>
        </div>
        <div className="dock-grp">
          <button className="dock-action" onClick={() => handleOpenDialog('shop')} title="ร้านไอดีเกม">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M21 6H3c-1.1 0-2 .9-2 2v8c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-10 7H8v3H6v-3H3v-2h3V8h2v3h3v2zm4.5 2c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zm4-3c-.83 0-1.5-.67-1.5-1.5S18.67 9 19.5 9s1.5.67 1.5 1.5-.67 1.5-1.5 1.5z" /></svg>
            <span>ร้านไอดีเกม</span>
          </button>
        </div>
      </div>

      {/* Logout Confirm Modal */}
      {showLogoutConfirm && (
        <div className="modal-overlay">
          <div className="modal-head">
            <div className="modal-title" style={{ color: 'var(--accent-orange)' }}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M10 17l5-5-5-5v3H3v4h7v3z" /></svg>
              ยืนยันออกจากระบบ
            </div>
            <button className="win-btn close" onClick={() => setShowLogoutConfirm(false)}>✕</button>
          </div>
          <div className="modal-body" style={{ textAlign: 'center', gap: '10px' }}>
            <p style={{ fontSize: '12px', fontWeight: 500, color: '#cbd5e1', lineHeight: '1.4' }}>
              คุณต้องการจบการใช้งานและออกจากระบบทันทีหรือไม่?<br />
              <span style={{ fontSize: '11px', color: '#94a3b8' }}>{logoutNote}</span>
            </p>
            <div style={{ display: 'flex', justifyContent: 'center', gap: '8px' }}>
              <button className="btn-buy" style={{ background: 'rgba(255,255,255,0.1)' }} onClick={() => setShowLogoutConfirm(false)}>ยกเลิก</button>
              <button className="btn-buy" style={{ background: 'linear-gradient(135deg, #f97316, #ef4444)' }} onClick={handleConfirmLogout}>ยืนยัน ออกจากระบบ</button>
            </div>
          </div>
        </div>
      )}

      {/* (hidden settings form removed: brand/API now come from config.json and the shop system - customers could change them) */}

      {/* Toast */}
      <div className={`toast-box ${toastVisible ? 'visible' : ''}`}>{toastMsg}</div>
    </div>
  );
}
