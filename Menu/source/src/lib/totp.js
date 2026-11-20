// 2-Step code (TOTP · RFC 6238) for game IDs bought from the shop (e.g. Rockstar "2FA: XXXX").
// Same rules as the shop web (at9-web src/lib/totp-client.ts): computed on this PC, the secret never leaves it.
// Plain JS SHA-1/HMAC (no crypto.subtle) so it works on any page origin.

const B32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/** tidy a base32 secret (drop spaces/dashes/trailing =, upper case) — "" when it is not usable base32 */
export function cleanTotpSecret(raw) {
  const s = String(raw || '').toUpperCase().replace(/[\s-]/g, '').replace(/=+$/, '');
  return /^[A-Z2-7]{16,128}$/.test(s) ? s : '';
}

function base32Bytes(secret) {
  let bits = 0;
  let value = 0;
  const out = [];
  for (const c of secret) {
    value = (value << 5) | B32.indexOf(c);
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return new Uint8Array(out);
}

function sha1(msg) {
  const ml = msg.length;
  const withPad = new Uint8Array(((ml + 9 + 63) >> 6) << 6);
  withPad.set(msg);
  withPad[ml] = 0x80;
  const bitLen = ml * 8;
  const dv = new DataView(withPad.buffer);
  dv.setUint32(withPad.length - 4, bitLen >>> 0);
  dv.setUint32(withPad.length - 8, Math.floor(bitLen / 2 ** 32));
  let h0 = 0x67452301, h1 = 0xefcdab89, h2 = 0x98badcfe, h3 = 0x10325476, h4 = 0xc3d2e1f0;
  const w = new Uint32Array(80);
  for (let off = 0; off < withPad.length; off += 64) {
    for (let i = 0; i < 16; i++) w[i] = dv.getUint32(off + i * 4);
    for (let i = 16; i < 80; i++) {
      const x = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16];
      w[i] = (x << 1) | (x >>> 31);
    }
    let a = h0, b = h1, c = h2, d = h3, e = h4;
    for (let i = 0; i < 80; i++) {
      const f = i < 20 ? (b & c) | (~b & d) : i < 40 ? b ^ c ^ d : i < 60 ? (b & c) | (b & d) | (c & d) : b ^ c ^ d;
      const k = i < 20 ? 0x5a827999 : i < 40 ? 0x6ed9eba1 : i < 60 ? 0x8f1bbcdc : 0xca62c1d6;
      const t = (((a << 5) | (a >>> 27)) + f + e + k + w[i]) >>> 0;
      e = d;
      d = c;
      c = (b << 30) | (b >>> 2);
      b = a;
      a = t;
    }
    h0 = (h0 + a) >>> 0;
    h1 = (h1 + b) >>> 0;
    h2 = (h2 + c) >>> 0;
    h3 = (h3 + d) >>> 0;
    h4 = (h4 + e) >>> 0;
  }
  const out = new Uint8Array(20);
  const odv = new DataView(out.buffer);
  [h0, h1, h2, h3, h4].forEach((h, i) => odv.setUint32(i * 4, h));
  return out;
}

function hmacSha1(key, msg) {
  const k = key.length > 64 ? sha1(key) : key;
  const ipad = new Uint8Array(64 + msg.length);
  const opad = new Uint8Array(64 + 20);
  for (let i = 0; i < 64; i++) {
    const kb = i < k.length ? k[i] : 0;
    ipad[i] = kb ^ 0x36;
    opad[i] = kb ^ 0x5c;
  }
  ipad.set(msg, 64);
  opad.set(sha1(ipad), 64);
  return sha1(opad);
}

/** 6-digit TOTP code at time t (ms) · 30 s steps (what every authenticator uses) */
export function totpCode(secret, t = Date.now(), digits = 6, period = 30) {
  const key = base32Bytes(cleanTotpSecret(secret));
  if (!key.length) return '';
  const counter = Math.floor(t / 1000 / period);
  const msg = new Uint8Array(8);
  const dv = new DataView(msg.buffer);
  dv.setUint32(0, Math.floor(counter / 2 ** 32));
  dv.setUint32(4, counter >>> 0);
  const h = hmacSha1(key, msg);
  const o = h[h.length - 1] & 0x0f;
  const bin = ((h[o] & 0x7f) << 24) | (h[o + 1] << 16) | (h[o + 2] << 8) | h[o + 3];
  return String(bin % 10 ** digits).padStart(digits, '0');
}

/** seconds left before the code changes */
export function totpRemaining(t = Date.now(), period = 30) {
  return period - (Math.floor(t / 1000) % period);
}

const TOTP_LABEL = /2\s*-?\s*fa|totp|authenticator|auth\s*key|2\s*-?\s*step|two[\s-]*factor|secret\s*key|otp\s*key|รหัส\s*2|คีย์\s*2|ยืนยันตัวตน\s*2/i;

/** 2FA secret in one line of the ID details — "2FA: XXXX", an otpauth:// link, or a bare upper-case base32 line · none = "" */
export function totpSecretFromLine(line) {
  const t = String(line || '').trim();
  const uri = /otpauth:\/\/totp\/[^\s]*[?&]secret=([A-Z2-7=]+)/i.exec(t);
  if (uri) return cleanTotpSecret(uri[1]);
  const colon = t.search(/[:：]/);
  if (colon > 0) {
    const label = t.slice(0, colon);
    if (!TOTP_LABEL.test(label)) return '';
    return cleanTotpSecret(t.slice(colon + 1));
  }
  // no label: only a long all-capitals base32 string (so passwords / e-mails are never taken for a key)
  const bare = t.replace(/\s/g, '');
  return /^[A-Z2-7]{16,64}=*$/.test(bare) && /[2-7]/.test(bare) && /[A-Z]/.test(bare) ? cleanTotpSecret(bare) : '';
}

/** visible lines of the ID details: lines starting with # are the shop's own data (e.g. the mail token for Steam Guard) — never shown */
export function visibleLines(text) {
  return String(text || '').split(/\r?\n/).map((l) => l.trim()).filter((l) => l && !l.startsWith('#'));
}

/** first 2FA secret in the ID details ("" = this ID has no 2-Step key) */
export function totpSecretFromText(text) {
  for (const l of visibleLines(text)) {
    const s = totpSecretFromLine(l);
    if (s) return s;
  }
  return '';
}
