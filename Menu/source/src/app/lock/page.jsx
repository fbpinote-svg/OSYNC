'use client';

// Lock screen (shown full screen by electron/main.js while this PC has no rental and the shop system is connected).
// Members: log in with the shop web account (or scan a QR with a phone that is logged in to the shop web),
// pick a package / saved time, and the PC unlocks by itself as soon as the agent sees the new rental.
// Not enough money → top up right here (exact-amount QR) or pay cash at the counter.
// People without an account: buy a cash coupon at the counter (e.g. AFQW-1FA2), type it, see the balance, pick time
// (same prices as members) → paid from the coupon; leftover paid time goes back into the coupon on early end.
// Old 10-character time tickets typed in the same box still work until they expire.

import { useEffect, useMemo, useRef, useState } from 'react';
import { getBrandConfig, applyUi, getBuildStamp } from '../../lib/config';
import TopupPanel, { baht, gcApi as api } from '../../components/TopupPanel';

// headline: a run of Latin words ("AT9 COM-ONLINE") stays on one line (no break at the hyphen or between them);
// Thai text still wraps normally · very long Latin runs keep only each word together
function keepWords(text) {
  return String(text || '').split(/([A-Za-z0-9][A-Za-z0-9 .&'+:-]*[A-Za-z0-9])/).map((part, i) => {
    if (i % 2 === 0) return part;
    if (part.length <= 24) return <span key={i} style={{ whiteSpace: 'nowrap' }}>{part}</span>;
    return part.split(/(\s+)/).map((w, j) => (/\S/.test(w) ? <span key={`${i}-${j}`} style={{ whiteSpace: 'nowrap' }}>{w}</span> : w));
  });
}

// package / coupon option list: thin scrollbar + "more below" hint (13 Nov: at 1366x768 the 5th package was hidden with no sign of it)
function OptionScroll({ children }) {
  const ref = useRef(null);
  const [more, setMore] = useState(false);
  const check = () => { const el = ref.current; if (el) setMore(el.scrollHeight - el.scrollTop - el.clientHeight > 6); };
  useEffect(check);
  useEffect(() => {
    const el = ref.current;
    if (!el || typeof ResizeObserver === 'undefined') return undefined;
    const ro = new ResizeObserver(check);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
      <div ref={ref} onScroll={check} style={{ display: 'flex', flexDirection: 'column', gap: 8, maxHeight: 300, overflowY: 'auto', paddingRight: 4 }}>{children}</div>
      {more ? (
        <button type="button" onClick={() => ref.current && ref.current.scrollBy({ top: 140, behavior: 'smooth' })} style={{ alignSelf: 'center', border: 0, background: 'transparent', color: '#67e8f9', fontFamily: 'inherit', fontSize: 13, cursor: 'pointer', padding: '2px 8px' }}>
          ⌄ เลื่อนดูแพ็กเกจเพิ่ม
        </button>
      ) : null}
    </div>
  );
}

function hm(sec) {
  const m = Math.floor(Math.max(0, sec) / 60);
  const h = Math.floor(m / 60);
  return h ? `${h} ชม.${m % 60 ? ` ${m % 60} นาที` : ''}` : `${m % 60} นาที`;
}
function mmss(sec) {
  const s = Math.max(0, Math.floor(sec));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

const S = {
  page: { position: 'fixed', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 48, padding: 40, background: 'radial-gradient(1200px 700px at 20% 20%, #1b2a6b55, transparent), radial-gradient(900px 600px at 85% 80%, #6d28d955, transparent), #070a18', color: '#f8fafc' },
  left: { flex: '1 1 0', maxWidth: 560, display: 'flex', flexDirection: 'column', gap: 18 },
  // maxHeight in % (not vh): the lock screen can be zoomed (config.json ui.lockSize) and vh does not follow the zoom
  card: { width: 470, maxWidth: '100%', maxHeight: '100%', overflowY: 'auto', background: 'rgba(12,18,30,0.92)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 20, padding: 24, boxShadow: '0 30px 80px rgba(0,0,0,0.45)', display: 'flex', flexDirection: 'column', gap: 14 },
  tabs: { display: 'flex', gap: 4, background: 'rgba(255,255,255,0.05)', borderRadius: 12, padding: 4 },
  tab: (on) => ({ flex: 1, padding: '9px 6px', borderRadius: 9, border: 'none', cursor: 'pointer', fontFamily: 'inherit', fontWeight: 600, fontSize: 14, color: on ? '#0a0d1f' : '#cbd5e1', background: on ? 'linear-gradient(135deg,#00f0ff,#60a5fa)' : 'transparent' }),
  input: { width: '100%', padding: '12px 14px', borderRadius: 12, border: '1px solid rgba(255,255,255,0.14)', background: 'rgba(255,255,255,0.06)', color: '#f8fafc', fontFamily: 'inherit', fontSize: 15, outline: 'none', userSelect: 'text', WebkitUserSelect: 'text' },
  btn: (disabled) => ({ width: '100%', padding: '13px 14px', borderRadius: 12, border: 'none', cursor: disabled ? 'default' : 'pointer', fontFamily: 'inherit', fontWeight: 700, fontSize: 16, color: '#0a0d1f', background: disabled ? '#475569' : 'linear-gradient(135deg,#00f0ff,#2563eb)' }),
  ghost: { width: '100%', padding: '10px 14px', borderRadius: 12, border: '1px solid rgba(255,255,255,0.14)', background: 'transparent', color: '#cbd5e1', cursor: 'pointer', fontFamily: 'inherit', fontSize: 14 },
  err: { color: '#fca5a5', fontSize: 13, lineHeight: 1.45 },
  ok: { color: '#6ee7b7', fontSize: 15, fontWeight: 700, lineHeight: 1.45 },
  muted: { color: '#94a3b8', fontSize: 13, lineHeight: 1.5 },
  opt: (on, off) => ({ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, padding: '12px 14px', borderRadius: 12, cursor: off ? 'default' : 'pointer', border: `1px solid ${on ? '#00f0ff' : 'rgba(255,255,255,0.12)'}`, background: on ? 'rgba(0,240,255,0.10)' : 'rgba(255,255,255,0.04)', opacity: off ? 0.45 : 1 }),
  qr: { width: 220, height: 220, borderRadius: 14, background: '#fff', padding: 8, alignSelf: 'center' },
};

const PASS_MS = 110000;   // the login pass lasts 2 minutes (the web extends it while a top-up QR is waiting)
const COUPON_MS = 120000; // a checked coupon stays on screen 2 minutes, then clears (so the next person can't spend it)

export default function LockScreen() {
  const brand = useMemo(() => getBrandConfig(), []);
  const [view, setView] = useState(null);       // agent view (machine name, site, ending)
  const [st, setSt] = useState(null);           // /api/gcafe/state (login allowed? top-up config)
  const [now, setNow] = useState(0);   // 0 until mounted: the page is pre-rendered, a clock here would not match (React #418)
  const [build, setBuild] = useState('');   // menu build time (bottom-right corner), read after mount for the same reason
  useEffect(() => { setBuild(getBuildStamp()); }, []);
  const [tab, setTab] = useState('login');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [code, setCode] = useState('');
  const [needCode, setNeedCode] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [login, setLogin] = useState(null);     // { pass, user, options }
  const [pick, setPick] = useState('');
  const [passExp, setPassExp] = useState(0);
  const [topup, setTopup] = useState(false);
  const [qr, setQr] = useState(null);           // { id, qr, url, expiresAt }
  const [qrState, setQrState] = useState('');   // '' | waiting | expired | denied | error
  const [ticket, setTicket] = useState('');
  const [coupon, setCoupon] = useState(null);   // { code (raw), tail, balance, expiresAt, options }
  const [couponPick, setCouponPick] = useState('');
  const [couponExp, setCouponExp] = useState(0);
  const [mergeOpen, setMergeOpen] = useState(false);   // 15 Nov: "merge another coupon into this one" box
  const [mergeCode, setMergeCode] = useState('');
  const [mergeMsg, setMergeMsg] = useState('');
  useEffect(() => { if (!coupon) { setMergeOpen(false); setMergeCode(''); setMergeMsg(''); } }, [coupon]);
  const [started, setStarted] = useState('');
  const qrTab = useRef(false);

  useEffect(() => {
    applyUi('lock');   // font + zoom set by the shop (config.json "ui")
    const a = window.electronAPI?.agent;
    if (a) {
      a.get().then(setView);
      a.onUpdate(setView);
    }
    const loadState = () => api('GET', 'state').then((r) => { if (r.ok) setSt(r.data); });
    loadState();
    const s = setInterval(loadState, 15000);
    setNow(Date.now());
    const c = setInterval(() => setNow(Date.now()), 1000);
    return () => { clearInterval(s); clearInterval(c); };
  }, []);

  // the login pass runs out → back to the form
  useEffect(() => {
    if (login && now > passExp) { setLogin(null); setPick(''); setTopup(false); setError('หมดเวลาเลือกแพ็กเกจ — ล็อกอินใหม่อีกครั้ง'); }
  }, [now, login, passExp]);
  // a checked coupon left on screen → clear it
  useEffect(() => {
    if (coupon && now > couponExp) { setCoupon(null); setCouponPick(''); setTicket(''); setError('หมดเวลา — พิมพ์รหัสคูปองใหม่อีกครั้ง'); }
  }, [now, coupon, couponExp]);

  const shop = (st && st.shop) || (view && view.shop) || brand.name;
  const machine = (st && st.machine && st.machine.name) || (view && view.machineName) || '';
  const site = (st && st.site) || (view && view.site) || '';
  const siteHost = site.replace(/^https?:\/\//, '').replace(/\/.*$/, '');
  const allowed = st ? st.storefront && st.storefront.loginAllowed : true;
  const why = st && st.storefront ? st.storefront.why : '';
  const ticketsOn = !st || !st.storefront || st.storefront.tickets !== false;
  const couponsOn = !!(st && st.storefront && st.storefront.coupons);
  // phase 3 (12 Nov): look set by the shop at admin → หน้าจอเครื่องลูก (older webs send no "screen" → defaults)
  const look = (st && st.screen && st.screen.lock) || {};
  const tabsOn = { member: true, qr: true, coupon: true, signup: true, ...(look.tabs || {}) };
  const codeTabOn = (couponsOn || ticketsOn) && tabsOn.coupon !== false;
  const lines = String(look.lines || '').split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  const clock = new Date(now);

  function gotLogin(data) {
    setLogin(data); setPassExp(Date.now() + PASS_MS); setPassword(''); setCode(''); setNeedCode(false); setTopup(false); setError('');
    const first = (data.options || []).find((o) => o.price <= data.user.balance || o.key === 'bank');
    setPick(first ? first.key : '');
    setTab('login');
  }

  async function doLogin(e) {
    e?.preventDefault?.();
    if (busy) return;
    if (!username.trim() || !password) { setError('ใส่ชื่อผู้ใช้และรหัสผ่าน'); return; }
    setBusy(true); setError('');
    const r = await api('POST', 'login', { username: username.trim(), password, code: needCode ? code.trim() : '' });
    setBusy(false);
    if (r.ok) { gotLogin(r.data); return; }
    const msg = (r.data && r.data.error) || 'เข้าสู่ระบบไม่สำเร็จ';
    if (msg === 'TOTP_REQUIRED') { setNeedCode(true); setError('บัญชีนี้เปิดยืนยัน 2 ชั้น — ใส่รหัส 6 หลักจากแอปยืนยันตัวตน'); return; }
    setError(msg === 'wrong_network' ? 'เครื่องนี้ยังเชื่อมต่อร้านไม่ได้ — แจ้งพนักงาน' : msg);
  }

  async function doStart() {
    if (busy || !login || !pick) return;
    setBusy(true); setError('');
    const r = await api('POST', 'start', { pass: login.pass, option: pick });
    setBusy(false);
    if (r.ok) { setLogin(null); setPick(''); setUsername(''); setError(''); setTopup(false); setStarted('เริ่มเล่นแล้ว — เครื่องกำลังปลดล็อก…'); return; }   // the agent unlocks the PC within a few seconds
    setError((r.data && r.data.error) || 'เริ่มเล่นไม่สำเร็จ');
    if (/ล็อกอินใหม่/.test((r.data && r.data.error) || '')) setLogin(null);
  }

  // ---- QR login: the phone (logged in to the shop web) scans, confirms → this screen gets the login pass ----
  async function newQr() {
    setQr(null); setQrState(''); setError('');
    const r = await api('POST', 'qr-login', { action: 'create' });
    if (r.ok) { setQr(r.data); setQrState('waiting'); } else { setQrState('error'); setError((r.data && r.data.error) || 'ขอ QR ไม่สำเร็จ'); }
  }
  useEffect(() => {
    qrTab.current = tab === 'qr';
    if (tab === 'qr' && allowed && !login && !qr) newQr();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab, allowed]);
  useEffect(() => {
    if (tab !== 'qr' || !qr || qrState !== 'waiting') return undefined;
    const t = setInterval(async () => {
      if (Date.now() > qr.expiresAt + 3000) { setQrState('expired'); return; }
      const r = await api('POST', 'qr-login', { action: 'poll', id: qr.id });
      if (!r.ok || !qrTab.current) return;
      const d = r.data;
      if (d.status === 'approved') { setQr(null); setQrState(''); gotLogin(d); }
      else if (d.status === 'expired') setQrState('expired');
      else if (d.status === 'denied') setQrState('denied');
      else if (d.status === 'error') { setQrState('error'); setError(d.error || 'ล็อกอินไม่สำเร็จ'); }
    }, 2000);
    return () => clearInterval(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab, qr, qrState]);

  // ---- coupon (8 characters, cash bought at the counter) or old time ticket (10 characters) — no account ----
  async function submitTicket(e) {
    e?.preventDefault?.();
    if (busy) return;
    const c = ticket.toUpperCase().replace(/[^0-9A-Z]/g, '');
    if (c.length === 8 && couponsOn) {
      setBusy(true); setError('');
      const r = await api('POST', 'coupon', { action: 'check', code: c });
      setBusy(false);
      if (!r.ok || !r.data || !r.data.ok) { setError((r.data && r.data.error) || 'ตรวจคูปองไม่สำเร็จ'); return; }
      const d = r.data;
      setCoupon({ code: c, tail: d.code, balance: d.balance, expiresAt: d.expiresAt, options: d.options || [] });
      setCouponExp(Date.now() + COUPON_MS);
      const first = (d.options || []).find((o) => o.price <= d.balance);
      setCouponPick(first ? first.key : '');
      return;
    }
    if (c.length === 10 && ticketsOn) {
      setBusy(true); setError('');
      const r = await api('POST', 'ticket', { code: c });
      setBusy(false);
      if (r.ok) { setTicket(''); setStarted(`ใช้บัตร ${r.data.label || ''} แล้ว — เครื่องกำลังปลดล็อก…`); return; }
      setError((r.data && r.data.error) || 'ใช้บัตรไม่สำเร็จ');
      return;
    }
    setError(couponsOn ? 'รหัสคูปองมี 8 ตัว (ตัวอักษรและตัวเลข เช่น AFQW-1FA2)' : 'รหัสบัตรมี 10 ตัว (ตัวอักษรและตัวเลข เช่น K7Q9M-2XD4P)');
  }
  // 15 Nov: the customer merges another coupon into the checked one (whole balance moves · the other coupon can't be used again)
  //   the web refuses expired / in-use / voided coupons (expired ones go to the counter) · a wrong code counts toward the 5-tries lock
  async function mergeCoupon(e) {
    e?.preventDefault?.();
    if (busy || !coupon) return;
    const add = mergeCode.toUpperCase().replace(/[^0-9A-Z]/g, '');
    if (add.length !== 8) { setError('รหัสคูปองมี 8 ตัว (ตัวอักษรและตัวเลข เช่น AFQW-1FA2)'); return; }
    setBusy(true); setError(''); setMergeMsg('');
    const r = await api('POST', 'coupon', { action: 'merge', code: coupon.code, add });
    setBusy(false);
    if (!r.ok || !r.data || !r.data.ok) { setError((r.data && r.data.error) || 'รวมคูปองไม่สำเร็จ'); return; }
    const d = r.data;
    setCoupon((cur) => (cur ? { ...cur, balance: d.balance, expiresAt: d.expiresAt, options: d.options || cur.options } : cur));
    setCouponExp(Date.now() + COUPON_MS);
    setMergeCode(''); setMergeOpen(false); setMergeMsg(d.message || 'รวมคูปองแล้ว');
    if (!couponPick) { const first = (d.options || []).find((o) => o.price <= d.balance); if (first) setCouponPick(first.key); }
  }
  async function startCoupon() {
    if (busy || !coupon || !couponPick) return;
    const o = coupon.options.find((x) => x.key === couponPick);
    setBusy(true); setError('');
    const r = await api('POST', 'coupon', { action: 'start', code: coupon.code, option: couponPick, expectedPrice: o ? o.price : undefined });
    setBusy(false);
    if (r.ok && r.data && r.data.ok) {
      setCoupon(null); setCouponPick(''); setTicket('');
      setStarted(`เริ่มเล่น ${r.data.label || ''} แล้ว · เหลือในคูปอง ${baht(r.data.balance)} — เครื่องกำลังปลดล็อก…`);
      return;
    }
    const d = r.data || {};
    setError(d.error || 'เริ่มเล่นไม่สำเร็จ');
    if (d.priceChanged) {   // price moved while choosing → reload the options
      const c2 = await api('POST', 'coupon', { action: 'check', code: coupon.code });
      if (c2.ok && c2.data && c2.data.ok) setCoupon((cur) => (cur ? { ...cur, balance: c2.data.balance, options: c2.data.options || [] } : cur));
    }
  }
  // 8 characters → XXXX-XXXX (coupon) · 10 → XXXXX-XXXXX (old ticket)
  function fmtTicket(v) {
    const c = v.toUpperCase().replace(/[^0-9A-Z]/g, '').slice(0, 10);
    if (c.length > 8) return `${c.slice(0, 5)}-${c.slice(5)}`;
    return c.length > 4 ? `${c.slice(0, 4)}-${c.slice(4)}` : c;
  }

  const short = login && (login.options || []).some((o) => o.key !== 'bank' && o.price > login.user.balance);

  // first tab the shop left on (member is the default)
  useEffect(() => {
    if (!st) return;
    const order = [['login', tabsOn.member], ['qr', tabsOn.qr], ['ticket', codeTabOn], ['signup', tabsOn.signup]];
    const cur = order.find(([k]) => k === tab);
    if (cur && !cur[1]) { const first = order.find(([, on]) => on); if (first) setTab(first[0]); }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [st]);

  const pageStyle = look.bg
    ? { ...S.page, background: `linear-gradient(rgba(7,10,24,0.72), rgba(7,10,24,0.82)), url("${String(look.bg).replace(/"/g, '')}") center / cover no-repeat, #070a18` }
    : S.page;

  return (
    <div style={pageStyle}>
      <div style={S.left}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
          {/* rounded square (13 Nov: the shop logo is a rounded tile - a circle crop cut its corners and text); a round logo stays round */}
          {brand.logoUrl ? <img src={brand.logoUrl} alt="" style={{ width: 92, height: 92, flex: 'none', borderRadius: '22%', objectFit: 'contain', filter: 'drop-shadow(0 0 14px rgba(168,85,247,0.45))' }} /> : null}
          <div>
            <div style={{ fontSize: String(look.headline || shop).length > 24 ? 34 : 40, fontWeight: 800, letterSpacing: 0.5, lineHeight: 1.25, overflowWrap: 'anywhere' }}>{keepWords(look.headline || shop)}</div>
            {look.headline ? <div style={{ ...S.muted, fontSize: 15, marginTop: 2 }}>{shop}</div> : null}
            {machine ? <div style={{ marginTop: 8, display: 'inline-block', padding: '4px 12px', borderRadius: 999, background: 'rgba(0,240,255,0.12)', color: '#67e8f9', fontWeight: 700 }}>เครื่อง {machine}</div> : null}
          </div>
        </div>
        <div style={{ fontFamily: "'Chakra Petch', monospace", fontSize: 88, fontWeight: 800, lineHeight: 1, color: '#e0f2fe' }}>
          {now ? clock.toLocaleTimeString('th-TH', { hour: '2-digit', minute: '2-digit' }) : ' '}
        </div>
        <div style={{ fontSize: 18, color: '#cbd5e1' }}>{now ? clock.toLocaleDateString('th-TH', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }) : ' '}</div>
        <div style={{ ...S.muted, fontSize: 16, marginTop: 6 }}>
          {view && view.ending ? view.ending.text : started || (allowed ? `เครื่องนี้ว่าง — ล็อกอินสมาชิก สแกน QR หรือใช้${couponsOn ? 'คูปอง' : 'บัตรเวลา'}เพื่อเริ่มเล่น` : why || 'กำลังเตรียมเครื่อง…')}
        </div>
        <div style={{ ...S.muted, fontSize: 15, lineHeight: 1.7 }}>
          จ่ายเงินสดได้ที่เคาน์เตอร์: เติมเข้าบัญชีสมาชิก หรือซื้อ{couponsOn ? 'คูปองเงินสด' : 'บัตรเวลา'} (ไม่ต้องมีบัญชี)
          {siteHost ? <><br />เติมเงิน · เช่าเล่นจากที่บ้าน · ดูเวลาสะสม ได้ที่ <b style={{ color: '#f8fafc' }}>{siteHost}</b></> : null}
        </div>
        {lines.length ? (
          <div style={{ background: 'rgba(0,240,255,0.08)', border: '1px solid rgba(0,240,255,0.3)', borderRadius: 14, padding: '12px 16px', display: 'flex', flexDirection: 'column', gap: 4, fontSize: 15, lineHeight: 1.55 }}>
            {lines.map((l, i) => <div key={i}>• {l}</div>)}
          </div>
        ) : null}
      </div>

      <div style={S.card}>
        <div style={S.tabs}>
          {tabsOn.member !== false ? <button style={S.tab(tab === 'login')} onClick={() => { setTab('login'); setError(''); }}>สมาชิก</button> : null}
          {tabsOn.qr !== false ? <button style={S.tab(tab === 'qr')} onClick={() => { setTab('qr'); setError(''); }}>สแกน QR</button> : null}
          {codeTabOn ? <button style={S.tab(tab === 'ticket')} onClick={() => { setTab('ticket'); setError(''); }}>{couponsOn ? 'คูปอง' : 'บัตรเวลา'}</button> : null}
          {tabsOn.signup !== false ? <button style={S.tab(tab === 'signup')} onClick={() => { setTab('signup'); setError(''); }}>สมัครสมาชิก</button> : null}
        </div>

        {tab !== 'signup' && !allowed && (
          <div style={{ ...S.muted, fontSize: 15, padding: '18px 4px' }}>{started || why || 'ยังเริ่มเล่นที่เครื่องนี้ไม่ได้ในตอนนี้'}</div>
        )}

        {tab === 'login' && allowed && !login && (
          <form onSubmit={doLogin} style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <input style={S.input} placeholder="ชื่อผู้ใช้ (บัญชีเว็บร้าน)" value={username} onChange={(e) => setUsername(e.target.value)} autoFocus autoComplete="off" spellCheck={false} />
            <input style={S.input} type="password" placeholder="รหัสผ่าน" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="off" />
            {needCode && <input style={S.input} placeholder="รหัสยืนยัน 2 ชั้น (6 หลัก)" value={code} onChange={(e) => setCode(e.target.value)} inputMode="numeric" autoComplete="off" />}
            {error && <div style={S.err}>{error}</div>}
            <button type="submit" style={S.btn(busy)} disabled={busy}>{busy ? 'กำลังตรวจสอบ…' : 'เข้าสู่ระบบ'}</button>
            <div style={S.muted}>
              ไม่อยากพิมพ์รหัสบนเครื่องร้าน? กดแท็บ <b>สแกน QR</b> แล้วสแกนด้วยมือถือที่ล็อกอินเว็บร้านไว้ · ไม่มีบัญชี? <b>สมัครสมาชิก</b>ฟรี (สมัครเองหรือให้แคชเชียร์สมัครให้ · เก็บเวลาที่เหลือได้) หรือซื้อ<b>{couponsOn ? 'คูปองเงินสด' : 'บัตรเวลา'}</b>ที่เคาน์เตอร์
            </div>
          </form>
        )}

        {tab === 'login' && allowed && login && !topup && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div>
              <div style={{ fontSize: 18, fontWeight: 700 }}>สวัสดี {login.user.name}</div>
              <div style={S.muted}>ยอดเงิน <b style={{ color: '#f8fafc' }}>{baht(login.user.balance)}</b>{login.user.timeBankSec >= 60 ? <> · เวลาสะสม <b style={{ color: '#f8fafc' }}>{hm(login.user.timeBankSec)}</b></> : null} · เหลือเวลาเลือก {mmss((passExp - now) / 1000)}</div>
              {/* 14 พ.ย.: เวลาสะสมที่เก็บจากเครื่องราคาถูกกว่าใช้กับเครื่องนี้ไม่ได้ — บอกก่อนเลือก (เว็บรุ่นเก่าไม่ส่ง timeBankTotalSec = ไม่ขึ้นบรรทัดนี้) */}
              {(Number(login.user.timeBankTotalSec) || 0) - (Number(login.user.timeBankSec) || 0) >= 60 ? (
                <div style={S.muted}>เวลาสะสมอีก {hm(login.user.timeBankTotalSec - login.user.timeBankSec)} เก็บมาจากเครื่องราคาถูกกว่า ใช้กับเครื่องนี้ไม่ได้ (ใช้ได้กับเครื่องราคาเท่าเดิมหรือถูกกว่า)</div>
              ) : null}
            </div>
            <OptionScroll>
              {(login.options || []).map((o) => {
                const off = o.key !== 'bank' && o.price > login.user.balance;
                return (
                  <div key={o.key} style={S.opt(pick === o.key, off)} onClick={() => !off && setPick(o.key)}>
                    <div>
                      <div style={{ fontWeight: 700 }}>{o.label}</div>
                      <div style={S.muted}>{o.key === 'bank' ? 'ไม่หักเงิน' : `เล่นได้ ${hm(o.minutes * 60)}`}{off ? ' · ยอดเงินไม่พอ' : ''}</div>
                    </div>
                    <div style={{ fontWeight: 800, color: o.key === 'bank' ? '#34d399' : '#f8fafc' }}>{o.key === 'bank' ? 'ฟรี' : baht(o.price)}</div>
                  </div>
                );
              })}
              {!(login.options || []).length && <div style={S.muted}>เครื่องนี้ยังไม่มีแพ็กเกจ — ติดต่อพนักงาน</div>}
            </OptionScroll>
            {error && <div style={S.err}>{error}</div>}
            <button style={S.btn(busy || !pick)} disabled={busy || !pick} onClick={doStart}>{busy ? 'กำลังเริ่ม…' : 'เริ่มเล่น'}</button>
            <button style={{ ...S.ghost, borderColor: short ? '#00f0ff' : 'rgba(255,255,255,0.14)', color: short ? '#67e8f9' : '#cbd5e1' }} onClick={() => { setTopup(true); setError(''); }}>
              เติมเงิน{short ? ' (ยอดเงินไม่พอบางแพ็กเกจ)' : ''}
            </button>
            <button style={S.ghost} onClick={() => { setLogin(null); setPick(''); setError(''); }}>ยกเลิก / เปลี่ยนบัญชี</button>
            <div style={S.muted}>จ่ายสดได้ที่เคาน์เตอร์ — พนักงานเติมเข้าบัญชีให้ แล้วกด “เติมเงิน” → ยอดขึ้นที่นี่</div>
          </div>
        )}

        {tab === 'login' && allowed && login && topup && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <TopupPanel
              cfg={st && st.topup}
              pass={login.pass}
              title={`เติมเงินเข้าบัญชี ${login.user.name}`}
              onBalance={(b) => { setLogin((l) => (l ? { ...l, user: { ...l.user, balance: b } } : l)); setPassExp((x) => Math.max(x, Date.now() + PASS_MS)); }}
            />
            <button style={S.ghost} onClick={() => { setTopup(false); setPassExp((x) => Math.max(x, Date.now() + 60000)); }}>กลับไปเลือกแพ็กเกจ</button>
          </div>
        )}

        {tab === 'qr' && allowed && !login && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {qr && qrState === 'waiting' ? (
              <>
                <img src={qr.qr} alt="QR ล็อกอิน" style={S.qr} />
                <ol style={{ paddingLeft: 18, display: 'flex', flexDirection: 'column', gap: 4, fontSize: 14, lineHeight: 1.45, margin: 0 }}>
                  <li>เปิดกล้องมือถือที่<b>ล็อกอินเว็บร้านไว้แล้ว</b> สแกน QR นี้</li>
                  <li>ดูว่าชื่อเครื่องบนมือถือคือ <b>{machine}</b> แล้วกด “ล็อกอินที่เครื่องนี้”</li>
                  <li>จอนี้จะไปหน้าเลือกแพ็กเกจเอง</li>
                </ol>
                <div style={S.muted}>QR ใช้ได้อีก {mmss((qr.expiresAt - now) / 1000)} · ครั้งเดียว</div>
              </>
            ) : qrState === 'expired' || qrState === 'denied' || qrState === 'error' ? (
              <>
                <div style={qrState === 'error' ? S.err : S.muted}>{qrState === 'expired' ? 'QR หมดอายุแล้ว' : qrState === 'denied' ? 'มือถือกดยกเลิก' : error || 'ขอ QR ไม่สำเร็จ'}</div>
                <button style={S.btn(false)} onClick={newQr}>ขอ QR ใหม่</button>
              </>
            ) : (
              <div style={S.muted}>กำลังสร้าง QR…</div>
            )}
          </div>
        )}

        {tab === 'ticket' && allowed && !coupon && (
          <form onSubmit={submitTicket} style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <div style={{ fontSize: 16, fontWeight: 700 }}>{couponsOn ? 'ใช้คูปองเงินสด (ไม่ต้องมีบัญชี)' : 'ใช้บัตรเวลา (ไม่ต้องมีบัญชี)'}</div>
            <input
              style={{ ...S.input, fontSize: 24, letterSpacing: 4, textAlign: 'center', fontFamily: "'Chakra Petch', monospace" }}
              placeholder={couponsOn ? 'XXXX-XXXX' : 'XXXXX-XXXXX'}
              value={ticket}
              onChange={(e) => setTicket(fmtTicket(e.target.value))}
              autoComplete="off"
              spellCheck={false}
              autoFocus
            />
            {error && <div style={S.err}>{error}</div>}
            <button type="submit" style={S.btn(busy)} disabled={busy}>{busy ? 'กำลังตรวจสอบ…' : couponsOn ? 'ดูยอด / เลือกเวลา' : 'เริ่มเล่นด้วยบัตรนี้'}</button>
            <div style={S.muted}>
              {couponsOn
                ? 'ซื้อคูปองได้ที่เคาน์เตอร์ (จ่ายสด) · ใช้ได้ทุกเครื่องที่ว่าง ราคาเดียวกับสมาชิก · เลิกก่อนหมดเวลา เงินส่วนที่เหลือคืนเข้าคูปอง · บัตรเวลาแบบเก่า (10 ตัว) พิมพ์ช่องนี้ได้เหมือนเดิม'
                : 'ซื้อบัตรได้ที่เคาน์เตอร์ (จ่ายสด) · ใช้ได้ครั้งเดียว กับเครื่องในหมวดที่ซื้อ · เลิกเล่นแล้วเวลาที่เหลือไม่เก็บ — สมัครสมาชิกเพื่อเก็บเวลาได้'}
            </div>
          </form>
        )}

        {tab === 'ticket' && allowed && coupon && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div>
              <div style={{ fontSize: 18, fontWeight: 700 }}>คูปอง {coupon.tail}</div>
              <div style={S.muted}>
                ยอดในคูปอง <b style={{ color: '#f8fafc', fontSize: 16 }}>{baht(coupon.balance)}</b> · ใช้ได้ถึง {new Date(coupon.expiresAt).toLocaleDateString('th-TH', { day: 'numeric', month: 'short', year: '2-digit' })} · เหลือเวลาเลือก {mmss((couponExp - now) / 1000)}
              </div>
            </div>
            <OptionScroll>
              {coupon.options.map((o) => {
                const off = o.price > coupon.balance;
                return (
                  <div key={o.key} style={S.opt(couponPick === o.key, off)} onClick={() => !off && setCouponPick(o.key)}>
                    <div>
                      <div style={{ fontWeight: 700 }}>{o.label}</div>
                      <div style={S.muted}>เล่นได้ {hm(o.minutes * 60)}{off ? ' · ยอดในคูปองไม่พอ' : ''}</div>
                    </div>
                    <div style={{ fontWeight: 800 }}>{baht(o.price)}</div>
                  </div>
                );
              })}
              {!coupon.options.length && <div style={S.muted}>เครื่องนี้ยังไม่มีแพ็กเกจ — ติดต่อพนักงาน</div>}
            </OptionScroll>
            {mergeMsg && <div style={S.ok}>{mergeMsg}</div>}
            {mergeOpen ? (
              <form onSubmit={mergeCoupon} style={{ display: 'flex', gap: 8 }}>
                <input
                  style={{ ...S.input, fontFamily: "'Chakra Petch', monospace", letterSpacing: 2 }}
                  value={mergeCode}
                  onChange={(e) => { const c = e.target.value.toUpperCase().replace(/[^0-9A-Z]/g, '').slice(0, 8); setMergeCode(c.length > 4 ? `${c.slice(0, 4)}-${c.slice(4)}` : c); }}
                  placeholder="รหัสคูปองอีกใบ เช่น AFQW-1FA2"
                  autoFocus
                />
                <button type="submit" style={{ ...S.btn(busy), width: 'auto', padding: '0 20px', whiteSpace: 'nowrap' }} disabled={busy}>{busy ? 'กำลังรวม…' : 'รวม'}</button>
              </form>
            ) : (
              <button style={S.ghost} onClick={() => { setMergeOpen(true); setError(''); setMergeMsg(''); }}>+ รวมคูปองใบอื่นเข้าใบนี้</button>
            )}
            {error && <div style={S.err}>{error}</div>}
            <button style={S.btn(busy || !couponPick)} disabled={busy || !couponPick} onClick={startCoupon}>{busy ? 'กำลังเริ่ม…' : 'เริ่มเล่น (หักจากคูปอง)'}</button>
            <button style={S.ghost} onClick={() => { setCoupon(null); setCouponPick(''); setTicket(''); setError(''); }}>ยกเลิก / ใช้คูปองใบอื่น</button>
            <div style={S.muted}>ยอดไม่พอ? กด “รวมคูปองใบอื่นเข้าใบนี้” ได้เลย (ยอดทั้งหมดย้ายมาใบนี้ ใบที่รวมใช้ไม่ได้อีก) · เติมเงินเข้าคูปอง หรือคูปองที่หมดอายุแล้ว ทำได้ที่เคาน์เตอร์ · เลิกก่อนหมดเวลา (กดออกจากระบบ) ได้เงินคืนเข้าคูปอง = ยอดที่จ่ายหักค่าเวลาที่เล่นไป (คิดราคารายชั่วโมง ไม่ใช่ราคาแพ็กเกจ) · เหลือไม่ถึง 1 นาทีไม่คืน</div>
          </div>
        )}

        {tab === 'signup' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
              {site ? <img src={`${site}/api/topup-qr?to=register`} alt="QR สมัครสมาชิก" style={{ width: 150, height: 150, borderRadius: 12, background: '#fff' }} /> : null}
              <ol style={{ paddingLeft: 18, display: 'flex', flexDirection: 'column', gap: 6, fontSize: 14, lineHeight: 1.45 }}>
                <li>สแกน QR ด้วยกล้องมือถือ{siteHost ? <> หรือเปิด <b>{siteHost}/register</b></> : null}</li>
                <li>ตั้งชื่อผู้ใช้และรหัสผ่าน (สมัครฟรี)</li>
                <li>เติมเงินที่เคาน์เตอร์ (เงินสด) หรือโอนผ่านเว็บ</li>
                <li>กลับมาที่หน้านี้ กดแท็บ <b>สแกน QR</b> หรือ <b>สมาชิก</b></li>
              </ol>
            </div>
            <div style={{ background: 'rgba(0,240,255,0.08)', border: '1px solid rgba(0,240,255,0.35)', borderRadius: 12, padding: 12, fontSize: 14, lineHeight: 1.5 }}>
              <b style={{ color: '#67e8f9' }}>สมัครไม่เป็น? ให้แคชเชียร์สมัครให้ได้ฟรี</b>
              <br />
              <span style={{ color: '#cbd5e1' }}>เดินไปที่เคาน์เตอร์ บอกชื่อผู้ใช้ที่อยากได้ แล้วตั้งรหัสผ่านเอง (สแกน QR ด้วยมือถือ หรือพิมพ์ที่เคาน์เตอร์) · เติมเงินสดพร้อมกันได้เลย</span>
            </div>
            <div style={{ ...S.muted, background: 'rgba(255,255,255,0.04)', borderRadius: 12, padding: 12 }}>
              <b style={{ color: '#f8fafc' }}>ข้อดีของสมาชิก</b>
              <br />• เลิกเล่นก่อนหมดแพ็กเกจ เวลาที่เหลือเก็บไว้ใช้ครั้งหน้า
              <br />• เติมเงินได้ทั้งเงินสดที่เคาน์เตอร์ และโอนผ่าน QR ตลอด 24 ชม.
              <br />• เช่าเครื่องเล่นจากที่บ้านได้ด้วยบัญชีเดียวกัน
            </div>
            <button style={S.ghost} onClick={() => setTab('qr')}>สมัครแล้ว — สแกน QR เพื่อล็อกอิน</button>
          </div>
        )}
      </div>
      {build ? <div style={{ position: 'absolute', right: 14, bottom: 10, fontSize: 11, lineHeight: 1.5, color: 'rgba(203,213,225,0.38)', pointerEvents: 'none', fontFamily: "'Chakra Petch', monospace" }}>build {build}</div> : null}
    </div>
  );
}
