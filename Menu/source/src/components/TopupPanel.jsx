'use client';

// Top-up box used by the HUD dialog (while renting) and by the lock screen (after login, with the login pass).
// auto = exact-amount PromptPay QR; the shop system credits the account by itself when the money really arrives
// slip = shop has no auto QR: phone link to attach a slip / TrueMoney gift · web = lock screen without auto QR: phone opens the shop wallet page
// Nothing here ever adds time or money by itself: the balance only changes when the shop web says so.

import { useEffect, useRef, useState } from 'react';

export const gcApi = (method, p, body) =>
  typeof window !== 'undefined' && window.electronAPI?.agent
    ? window.electronAPI.agent.api(method, p, body)
    : Promise.resolve({ ok: false, status: 0, data: { error: 'offline' } });

export function baht(satang) {
  const v = (Number(satang) || 0) / 100;
  return '฿' + v.toLocaleString('th-TH', { minimumFractionDigits: v % 1 ? 2 : 0, maximumFractionDigits: 2 });
}

export const UI = {
  card: { background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.10)', borderRadius: 16, padding: 18, display: 'flex', flexDirection: 'column', gap: 12 },
  h: { fontSize: 17, fontWeight: 800, color: '#f8fafc' },
  muted: { color: '#94a3b8', fontSize: 13, lineHeight: 1.5 },
  err: { color: '#fca5a5', fontSize: 13, lineHeight: 1.45 },
  ok: { color: '#6ee7b7', fontSize: 14, fontWeight: 700, lineHeight: 1.45 },
  input: { width: '100%', padding: '11px 13px', borderRadius: 11, border: '1px solid rgba(255,255,255,0.14)', background: 'rgba(255,255,255,0.06)', color: '#f8fafc', fontFamily: 'inherit', fontSize: 15, outline: 'none', userSelect: 'text', WebkitUserSelect: 'text' },
  btn: (disabled) => ({ padding: '11px 16px', borderRadius: 11, border: 'none', cursor: disabled ? 'default' : 'pointer', fontFamily: 'inherit', fontWeight: 700, fontSize: 15, color: '#0a0d1f', background: disabled ? '#475569' : 'linear-gradient(135deg,#00f0ff,#2563eb)' }),
  ghost: { padding: '9px 14px', borderRadius: 11, border: '1px solid rgba(255,255,255,0.16)', background: 'transparent', color: '#cbd5e1', cursor: 'pointer', fontFamily: 'inherit', fontSize: 14 },
  chip: (on) => ({ padding: '10px 14px', borderRadius: 11, cursor: 'pointer', fontFamily: 'inherit', fontWeight: 700, fontSize: 15, border: `1px solid ${on ? '#00f0ff' : 'rgba(255,255,255,0.14)'}`, background: on ? 'rgba(0,240,255,0.12)' : 'rgba(255,255,255,0.04)', color: '#f8fafc' }),
  qr: { width: 210, height: 210, borderRadius: 14, background: '#fff', padding: 8 },
};

function mmss(sec) {
  const s = Math.max(0, Math.floor(sec));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

export default function TopupPanel({ cfg, pass, onBalance, title = 'เติมเงิน' }) {
  const [amount, setAmount] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [req, setReq] = useState(null);        // answer of action:create
  const [done, setDone] = useState(null);      // { amount, bonus, balance }
  const [expired, setExpired] = useState(false);
  const [now, setNow] = useState(Date.now());
  const base = useRef(null);                   // balance when a slip/web top-up started (to notice it going up)

  const chips = cfg ? [50, 100, 200, 500].filter((a) => a >= cfg.min && a <= cfg.max) : [];
  const body = (x) => (pass ? { ...x, pass } : x);

  useEffect(() => {
    if (!req || done || expired) return undefined;
    const tick = setInterval(() => setNow(Date.now()), 1000);
    const poll = setInterval(async () => {
      const r = await gcApi('POST', 'topup', body({ action: 'status', id: req.mode === 'auto' ? req.id : 0 }));
      if (!r.ok) return;
      const d = r.data;
      if (req.mode === 'auto') {
        if (d.status === 'success') { setDone({ amount: d.amount, bonus: d.bonus, balance: d.balance }); onBalance && onBalance(d.balance); }
        else if (d.status === 'expired' || d.status === 'gone') setExpired(true);
      } else {
        if (base.current == null) base.current = d.balance;
        else if (d.balance > base.current) { setDone({ amount: d.balance - base.current, bonus: 0, balance: d.balance }); onBalance && onBalance(d.balance); }
      }
    }, req.mode === 'auto' ? 3000 : 5000);
    return () => { clearInterval(tick); clearInterval(poll); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [req, done, expired]);

  async function create(a) {
    if (busy) return;
    const n = Math.trunc(Number(a));
    if (cfg && cfg.auto && (!n || n < cfg.min || n > cfg.max)) { setError(`เติมได้ ${cfg.min}–${cfg.max} บาท`); return; }
    setBusy(true); setError(''); setDone(null); setExpired(false); base.current = null;
    const r = await gcApi('POST', 'topup', body({ action: 'create', amount: n || 0 }));
    setBusy(false);
    if (!r.ok) { setError((r.data && r.data.error) || 'ขอ QR ไม่สำเร็จ ลองใหม่อีกครั้ง'); return; }
    setReq(r.data);
  }

  async function cancel() {
    if (req && req.mode === 'auto') gcApi('POST', 'topup', body({ action: 'cancel', id: req.id }));
    setReq(null); setDone(null); setExpired(false); setError('');
  }

  if (!cfg) return <div style={UI.card}><div style={UI.muted}>กำลังโหลด…</div></div>;

  if (done)
    return (
      <div style={UI.card}>
        <div style={UI.h}>{title}</div>
        <div style={UI.ok}>✓ เติมเงินสำเร็จ {baht(done.amount)}{done.bonus ? ` + โบนัส ${baht(done.bonus)}` : ''}</div>
        <div style={UI.muted}>ยอดเงินตอนนี้ <b style={{ color: '#f8fafc' }}>{baht(done.balance)}</b></div>
        <button style={UI.ghost} onClick={cancel}>เติมอีก</button>
      </div>
    );

  if (req) {
    const left = req.mode === 'auto' ? Math.max(0, (req.expiresAt - now) / 1000) : 0;
    return (
      <div style={UI.card}>
        <div style={UI.h}>{title}</div>
        {req.mode === 'auto' && (
          <>
            <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
              <img src={req.qr} alt="QR พร้อมเพย์" style={UI.qr} />
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                <div style={UI.muted}>สแกนจ่ายด้วยแอปธนาคาร ยอดนี้เท่านั้น</div>
                <div style={{ fontSize: 30, fontWeight: 800, color: '#67e8f9', fontFamily: "'Chakra Petch', monospace" }}>{baht(req.amount)}</div>
                <div style={UI.muted}>มีเศษสตางค์ไว้ให้ระบบรู้ว่าเป็นของคุณ — <b style={{ color: '#f8fafc' }}>อย่าแก้ยอด</b></div>
                {expired ? <div style={UI.err}>หมดเวลาแล้ว — ถ้าโอนไปแล้ว เงินจะเข้าเมื่อพนักงานตรวจ / แนบสลิปที่เว็บ</div> : <div style={UI.muted}>รอเงินเข้า… เหลือ <b style={{ color: '#f8fafc' }}>{mmss(left)}</b></div>}
              </div>
            </div>
            <div style={UI.muted}>เงินเข้าแล้วยอดขึ้นเองภายในไม่กี่วินาที ไม่ต้องกดอะไร</div>
          </>
        )}
        {req.mode === 'slip' && (
          <>
            <div style={{ display: 'flex', gap: 14, alignItems: 'flex-start', flexWrap: 'wrap' }}>
              {req.payQr ? (
                <div style={{ textAlign: 'center' }}>
                  <img src={req.payQr} alt="QR ร้าน" style={{ ...UI.qr, width: 170, height: 170 }} />
                  <div style={UI.muted}>1. สแกนจ่ายเข้าร้าน</div>
                </div>
              ) : null}
              <div style={{ textAlign: 'center' }}>
                <img src={req.qr} alt="QR แนบสลิป" style={{ ...UI.qr, width: 170, height: 170 }} />
                <div style={UI.muted}>{req.payQr ? '2. ' : ''}สแกนเพื่อแนบสลิป{req.truewallet ? ' / ซองทรู' : ''}</div>
              </div>
            </div>
            {req.account && req.account.no ? <div style={UI.muted}>หรือโอนเข้า {req.account.bank} {req.account.no} ({req.account.name})</div> : null}
            <div style={UI.muted}>แนบสลิปผ่านแล้วยอดขึ้นเองที่จอนี้ · ลิงก์ใช้ได้ 30 นาที</div>
          </>
        )}
        {req.mode === 'web' && (
          <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
            <img src={req.qr} alt="QR เว็บร้าน" style={UI.qr} />
            <div style={UI.muted}>สแกนด้วยมือถือ → ล็อกอินเว็บร้าน → เติมเงิน · ยอดขึ้นที่จอนี้เองเมื่อเติมสำเร็จ หรือเติมเงินสดที่เคาน์เตอร์</div>
          </div>
        )}
        {error && <div style={UI.err}>{error}</div>}
        <button style={UI.ghost} onClick={cancel}>{req.mode === 'auto' && !expired ? 'ยกเลิก' : 'กลับ'}</button>
      </div>
    );
  }

  return (
    <div style={UI.card}>
      <div style={UI.h}>{title}</div>
      {cfg.auto ? (
        <>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {chips.map((a) => (
              <button key={a} style={UI.chip(false)} disabled={busy} onClick={() => create(a)}>{a} บาท</button>
            ))}
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <input style={{ ...UI.input, flex: 1 }} inputMode="numeric" placeholder={`จำนวนอื่น (${cfg.min}–${cfg.max} บาท)`} value={amount} onChange={(e) => setAmount(e.target.value.replace(/[^0-9]/g, '').slice(0, 6))} onKeyDown={(e) => { if (e.key === 'Enter') create(amount); }} />
            <button style={UI.btn(busy || !amount)} disabled={busy || !amount} onClick={() => create(amount)}>{busy ? '…' : 'สร้าง QR'}</button>
          </div>
          <div style={UI.muted}>สแกนจ่ายด้วยแอปธนาคาร เงินเข้าแล้วเครดิตขึ้นเองอัตโนมัติ (ได้โบนัสเติมเหมือนเติมที่เว็บ) · จ่ายเงินสดได้ที่เคาน์เตอร์</div>
        </>
      ) : (
        <>
          <div style={UI.muted}>{pass ? 'เติมผ่านมือถือ (สแกน QR ไปหน้าเติมเงินของเว็บร้าน)' : 'โอนเข้าบัญชีร้าน แล้วแนบสลิปผ่านมือถือ'} หรือจ่ายเงินสดที่เคาน์เตอร์</div>
          <button style={UI.btn(busy)} disabled={busy} onClick={() => create(0)}>{busy ? 'กำลังเปิด…' : 'เปิด QR เติมเงิน'}</button>
        </>
      )}
      {error && <div style={UI.err}>{error}</div>}
    </div>
  );
}
