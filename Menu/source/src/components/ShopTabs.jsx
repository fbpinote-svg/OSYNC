'use client';

// Dialog tabs wired to the shop web (phase 2): top-up & extend time, ID shop, code inventory.
// Only for the session playing on this PC (the web checks the token belongs to the current rental):
// a member (credit) or, since 12 Nov, a coupon player (extend time from the coupon balance).
// Chat / account = phase 3 (12 Nov): chat uses the web support tickets, account is read-only. Not connected to the shop system (old agent) = notice, never made-up data.

import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import TopupPanel, { baht, gcApi, UI } from './TopupPanel';
import { totpCode, totpRemaining, totpSecretFromLine, totpSecretFromText, visibleLines } from '../lib/totp';

// shop web clock minus this PC's clock (agent state.json) — 2-Step codes follow the web clock, so a PC with a wrong clock still gets the right code
const OffsetCtx = createContext(0);

const S = {
  wrap: { flex: 1, overflowY: 'auto', padding: 22, display: 'flex', flexDirection: 'column', gap: 16, color: '#f8fafc' },
  grid2: { display: 'grid', gridTemplateColumns: 'minmax(0,1fr) minmax(0,1fr)', gap: 16, alignItems: 'start' },
  opt: (on) => ({ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, padding: '11px 13px', borderRadius: 12, cursor: 'pointer', border: `1px solid ${on ? '#00f0ff' : 'rgba(255,255,255,0.12)'}`, background: on ? 'rgba(0,240,255,0.10)' : 'rgba(255,255,255,0.04)' }),
  products: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(210px, 1fr))', gap: 14 },
  pcard: { background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.10)', borderRadius: 14, overflow: 'hidden', display: 'flex', flexDirection: 'column' },
  modalBack: { position: 'fixed', inset: 0, background: 'rgba(2,6,23,0.72)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 50 },
  modal: { width: 520, maxWidth: '92vw', maxHeight: '86vh', overflowY: 'auto', background: '#0c121e', border: '1px solid rgba(255,255,255,0.14)', borderRadius: 18, padding: 22, display: 'flex', flexDirection: 'column', gap: 12 },
  line: { display: 'flex', alignItems: 'center', gap: 10, padding: '8px 10px', borderRadius: 10, background: 'rgba(255,255,255,0.05)', fontSize: 14, minHeight: 44, boxSizing: 'border-box' },
  // 16 Nov: same-size layout — fixed label column, fixed-width buttons, equal product cards / inventory rows
  lbl: { width: 132, flexShrink: 0, color: '#94a3b8', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' },
  val: { flex: 1, minWidth: 0, fontFamily: "'Chakra Petch', monospace", wordBreak: 'break-all', userSelect: 'text', WebkitUserSelect: 'text' },
  copyBtn: { width: 96, flexShrink: 0, padding: '6px 0', borderRadius: 9, border: '1px solid rgba(255,255,255,0.16)', background: 'transparent', color: '#cbd5e1', cursor: 'pointer', fontFamily: 'inherit', fontSize: 13, textAlign: 'center' },
  actBtn: (primary, disabled) => ({ width: 170, height: 40, flexShrink: 0, borderRadius: 11, cursor: disabled ? 'default' : 'pointer', fontFamily: 'inherit', fontSize: 14, fontWeight: 700, textAlign: 'center', opacity: disabled ? 0.6 : 1, ...(primary ? { border: 'none', color: '#0a0d1f', background: 'linear-gradient(135deg,#00f0ff,#2563eb)' } : { border: '1px solid rgba(255,255,255,0.18)', background: 'rgba(255,255,255,0.04)', color: '#e2e8f0' }) }),
  totp: (ending) => ({ display: 'flex', flexDirection: 'column', gap: 8, padding: '12px 14px', borderRadius: 12, border: `1px solid ${ending ? 'rgba(245,158,11,0.55)' : 'rgba(34,211,238,0.35)'}`, background: ending ? 'rgba(245,158,11,0.08)' : 'rgba(34,211,238,0.07)' }),
  totpCode: (ending) => ({ border: 'none', background: 'transparent', padding: 0, cursor: 'pointer', fontFamily: "'Chakra Petch', monospace", fontSize: 34, fontWeight: 800, letterSpacing: 6, color: ending ? '#fbbf24' : '#67e8f9', fontVariantNumeric: 'tabular-nums' }),
  bar: { height: 4, borderRadius: 4, background: 'rgba(255,255,255,0.08)', overflow: 'hidden' },
  invRow: { display: 'flex', alignItems: 'center', gap: 14, minHeight: 72 },
  clamp: (n) => ({ display: '-webkit-box', WebkitLineClamp: n, WebkitBoxOrient: 'vertical', overflow: 'hidden' }),
};

function hm(sec) {
  const m = Math.floor(Math.max(0, sec) / 60);
  const h = Math.floor(m / 60);
  return h ? `${h} ชม.${m % 60 ? ` ${m % 60} นาที` : ''}` : `${m % 60} นาที`;
}

/** call the shop web; a 409 "preparing" (token being renewed right after the rental started) is retried once */
async function call(method, p, body) {
  let r = await gcApi(method, p, body);
  if (!r.ok && r.status === 409 && !(r.data && r.data.priceChanged)) {
    await new Promise((res) => setTimeout(res, 2500));
    r = await gcApi(method, p, body);
  }
  return r;
}

const errOf = (r, fallback) => (r && r.data && r.data.error) || fallback;

function notifyHud(text) {
  if (typeof window !== 'undefined' && window.electronAPI?.sendOrder) window.electronAPI.sendOrder({ text });
}

function Notice({ title, text, onBack }) {
  return (
    <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 40 }}>
      <div style={{ maxWidth: 520, textAlign: 'center', display: 'flex', flexDirection: 'column', gap: 12, background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 18, padding: 28 }}>
        <div style={{ fontSize: 20, fontWeight: 800 }}>{title}</div>
        <div style={{ color: '#cbd5e1', lineHeight: 1.6 }}>{text}</div>
        {onBack ? <button className="btn-buy" style={{ alignSelf: 'center', padding: '10px 18px' }} onClick={onBack}>กลับไปเกมเมนู</button> : null}
      </div>
    </div>
  );
}

function copyText(v) {
  try { navigator.clipboard?.writeText(v); } catch { /* clipboard blocked - the value is still on screen */ }
}

/** icon in front of each ID line, by the words in its label (same idea as the shop web's history page) */
function lineEmoji(line) {
  if (/^https?:\/\/\S+$/i.test(line)) return '📧';
  if (totpSecretFromLine(line)) return '🔐';
  const colon = line.search(/[:：]/);
  const k = (colon > 0 ? line.slice(0, colon) : line).toLowerCase();
  if (/รหัส|pass/.test(k)) return '🛡️';
  if (/user|ชื่อผู้ใช้|ชื่อบัญชี|account/.test(k)) return '👤';
  if (/เว็บเมล|webmail|web\s*mail/.test(k)) return '📁';
  if (/รับข้อความ|รับโค้ด|otp|รับ/.test(k)) return '🔑';
  if (/email|e-mail|อีเมล|เมล|mail/.test(k)) return '📧';
  if (/ลิงก์|ลิงค์|url|link|เว็บ/.test(k)) return '🔗';
  return '🔸';
}

/** live 6-digit 2-Step code (changes every 30 s) — worked out on this PC from the ID's 2FA key, on the shop web clock */
function TotpBox({ secret }) {
  const offset = useContext(OffsetCtx);
  const [now, setNow] = useState(() => Date.now() + offset);
  const [copied, setCopied] = useState(false);
  useEffect(() => {
    setNow(Date.now() + offset);
    const id = setInterval(() => setNow(Date.now() + offset), 1000);
    return () => clearInterval(id);
  }, [offset]);
  const code = totpCode(secret, now);
  const left = totpRemaining(now);
  if (!code) return null;
  const ending = left <= 5;
  const copy = () => { copyText(code); setCopied(true); setTimeout(() => setCopied(false), 1500); };
  return (
    <div style={S.totp(ending)}>
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: 10, ...UI.muted }}>
        <span>🔐 ใส่เลข 6 ตัวนี้ในช่อง 2-Step Verification ตอนล็อกอิน</span>
        <span style={{ flexShrink: 0, fontVariantNumeric: 'tabular-nums', color: ending ? '#fbbf24' : '#94a3b8' }}>เลขใหม่ใน {left} วิ</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
        <button style={S.totpCode(ending)} onClick={copy} title="กดเพื่อคัดลอก">{code.slice(0, 3)} {code.slice(3)}</button>
        <button style={S.copyBtn} onClick={copy}>{copied ? 'คัดลอกแล้ว' : 'คัดลอก'}</button>
      </div>
      <div style={S.bar}><span style={{ display: 'block', height: '100%', width: `${(left / 30) * 100}%`, background: ending ? '#f59e0b' : '#22d3ee', transition: 'width 1s linear' }} /></div>
    </div>
  );
}

/** account details bought from the shop: one row per line (icon + fixed label column + value + copy button) ·
 *  lines starting with # are the shop's own data and never shown · a 2FA key line gets the live 2-Step code under it */
function SecretView({ text }) {
  const [copied, setCopied] = useState('');
  const lines = visibleLines(text);
  function copy(v, k) {
    copyText(v);
    setCopied(k);
    setTimeout(() => setCopied(''), 1500);
  }
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      {lines.map((l, i) => {
        const totp = totpSecretFromLine(l);
        const isUrl = /^https?:\/\/\S+$/i.test(l);
        const m = isUrl ? null : /^([^:：]{1,30})[:：]\s*(.+)$/.exec(l);
        const label = totp ? (m && !/^otpauth:/i.test(l) ? m[1].trim() : 'รหัส 2FA') : m ? m[1].trim() : '';
        const value = totp || (m ? m[2] : l);
        return (
          <div key={i} style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            <div style={S.line}>
              <span style={S.lbl} title={label}>{lineEmoji(l)} {label}</span>
              <span style={S.val}>{value}</span>
              <button style={S.copyBtn} onClick={() => copy(value, `l${i}`)}>{copied === `l${i}` ? 'คัดลอกแล้ว' : 'คัดลอก'}</button>
            </div>
            {totp ? <TotpBox secret={totp} /> : null}
          </div>
        );
      })}
      {!lines.length ? <div style={UI.muted}>ไม่มีข้อมูลไอดี — สอบถามพนักงานที่เคาน์เตอร์</div> : null}
      {lines.length ? <button style={{ ...S.actBtn(false, false), alignSelf: 'flex-start' }} onClick={() => copy(lines.join('\n'), 'all')}>{copied === 'all' ? 'คัดลอกแล้ว' : 'คัดลอกทั้งหมด'}</button> : null}
    </div>
  );
}

/** Steam Guard code from the ID's mailbox (the shop web reads the mail) */
function SteamGuard({ orderId }) {
  const [busy, setBusy] = useState(false);
  const [res, setRes] = useState(null);
  async function get() {
    setBusy(true);
    const r = await call('POST', 'steam-guard', { orderId });
    setBusy(false);
    setRes(r.ok && r.data && r.data.ok ? { code: r.data.code } : { error: errOf(r, 'ขอโค้ดไม่สำเร็จ') });
  }
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <button style={{ ...S.actBtn(true, busy), alignSelf: 'flex-start' }} disabled={busy} onClick={get}>{busy ? 'กำลังเปิดเมล…' : res && res.code ? 'ขอโค้ดใหม่' : 'รับโค้ด Steam Guard'}</button>
      {res ? <SteamResult res={res} /> : null}
    </div>
  );
}

function SteamResult({ res }) {
  const [copied, setCopied] = useState(false);
  if (res.error) return <div style={UI.err}>{res.error}</div>;
  const copy = () => { copyText(res.code); setCopied(true); setTimeout(() => setCopied(false), 1500); };
  return (
    <div style={S.totp(false)}>
      <div style={UI.muted}>🛡️ ใส่โค้ดนี้ในช่อง Steam Guard · เปิดหน้าใส่โค้ดค้างไว้ อย่ากดล็อกอินใหม่ (Steam จะส่งโค้ดใหม่ โค้ดเก่าใช้ไม่ได้)</div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
        <button style={S.totpCode(false)} onClick={copy} title="กดเพื่อคัดลอก">{res.code}</button>
        <button style={S.copyBtn} onClick={copy}>{copied ? 'คัดลอกแล้ว' : 'คัดลอก'}</button>
      </div>
    </div>
  );
}

/* ---------------- top-up & extend ---------------- */
// 15 Nov: "กำหนดเอง" row — customer picks 1..maxHours whole hours; prices come from the web (hourPrices[0] = 1 hour),
// same formula the web charges with · an old web without hourPrices = no row (the menu works as before)
const STEP = { width: 34, height: 34, borderRadius: 9, border: '1px solid rgba(255,255,255,0.18)', background: 'rgba(255,255,255,0.06)', color: '#f8fafc', fontSize: 18, fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit', lineHeight: 1 };
function CustomHoursRow({ prices, max, hours, setHours, active, onPick, balance, shortText }) {
  const top = Math.min(max || prices.length, prices.length);
  const n = Math.max(1, Math.min(top, hours));
  const [txt, setTxt] = useState(String(n));
  useEffect(() => { setTxt(String(n)); }, [n]);
  const price = prices[n - 1];
  const short = price > balance;
  const go = (h) => { onPick(); setHours(Math.max(1, Math.min(top, h))); };
  const stop = (e) => e.stopPropagation();
  return (
    <div style={{ ...S.opt(active), opacity: !active && short ? 0.5 : 1 }} onClick={onPick}>
      <div>
        <div style={{ fontWeight: 700 }}>กำหนดเอง (1–{top} ชั่วโมง)</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 6 }} onClick={stop}>
          <button style={{ ...STEP, opacity: n <= 1 ? 0.4 : 1 }} disabled={n <= 1} onClick={() => go(n - 1)}>−</button>
          <input
            style={{ ...UI.input, width: 56, padding: '6px 8px', textAlign: 'center', fontWeight: 700 }}
            inputMode="numeric"
            value={txt}
            onFocus={onPick}
            onChange={(e) => { const v = e.target.value.replace(/[^0-9]/g, '').slice(0, 2); setTxt(v); const h = Number(v); if (h >= 1 && h <= top) go(h); }}
            onBlur={() => setTxt(String(n))}
          />
          <span>ชั่วโมง</span>
          <button style={{ ...STEP, opacity: n >= top ? 0.4 : 1 }} disabled={n >= top} onClick={() => go(n + 1)}>+</button>
        </div>
        <div style={{ ...UI.muted, marginTop: 4 }}>+{hm(n * 3600)}{short ? ` · ${shortText}` : ''}</div>
      </div>
      <div style={{ textAlign: 'right', fontWeight: 800 }}>{baht(price)}</div>
    </div>
  );
}

/** extend options (member credit or coupon balance) — an option that costs more than the balance is greyed out */
function OptionList({ options, balance, pick, setPick, shortText, hourPrices, maxHours, hours, setHours }) {
  const custom = Array.isArray(hourPrices) && hourPrices.length > 0;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8, maxHeight: 330, overflowY: 'auto' }}>
      {(options || []).map((o) => {
        const short = o.price > balance;
        return (
          <div key={o.key} style={{ ...S.opt(pick === o.key), opacity: short ? 0.5 : 1 }} onClick={() => setPick(o.key)}>
            <div>
              <div style={{ fontWeight: 700 }}>{o.label}{o.hot ? ' 🔥' : ''}</div>
              <div style={UI.muted}>{o.minutes ? `+${hm(o.minutes * 60)}` : ''}{short ? ` · ${shortText}` : ''}</div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontWeight: 800 }}>{baht(o.price)}</div>
              {o.compare && o.compare > o.price ? <div style={{ ...UI.muted, textDecoration: 'line-through' }}>{baht(o.compare)}</div> : null}
            </div>
          </div>
        );
      })}
      {custom && (
        <CustomHoursRow prices={hourPrices} max={maxHours} hours={hours} setHours={setHours} active={pick === 'custom'} onPick={() => setPick('custom')} balance={balance} shortText={shortText} />
      )}
      {!(options || []).length && !custom && <div style={UI.muted}>ยังไม่มีตัวเลือกต่อเวลาสำหรับเครื่องนี้ — ติดต่อพนักงาน</div>}
    </div>
  );
}

// 12 Nov: the same tab serves two kinds of session —
//   member  → GET panel (credit, packages, QR top-up)
//   coupon  → POST coupon {action:'panel'} (coupon balance, extend from the coupon; top up the coupon at the counter)
// The web answers 403 for the kind that does not apply, so we try the last known kind first and fall back to the other.
function TopupTab({ onToast }) {
  const [v, setV] = useState(null);
  const [mode, setMode] = useState('');
  const modeRef = useRef('');
  const lock = useRef(false);   // a fast double click must not extend twice
  const [error, setError] = useState('');
  const [pick, setPick] = useState('');
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');

  const load = useCallback(async () => {
    const order = modeRef.current === 'coupon' ? ['coupon', 'member'] : ['member', 'coupon'];
    let shown = null;
    for (const m of order) {
      const r = m === 'member' ? await call('GET', 'panel') : await call('POST', 'coupon', { action: 'panel' });
      if (r.ok) {
        if (modeRef.current !== m) setPick('');
        modeRef.current = m; setMode(m); setV(r.data); setError('');
        return;
      }
      if (r.status === 403) { shown = r; continue; }   // not this kind of session → try the other kind
      shown = shown || r;                               // preparing / offline / old web → stop here
      break;
    }
    setError(errOf(shown, 'โหลดข้อมูลไม่สำเร็จ'));
  }, []);
  useEffect(() => { load(); const t = setInterval(load, 15000); return () => clearInterval(t); }, [load]);

  // 15 Nov: pick 'custom' = the "กำหนดเอง" row (hours:N, price from v.hourPrices)
  const [hours, setHours] = useState(4);
  const hp = v && Array.isArray(v.hourPrices) && v.hourPrices.length ? v.hourPrices : null;
  const customH = hp ? Math.max(1, Math.min(Math.min(v.maxHours || hp.length, hp.length), hours)) : 0;
  const sel = !v ? null
    : pick === 'custom'
      ? (hp && hp[customH - 1] != null ? { key: `hours:${customH}`, label: `${customH} ชั่วโมง`, minutes: customH * 60, price: hp[customH - 1] } : null)
      : (v.options || []).find((o) => o.key === pick);
  const optProps = { hourPrices: hp, maxHours: v ? v.maxHours : 0, hours: customH || hours, setHours };

  // 15 Nov: coupon mode — merge another coupon into the one being played (web: coupon {action:'panelMerge'})
  const [mergeCode, setMergeCode] = useState('');
  const [merging, setMerging] = useState(false);
  const [mergeMsg, setMergeMsg] = useState('');
  const [mergeErr, setMergeErr] = useState('');
  async function mergeCoupon(e) {
    e?.preventDefault?.();
    const add = mergeCode.replace(/[^0-9A-Z]/g, '');
    if (merging || add.length !== 8) return;
    setMerging(true); setMergeErr(''); setMergeMsg('');
    const r = await call('POST', 'coupon', { action: 'panelMerge', add });
    setMerging(false);
    if (r.ok && r.data && r.data.ok) {
      const t = r.data.message || 'รวมคูปองแล้ว';
      setMergeCode(''); setMergeMsg(t); onToast && onToast(`✓ ${t}`); notifyHud(t);
      setV(r.data);
      return;
    }
    setMergeErr(errOf(r, 'รวมคูปองไม่สำเร็จ'));
  }

  async function extend() {
    if (!sel || lock.current) return;
    lock.current = true;
    setBusy(true); setError(''); setMsg('');
    const r = mode === 'coupon'
      ? await call('POST', 'coupon', { action: 'extend', key: sel.key, expectedPrice: sel.price })
      : await call('POST', 'extend', { key: sel.key, expectedPrice: sel.price });
    lock.current = false;
    setBusy(false);
    if (r.ok) {
      const t = (r.data && r.data.message) || 'ต่อเวลาเรียบร้อย';
      setMsg(t); setPick(''); onToast && onToast(`✓ ${t}`); notifyHud(t);
      load();
      return;
    }
    setError(errOf(r, 'ต่อเวลาไม่สำเร็จ'));
    if (r.data && r.data.priceChanged) load();
  }

  if (!v) return error ? <Notice title="ใช้เมนูนี้ไม่ได้ตอนนี้" text={error} /> : <div style={S.wrap}><div style={UI.muted}>กำลังโหลด…</div></div>;
  if (mode === 'coupon') {
    const cant = !sel || busy || sel.price > v.balance;
    const exp = v.expiresAt ? new Date(v.expiresAt).toLocaleDateString('th-TH', { day: 'numeric', month: 'short', year: '2-digit' }) : '';
    return (
      <div style={S.wrap}>
        <div style={{ display: 'flex', gap: 22, alignItems: 'baseline', flexWrap: 'wrap' }}>
          <div style={{ fontSize: 15 }}>ยอดในคูปอง {v.code} <b style={{ fontSize: 24, color: '#67e8f9' }}>{baht(v.balance)}</b></div>
          <div style={UI.muted}>
            เหลือเวลา <b style={{ color: '#f8fafc' }}>{hm(v.remainingSec)}</b>{exp ? ` · คูปองใช้ได้ถึง ${exp}` : ''}
          </div>
        </div>
        <div style={S.grid2}>
          <div style={UI.card}>
            <div style={UI.h}>ต่อเวลา (หักจากคูปอง)</div>
            <OptionList options={v.options} balance={v.balance} pick={pick} setPick={setPick} shortText="ยอดในคูปองไม่พอ" {...optProps} />
            {msg && <div style={UI.ok}>✓ {msg}</div>}
            {error && <div style={UI.err}>{error}</div>}
            <button style={UI.btn(cant)} disabled={cant} onClick={extend}>
              {busy ? 'กำลังต่อเวลา…' : sel ? `ยืนยัน ${sel.label} · หักจากคูปอง ${baht(sel.price)}` : 'เลือกแพ็กเกจ'}
            </button>
            <div style={UI.muted}>เวลาต่อจากเวลาที่เหลือ เล่นต่อได้เลย ไม่ต้องรอเครื่องล็อก</div>
          </div>
          <div style={UI.card}>
            <div style={UI.h}>ยอดในคูปองไม่พอ?</div>
            {/* 15 Nov: merge another coupon into the one being played (whole balance moves · the other coupon can't be used again) */}
            <form onSubmit={mergeCoupon} style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              <div style={{ color: '#cbd5e1', lineHeight: 1.6 }}>มีคูปองอีกใบ? พิมพ์รหัสเพื่อรวมยอดเข้าใบที่กำลังเล่น แล้วกดต่อเวลาทางซ้ายได้เลย</div>
              <div style={{ display: 'flex', gap: 8 }}>
                <input
                  style={{ ...UI.input, fontFamily: "'Chakra Petch', monospace", letterSpacing: 2 }}
                  value={mergeCode}
                  onChange={(e) => { const c = e.target.value.toUpperCase().replace(/[^0-9A-Z]/g, '').slice(0, 8); setMergeCode(c.length > 4 ? `${c.slice(0, 4)}-${c.slice(4)}` : c); }}
                  placeholder="เช่น AFQW-1FA2"
                />
                <button type="submit" style={{ ...UI.btn(merging || mergeCode.replace(/[^0-9A-Z]/g, '').length !== 8), whiteSpace: 'nowrap' }} disabled={merging || mergeCode.replace(/[^0-9A-Z]/g, '').length !== 8}>
                  {merging ? 'กำลังรวม…' : 'รวมคูปอง'}
                </button>
              </div>
              {mergeMsg && <div style={UI.ok}>✓ {mergeMsg}</div>}
              {mergeErr && <div style={UI.err}>{mergeErr}</div>}
            </form>
            <div style={{ color: '#cbd5e1', lineHeight: 1.7 }}>
              หรือเติมเงินเข้าคูปองได้ที่เคาน์เตอร์ (จ่ายเงินสด) แล้วกลับมากดต่อเวลาที่นี่ หรือให้พนักงานเพิ่มเวลาให้ที่เคาน์เตอร์ · คูปองที่หมดอายุแล้วรวมได้ที่เคาน์เตอร์
            </div>
            {/* 14 พ.ย.: บอกกติกาคืนเข้าคูปองให้ครบ (เวลาที่เล่นไปคิดราคารายชั่วโมง · เงินสดที่จ่ายเพิ่มไม่คืนเข้าคูปอง) */}
            <div style={UI.muted}>เลิกเล่นก่อนหมดเวลา (ปุ่ม “ออกจากระบบ”) ได้เงินคืนเข้าคูปอง = ยอดที่จ่ายด้วยคูปอง หักค่าเวลาที่เล่นไป (คิดราคารายชั่วโมง ไม่ใช่ราคาแพ็กเกจ) ใช้ครั้งหน้าได้ · ส่วนที่พนักงานเพิ่มเวลาให้แบบจ่ายเงินสด ไม่คืนเข้าคูปอง</div>
          </div>
        </div>
      </div>
    );
  }
  return (
    <div style={S.wrap}>
      <div style={{ display: 'flex', gap: 22, alignItems: 'baseline', flexWrap: 'wrap' }}>
        <div style={{ fontSize: 15 }}>ยอดเงิน <b style={{ fontSize: 24, color: '#67e8f9' }}>{baht(v.balance)}</b></div>
        <div style={UI.muted}>
          {v.mode === 'hourly' ? <>เหลือเวลา <b style={{ color: '#f8fafc' }}>{hm(v.remainingSec)}</b></> : <>หักตามเวลาที่เล่น {baht(v.ratePerHour)}/ชม. · เล่นได้อีกประมาณ <b style={{ color: '#f8fafc' }}>{hm(v.remainingSec)}</b></>}
          {v.booting ? ' · เครื่องกำลังเตรียม' : ''}{v.frozen ? ' · เครื่องค้าง (พักเวลาให้แล้ว)' : ''}
        </div>
      </div>
      <div style={S.grid2}>
        <div style={UI.card}>
          <div style={UI.h}>{v.mode === 'hourly' ? 'ต่อเวลา' : 'ซื้อเป็นชั่วโมง (คุ้มกว่า)'}</div>
          <OptionList options={v.options} balance={v.balance} pick={pick} setPick={setPick} shortText="ยอดเงินไม่พอ" {...optProps} />
          {msg && <div style={UI.ok}>✓ {msg}</div>}
          {error && <div style={UI.err}>{error}</div>}
          <button style={UI.btn(!sel || busy || (sel && sel.price > v.balance))} disabled={!sel || busy || (sel && sel.price > v.balance)} onClick={extend}>
            {busy ? 'กำลังต่อเวลา…' : sel ? `ยืนยัน ${sel.label} · ${baht(sel.price)}` : 'เลือกแพ็กเกจ'}
          </button>
          <div style={UI.muted}>หักจากยอดเงินในบัญชี · ยอดไม่พอเติมด้านขวา หรือจ่ายสดที่เคาน์เตอร์</div>
        </div>
        <TopupPanel cfg={v.topupCfg} onBalance={() => load()} />
      </div>
    </div>
  );
}

/* ---------------- ID shop ---------------- */
function ShopTab({ onToast, onTab }) {
  const [d, setD] = useState(null);
  const [error, setError] = useState('');
  const [confirm, setConfirm] = useState(null);   // product
  const [busy, setBusy] = useState(false);
  const [bought, setBought] = useState(null);     // { productName, secret, orderId, steam }

  const load = useCallback(async () => {
    const r = await call('GET', 'shop');
    if (r.ok) { setD(r.data); setError(''); } else setError(errOf(r, 'โหลดร้านค้าไม่สำเร็จ'));
  }, []);
  useEffect(() => { load(); }, [load]);

  async function buy() {
    if (!confirm || busy) return;
    setBusy(true); setError('');
    const r = await call('POST', 'buy', { productId: confirm.id, expectedPrice: confirm.price });
    setBusy(false);
    if (r.ok) {
      setBought(r.data); setConfirm(null);
      onToast && onToast(`✓ ซื้อ ${r.data.productName} สำเร็จ`); notifyHud(`ซื้อ ${r.data.productName} สำเร็จ ดูได้ที่คลังรหัส`);
      load();
      return;
    }
    setError(errOf(r, 'ซื้อไม่สำเร็จ'));
    if (r.data && r.data.priceChanged) { setConfirm(null); load(); }
  }

  if (!d) return error ? <Notice title="ใช้เมนูนี้ไม่ได้ตอนนี้" text={error} /> : <div style={S.wrap}><div style={UI.muted}>กำลังโหลด…</div></div>;
  if (!d.enabled) return <Notice title="ร้านค้าปิดชั่วคราว" text="ร้านไอดีปิดอยู่ตอนนี้ — สอบถามพนักงานที่เคาน์เตอร์" />;
  return (
    <div style={S.wrap}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 12, flexWrap: 'wrap' }}>
        <div style={UI.h}>ร้านไอดีเกม</div>
        <div style={{ fontSize: 15 }}>ยอดเงิน <b style={{ color: '#67e8f9' }}>{baht(d.balance)}</b> <button style={{ ...UI.ghost, marginLeft: 8, padding: '5px 10px' }} onClick={() => onTab('topup')}>เติมเงิน</button></div>
      </div>
      {error && <div style={UI.err}>{error}</div>}
      <div style={S.products}>
        {d.products.map((p) => {
          const out = p.stock <= 0;
          const short = p.price > d.balance;
          return (
            <div key={p.id} style={{ ...S.pcard, opacity: out ? 0.55 : 1 }}>
              {/* same picture height on every card (no picture = gradient of the same size) */}
              {p.image ? <img src={p.image} alt="" style={{ width: '100%', height: 120, objectFit: 'cover', background: '#111827', display: 'block' }} /> : <div style={{ height: 120, background: 'linear-gradient(135deg,#1e293b,#312e81)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 34 }}>🎮</div>}
              <div style={{ padding: 12, display: 'flex', flexDirection: 'column', gap: 6, flex: 1 }}>
                <div style={{ fontWeight: 800, lineHeight: 1.35, minHeight: '2.7em', ...S.clamp(2) }} title={p.name}>{p.name}</div>
                <div style={{ ...UI.muted, minHeight: '4.5em', ...S.clamp(3) }}>{p.description || ' '}</div>
                <div style={{ marginTop: 'auto', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <b style={{ fontSize: 18 }}>{baht(p.price)}</b>
                  <span style={UI.muted}>{out ? 'หมด' : `เหลือ ${p.stock}`}</span>
                </div>
                <button style={{ ...UI.btn(out || short), height: 42 }} disabled={out || short} onClick={() => setConfirm(p)}>{out ? 'สินค้าหมด' : short ? 'ยอดเงินไม่พอ' : 'ซื้อ'}</button>
              </div>
            </div>
          );
        })}
        {!d.products.length && <div style={UI.muted}>ยังไม่มีสินค้า</div>}
      </div>

      {confirm && (
        <div style={S.modalBack} onClick={() => !busy && setConfirm(null)}>
          <div style={S.modal} onClick={(e) => e.stopPropagation()}>
            <div style={UI.h}>ยืนยันการซื้อ</div>
            <div>{confirm.name} · <b>{baht(confirm.price)}</b></div>
            <div style={UI.muted}>หักจากยอดเงิน {baht(d.balance)} → เหลือ <b style={{ color: '#f8fafc' }}>{baht(d.balance - confirm.price)}</b> · ได้ไอดีทันทีหลังกดซื้อ</div>
            {error && <div style={UI.err}>{error}</div>}
            <div style={{ display: 'flex', gap: 10 }}>
              <button style={{ ...UI.btn(busy), flex: 1 }} disabled={busy} onClick={buy}>{busy ? 'กำลังซื้อ…' : 'ซื้อเลย'}</button>
              <button style={UI.ghost} disabled={busy} onClick={() => setConfirm(null)}>ยกเลิก</button>
            </div>
          </div>
        </div>
      )}

      {bought && (
        <div style={S.modalBack}>
          <div style={S.modal}>
            <div style={UI.ok}>✓ ซื้อ {bought.productName} สำเร็จ</div>
            <div style={UI.muted}>ข้อมูลไอดีของคุณ (ดูซ้ำได้ที่แท็บคลังรหัส และที่เว็บร้าน → ประวัติ)</div>
            <SecretView text={bought.secret} />
            {bought.steam ? <SteamGuard orderId={bought.orderId} /> : null}
            <button style={UI.btn(false)} onClick={() => setBought(null)}>ปิด</button>
          </div>
        </div>
      )}
    </div>
  );
}

/* ---------------- code inventory ---------------- */
// 16 Nov: every ID row is the same size with two same-size buttons — "ดูข้อมูลไอดี" (popup with all lines) and
// "รับรหัส 2-Step" right on the row: Rockstar-style IDs = live 6-digit code from the 2FA key · Steam IDs = Steam Guard code from the mail
function OrderRow({ o, getSecret, onView }) {
  const [st, setSt] = useState(null);   // null | { busy } | { totp } | { code } | { none } | { error }
  const shown = !!(st && (st.totp || st.code || st.none || st.error));
  async function twoStep() {
    if (st && st.busy) return;
    if (st && st.totp) { setSt(null); return; }   // second press hides the code
    setSt({ busy: true });
    if (o.steam) {
      const r = await call('POST', 'steam-guard', { orderId: o.id });
      setSt(r.ok && r.data && r.data.ok ? { code: r.data.code } : { error: errOf(r, 'ขอโค้ดไม่สำเร็จ') });
      return;
    }
    try {
      const t = totpSecretFromText(await getSecret(o.id));
      setSt(t ? { totp: t } : { none: true });
    } catch (e) {
      setSt({ error: e.message });
    }
  }
  const busy = !!(st && st.busy);
  const label = busy ? (o.steam ? 'กำลังเปิดเมล…' : 'กำลังโหลด…') : st && st.totp ? 'ซ่อนรหัส 2-Step' : o.steam ? (st && st.code ? 'ขอโค้ดใหม่' : 'รับโค้ด Steam Guard') : 'รับรหัส 2-Step';
  return (
    <div style={UI.card}>
      <div style={S.invRow}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontWeight: 800, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }} title={o.name}>{o.name}</div>
          <div style={{ ...UI.muted, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>#{o.id} · {new Date(o.createdAt).toLocaleString('th-TH', { dateStyle: 'medium', timeStyle: 'short' })} · {baht(o.price)}</div>
        </div>
        <button style={S.actBtn(false, false)} onClick={() => onView(o)}>ดูข้อมูลไอดี</button>
        <button style={S.actBtn(true, busy)} disabled={busy} onClick={twoStep}>{label}</button>
      </div>
      {shown && st.totp ? <TotpBox secret={st.totp} /> : null}
      {shown && (st.code || st.error) && o.steam ? <SteamResult res={st} /> : null}
      {shown && st.error && !o.steam ? <div style={UI.err}>{st.error}</div> : null}
      {shown && st.none ? <div style={UI.muted}>ไอดีนี้ไม่มีรหัส 2-Step — ล็อกอินด้วยข้อมูลใน “ดูข้อมูลไอดี” ได้เลย · ถ้าเกมขอโค้ด ทักแชทร้าน</div> : null}
    </div>
  );
}

function InventoryTab() {
  const [list, setList] = useState(null);
  const [error, setError] = useState('');
  const secrets = useRef({});              // orderId -> ID details (asked from the web once per order)
  const [view, setView] = useState(null);  // { o, secret?, error? } = details popup

  useEffect(() => {
    call('POST', 'orders', { action: 'list' }).then((r) => {
      if (r.ok) setList(r.data.orders || []); else setError(errOf(r, 'โหลดคลังรหัสไม่สำเร็จ'));
    });
  }, []);

  const getSecret = useCallback(async (id) => {
    if (secrets.current[id] != null) return secrets.current[id];
    const r = await call('POST', 'orders', { action: 'reveal', orderId: id });
    if (!r.ok) throw new Error(errOf(r, 'เปิดดูไม่สำเร็จ'));
    secrets.current[id] = String(r.data.secret || '');
    return secrets.current[id];
  }, []);

  async function openView(o) {
    setView({ o });
    try { setView({ o, secret: await getSecret(o.id) }); } catch (e) { setView({ o, error: e.message }); }
  }

  if (!list) return error ? <Notice title="ใช้เมนูนี้ไม่ได้ตอนนี้" text={error} /> : <div style={S.wrap}><div style={UI.muted}>กำลังโหลด…</div></div>;
  return (
    <div style={S.wrap}>
      <div style={UI.h}>คลังรหัสที่ซื้อ</div>
      <div style={UI.muted}>ไอดีที่ซื้อด้วยบัญชีนี้ (ทั้งที่เว็บและที่เครื่องในร้าน) · เกมขอโค้ดยืนยันตอนล็อกอิน กด “รับรหัส 2-Step” ได้เลย — อย่าลืมออกจากเกมก่อนเลิกเล่น</div>
      {error && <div style={UI.err}>{error}</div>}
      {list.map((o) => <OrderRow key={o.id} o={o} getSecret={getSecret} onView={openView} />)}
      {!list.length && <div style={UI.muted}>ยังไม่มีไอดีที่ซื้อ — ดูสินค้าได้ที่แท็บซื้อไอดีเกม</div>}

      {view && (
        <div style={S.modalBack} onClick={() => setView(null)}>
          <div style={S.modal} onClick={(e) => e.stopPropagation()}>
            <div style={UI.h}>{view.o.name}</div>
            <div style={UI.muted}>#{view.o.id} · {new Date(view.o.createdAt).toLocaleString('th-TH', { dateStyle: 'medium', timeStyle: 'short' })}</div>
            {view.error ? <div style={UI.err}>{view.error}</div> : view.secret == null ? <div style={UI.muted}>กำลังโหลด…</div> : <SecretView text={view.secret} />}
            {view.secret != null && view.o.steam ? <SteamGuard orderId={view.o.id} /> : null}
            <button style={UI.btn(false)} onClick={() => setView(null)}>ปิด</button>
          </div>
        </div>
      )}
    </div>
  );
}

// ── phase 3 (12 Nov): chat with the shop (web support tickets — staff answer at admin → แจ้งปัญหา) ──
const DT = (ms) => new Date(ms).toLocaleString('th-TH', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
const STATUS_TEXT = { open: 'รอทีมงาน', answered: 'ทีมงานตอบแล้ว', closed: 'ปิดแล้ว' };

function ChatTab() {
  const [tickets, setTickets] = useState([]);
  const [thread, setThread] = useState(null);
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');
  const [loaded, setLoaded] = useState(false);
  const load = useCallback(async (ticketId) => {
    const r = await call('POST', 'chat', ticketId ? { action: 'open', ticketId } : { action: 'list' });
    setLoaded(true);
    if (!r.ok) { setErr(errOf(r, 'โหลดแชทไม่สำเร็จ')); return; }
    setErr('');
    if (r.data.tickets) setTickets(r.data.tickets);
    setThread(r.data.thread || null);
  }, []);
  useEffect(() => { load(); }, [load]);
  // new replies from staff show up by themselves
  useEffect(() => {
    const t = setInterval(() => load(thread ? thread.id : undefined), 15000);
    return () => clearInterval(t);
  }, [load, thread]);
  async function send(e) {
    e?.preventDefault?.();
    if (busy || !text.trim()) return;
    setBusy(true);
    const r = await call('POST', 'chat', { action: 'send', ticketId: thread && thread.status !== 'closed' ? thread.id : undefined, body: text.trim() });
    setBusy(false);
    if (!r.ok) { setErr(errOf(r, 'ส่งไม่สำเร็จ')); return; }
    setText(''); setErr('');
    setThread(r.data.thread); if (r.data.tickets) setTickets(r.data.tickets);
  }
  return (
    <div style={{ ...S.wrap, flexDirection: 'row', gap: 16 }}>
      <div style={{ ...UI.card, width: 260, flexShrink: 0, alignSelf: 'stretch', overflowY: 'auto' }}>
        <div style={UI.h}>เรื่องของฉัน</div>
        <button className="btn-buy" style={{ padding: '8px 12px' }} onClick={() => { setThread(null); setText(''); }}>+ เริ่มคุยเรื่องใหม่</button>
        {tickets.map((t) => (
          <div key={t.id} style={S.opt(thread && thread.id === t.id)} onClick={() => load(t.id)}>
            <div style={{ minWidth: 0 }}>
              <div style={{ fontWeight: 700, fontSize: 13, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{t.subject}</div>
              <div style={UI.muted}>{STATUS_TEXT[t.status] || t.status} · {DT(t.updatedAt)}</div>
            </div>
            {t.unread ? <span style={{ width: 8, height: 8, borderRadius: 99, background: '#f472b6', flexShrink: 0 }} /> : null}
          </div>
        ))}
        {loaded && !tickets.length && <div style={UI.muted}>ยังไม่เคยคุยกับร้าน</div>}
      </div>
      <div style={{ ...UI.card, flex: 1, minWidth: 0, alignSelf: 'stretch' }}>
        <div style={UI.h}>{thread ? thread.subject : 'แชทกับแอดมินร้าน'}</div>
        <div style={{ flex: 1, minHeight: 200, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 8 }}>
          {thread ? thread.messages.map((m) => (
            <div key={m.id} style={{ alignSelf: m.from === 'me' ? 'flex-end' : 'flex-start', maxWidth: '78%', background: m.from === 'me' ? 'rgba(0,240,255,0.12)' : 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 12, padding: '8px 11px' }}>
              {m.from !== 'me' ? <div style={{ fontSize: 11, color: '#f9a8d4', fontWeight: 700 }}>{m.author}</div> : null}
              <div style={{ whiteSpace: 'pre-wrap', lineHeight: 1.5 }}>{m.body}</div>
              <div style={{ fontSize: 10, color: '#94a3b8', textAlign: 'right' }}>{DT(m.at)}</div>
            </div>
          )) : <div style={UI.muted}>พิมพ์ข้อความด้านล่างเพื่อเริ่มคุยกับร้าน — ทีมงานตอบกลับที่นี่และในเว็บร้าน (เมนูแจ้งปัญหา)</div>}
        </div>
        {thread && thread.status === 'closed' ? <div style={UI.muted}>เรื่องนี้ปิดแล้ว — ส่งข้อความใหม่จะเปิดเป็นเรื่องใหม่</div> : null}
        {err ? <div style={UI.err}>{err}</div> : null}
        <form onSubmit={send} style={{ display: 'flex', gap: 8 }}>
          <input value={text} onChange={(e) => setText(e.target.value.slice(0, 1000))} placeholder="พิมพ์ข้อความ…" style={{ flex: 1, padding: '11px 13px', borderRadius: 12, border: '1px solid rgba(255,255,255,0.14)', background: 'rgba(255,255,255,0.06)', color: '#f8fafc', fontFamily: 'inherit', fontSize: 14, outline: 'none' }} />
          <button type="submit" className="btn-buy" disabled={busy || !text.trim()} style={{ padding: '0 18px' }}>{busy ? 'กำลังส่ง…' : 'ส่ง'}</button>
        </form>
      </div>
    </div>
  );
}

// ── phase 3 (12 Nov): account summary of the member renting this PC ──
function AccountTab() {
  const [d, setD] = useState(null);
  const [err, setErr] = useState('');
  useEffect(() => {
    call('POST', 'account', {}).then((r) => (r.ok ? setD(r.data) : setErr(errOf(r, 'โหลดข้อมูลบัญชีไม่สำเร็จ'))));
  }, []);
  if (err) return <div style={S.wrap}><div style={UI.err}>{err}</div></div>;
  if (!d) return <div style={S.wrap}><div style={UI.muted}>กำลังโหลด…</div></div>;
  const s = d.stats;
  const tile = (label, value) => (
    <div style={{ ...UI.card, gap: 4 }}>
      <div style={UI.muted}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 800 }}>{value}</div>
    </div>
  );
  return (
    <div style={S.wrap}>
      <div style={{ fontSize: 22, fontWeight: 800 }}>{d.user.name} <span style={{ ...UI.muted, fontSize: 14 }}>@{d.user.username}</span></div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0,1fr))', gap: 12 }}>
        {tile('ยอดเงิน', baht(d.user.balance))}
        {tile('เวลาสะสม', d.user.timeBankSec >= 60 ? hm(d.user.timeBankSec) : '—')}
        {tile('เล่นไปแล้ว', `${s.rentals} ครั้ง`)}
        {tile('เวลาเล่นรวม', hm(s.minutesPlayed * 60))}
      </div>
      <div style={S.grid2}>
        <div style={UI.card}>
          <div style={UI.h}>สรุป</div>
          <div style={UI.muted}>เติมเงินรวม <b style={{ color: '#f8fafc' }}>{baht(s.toppedUp)}</b> · ใช้ไป <b style={{ color: '#f8fafc' }}>{baht(s.spent)}</b></div>
          {s.favoriteMachine ? <div style={UI.muted}>เครื่องที่เล่นบ่อย <b style={{ color: '#f8fafc' }}>{s.favoriteMachine}</b> ({s.favoriteCount} ครั้ง)</div> : null}
          <div style={UI.muted}>สมาชิกตั้งแต่ {new Date(d.user.memberSince).toLocaleDateString('th-TH', { day: 'numeric', month: 'long', year: 'numeric' })}</div>
        </div>
        <div style={UI.card}>
          <div style={UI.h}>เล่นล่าสุด</div>
          {d.recent.map((r) => (
            <div key={r.id} style={{ display: 'flex', justifyContent: 'space-between', gap: 8, fontSize: 13 }}>
              <span>{r.machine} · {DT(r.startedAt)}</span>
              <span style={{ color: '#cbd5e1' }}>{r.charged ? baht(r.charged) : '—'}</span>
            </div>
          ))}
          {!d.recent.length && <div style={UI.muted}>ยังไม่มีประวัติ</div>}
        </div>
      </div>
      <div style={UI.muted}>เปลี่ยนรหัสผ่าน · ยืนยัน 2 ชั้น · ประวัติทั้งหมด ดูได้ที่เว็บร้าน</div>
    </div>
  );
}

export default function ShopTabs({ offsetMs, ...props }) {
  return (
    <OffsetCtx.Provider value={Number(offsetMs) || 0}>
      <ShopTabsInner {...props} />
    </OffsetCtx.Provider>
  );
}

function ShopTabsInner({ tab, linked, site, onToast, onTab }) {
  const host = String(site || '').replace(/^https?:\/\//, '');
  if (!linked)
    return (
      <Notice
        title="ต้องเชื่อมระบบร้าน"
        text="เมนูนี้ใช้ได้เมื่อเครื่องเชื่อมกับระบบร้าน (Cooper Agent รุ่น 1.20 ขึ้นไป) — ตอนนี้เครื่องนี้ใช้ได้เฉพาะเกมเมนู · ติดต่อพนักงานที่เคาน์เตอร์"
        onBack={() => onTab('gamemenu')}
      />
    );
  if (tab === 'topup') return <TopupTab onToast={onToast} />;
  if (tab === 'shop') return <ShopTab onToast={onToast} onTab={onTab} />;
  if (tab === 'inventory') return <InventoryTab />;
  if (tab === 'chat') return <ChatTab />;
  if (tab === 'account') return <AccountTab />;
  return (
    <Notice
      title="ไม่พบเมนูนี้"
      text={<>ใช้ได้ที่เว็บร้าน{host ? <> <b style={{ color: '#f8fafc' }}>{host}</b></> : null} หรือแจ้งพนักงานที่เคาน์เตอร์</>}
      onBack={() => onTab('gamemenu')}
    />
  );
}
