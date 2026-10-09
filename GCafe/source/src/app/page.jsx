'use client';

import { useState, useEffect } from 'react';
import { sessionService } from '../lib/api';
import {
  getBrandConfig,
  setBrandConfig,
  getApiBaseUrl,
  setApiBaseUrl,
  getMachineId,
  setMachineId,
} from '../lib/config';

export default function Home() {
  // ── Core State ──
  const [brand, setBrand] = useState({ name: '0JAYSHOP', badge: 'VIP', logoUrl: '' });
  const [session, setSession] = useState({ machineId: 'PC-12', tier: 'Guest', lanSpeed: '...' });
  const [loadingSession, setLoadingSession] = useState(true);
  const [totalSec, setTotalSec] = useState(0);
  const [usedSec, setUsedSec] = useState(0);
  const [isMuted, setIsMuted] = useState(false);

  // ── UI State ──
  const [toastMsg, setToastMsg] = useState('');
  const [toastVisible, setToastVisible] = useState(false);
  const [showLogoutConfirm, setShowLogoutConfirm] = useState(false);
  const [showSettings, setShowSettings] = useState(false);

  // ── Hidden Settings Form ──
  const [formBrandName, setFormBrandName] = useState('');
  const [formBrandBadge, setFormBrandBadge] = useState('');
  const [formBrandLogo, setFormBrandLogo] = useState('');
  const [formMachineId, setFormMachineId] = useState('');
  const [formApiUrl, setFormApiUrl] = useState('');

  // ── Admin Hotkey: Ctrl+Shift+S ──
  useEffect(() => {
    const onKeyDown = (e) => {
      if (e.ctrlKey && e.shiftKey && e.key.toLowerCase() === 's') {
        e.preventDefault();
        setShowSettings((prev) => !prev);
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, []);

  // ── Init Brand & Session ──
  useEffect(() => {
    const b = getBrandConfig();
    setBrand(b);
    setFormBrandName(b.name);
    setFormBrandBadge(b.badge);
    setFormBrandLogo(b.logoUrl);
    setFormMachineId(getMachineId());
    setFormApiUrl(getApiBaseUrl());

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
        showToast(`✓ สั่งซื้อสำเร็จ! (${d.items.length} รายการ ฿${d.total}) ดูที่คลังรหัส`);
      });
    }
    if (window.electronAPI?.onTimeAdded) {
      window.electronAPI.onTimeAdded((sec) => {
        setTotalSec((prev) => prev + sec);
        showToast(`✓ เติมเวลาสำเร็จ +${Math.round(sec / 3600)} ชม.`);
      });
    }
    if (window.electronAPI?.onOpenSettings) {
      window.electronAPI.onOpenSettings(() => setShowSettings(true));
    }
  }, []);

  // ── Computed ──
  const leftSec = Math.max(0, totalSec - usedSec);
  const progressPct = totalSec > 0 ? Math.min(100, (leftSec / totalSec) * 100) : 0;

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
    await sessionService.logout();
    if (window.electronAPI?.quitApp) {
      window.electronAPI.quitApp();
    } else {
      handleClose();
    }
  }

  function handleSaveSettings() {
    const newBrand = {
      name: formBrandName.trim() || '0JAYSHOP',
      badge: formBrandBadge.trim() || 'VIP',
      logoUrl: formBrandLogo.trim(),
    };
    setBrand(newBrand);
    setBrandConfig(newBrand);
    if (formMachineId.trim()) {
      setMachineId(formMachineId.trim());
      setSession((prev) => ({ ...prev, machineId: formMachineId.trim() }));
    }
    if (formApiUrl.trim()) setApiBaseUrl(formApiUrl.trim());
    setShowSettings(false);
    showToast('✓ บันทึกการตั้งค่าแล้ว');

    setLoadingSession(true);
    sessionService.getSession().then((sess) => {
      setLoadingSession(false);
      if (sess) {
        setSession(sess);
        if (typeof sess.totalSec === 'number') setTotalSec(sess.totalSec);
        if (typeof sess.usedSec === 'number') setUsedSec(sess.usedSec);
      }
    });
  }

  // ── Render ──
  return (
    <div className="app-card">
      {/* Header */}
      <div className="header drag-zone">
        <div
          className="brand no-drag"
          title="0JAYSHOP"
          onContextMenu={(e) => { e.preventDefault(); setShowSettings(true); }}
        >
          {brand.logoUrl ? (
            <img src={brand.logoUrl} alt={brand.name} className="brand-logo-img" />
          ) : (
            <div className="brand-icon">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="#ffffff">
                <path d="M21 6H3c-1.1 0-2 .9-2 2v8c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-10 7H8v3H6v-3H3v-2h3V8h2v3h3v2zm4.5 2c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zm4-3c-.83 0-1.5-.67-1.5-1.5S18.67 9 19.5 9s1.5.67 1.5 1.5-.67 1.5-1.5 1.5z" />
              </svg>
            </div>
          )}
          <span className="brand-text">{brand.name}</span>
          <span className="badge-admin">{brand.badge}</span>
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
      <div className="status-ribbon drag-zone">
        <div>
          <span className="status-dot" />
          <span>เครื่อง: <b>{session.machineId}</b> {session.tier && `(${session.tier})`}</span>
        </div>
        <span style={{ fontSize: '11px', fontWeight: 600, color: '#94a3b8' }}>
          {loadingSession ? 'กำลังเชื่อมต่อ...' : session.lanSpeed || 'Online'}
        </span>
      </div>

      {/* Time Dashboard */}
      <div className="time-hud">
        <div className="time-row">
          <span className="time-title">เวลาทั้งหมด</span>
          <span className="time-digits">{formatTime(totalSec)}</span>
        </div>
        <div className="time-row">
          <span className="time-title">เวลาที่ใช้ไป</span>
          <span className="time-digits">{formatTime(usedSec)}</span>
        </div>
        <div className="time-row active-left">
          <span className="time-title">เวลาคงเหลือ</span>
          <span className="time-digits">{formatTime(leftSec)}</span>
        </div>
        <div className="meter-bar">
          <div className="meter-fill" style={{ width: `${progressPct}%` }} />
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
          <span className="item-label">เติมเงิน</span>
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

      {/* Promo Banner */}
      <div className="ad-card" onClick={() => handleOpenDialog('shop')}>
        <img src="https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=600&auto=format&fit=crop" alt="Promotion" />
        <span className="ad-tag">HOT ID SALE</span>
        <div className="ad-caption">🔥 ไอดี Valorant / ROV / Steam สกินแรร์ พร้อมส่ง</div>
      </div>

      {/* Dock Toolbar */}
      <div className="dock">
        <div className="dock-grp">
          <button className={`dock-action ${isMuted ? 'muted' : ''}`} onClick={() => { setIsMuted(!isMuted); showToast(isMuted ? '🔊 เปิดเสียงแล้ว' : '🔇 ปิดเสียงแล้ว'); }}>
            {isMuted ? (
              <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z" /></svg>
            ) : (
              <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02z" /></svg>
            )}
            <span>{isMuted ? 'ปิดเสียง' : 'เสียง'}</span>
          </button>
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
              <span style={{ fontSize: '11px', color: '#94a3b8' }}>เวลาที่เหลือจะถูกบันทึกเก็บไว้ในบัญชีสมาชิก</span>
            </p>
            <div style={{ display: 'flex', justifyContent: 'center', gap: '8px' }}>
              <button className="btn-buy" style={{ background: 'rgba(255,255,255,0.1)' }} onClick={() => setShowLogoutConfirm(false)}>ยกเลิก</button>
              <button className="btn-buy" style={{ background: 'linear-gradient(135deg, #f97316, #ef4444)' }} onClick={handleConfirmLogout}>ยืนยัน ออกจากระบบ</button>
            </div>
          </div>
        </div>
      )}

      {/* Hidden Admin Settings Modal (Ctrl+Shift+S or right-click brand) */}
      {showSettings && (
        <div className="modal-overlay">
          <div className="modal-head">
            <div className="modal-title" style={{ color: 'var(--accent-cyan)' }}>⚙️ ตั้งค่าระบบ</div>
            <button className="win-btn close" onClick={() => setShowSettings(false)}>✕</button>
          </div>
          <div className="modal-body" style={{ justifyContent: 'flex-start', overflowY: 'auto' }}>
            <div className="settings-field">
              <label>ชื่อร้าน / แบรนด์</label>
              <input type="text" placeholder="0JAYSHOP" value={formBrandName} onChange={(e) => setFormBrandName(e.target.value)} />
            </div>
            <div className="settings-field">
              <label>ป้ายข้อความ (Badge)</label>
              <input type="text" placeholder="VIP" value={formBrandBadge} onChange={(e) => setFormBrandBadge(e.target.value)} />
            </div>
            <div className="settings-field">
              <label>URL โลโก้ (เว้นว่าง = ไอคอนเริ่มต้น)</label>
              <input type="text" placeholder="https://.../logo.png" value={formBrandLogo} onChange={(e) => setFormBrandLogo(e.target.value)} />
            </div>
            <div className="settings-field">
              <label>รหัสเครื่อง (Station ID)</label>
              <input type="text" placeholder="PC-12" value={formMachineId} onChange={(e) => setFormMachineId(e.target.value)} />
            </div>
            <div className="settings-field">
              <label>URL เซิร์ฟเวอร์ API</label>
              <input type="text" placeholder="http://127.0.0.1:8000/api" value={formApiUrl} onChange={(e) => setFormApiUrl(e.target.value)} />
            </div>
            <div style={{ display: 'flex', gap: '8px', marginTop: '6px' }}>
              <button className="btn-buy" style={{ background: 'rgba(255,255,255,0.1)', flex: 1 }} onClick={() => setShowSettings(false)}>ยกเลิก</button>
              <button className="btn-buy" style={{ flex: 1 }} onClick={handleSaveSettings}>บันทึก</button>
            </div>
          </div>
        </div>
      )}

      {/* Toast */}
      <div className={`toast-box ${toastVisible ? 'visible' : ''}`}>{toastMsg}</div>
    </div>
  );
}
