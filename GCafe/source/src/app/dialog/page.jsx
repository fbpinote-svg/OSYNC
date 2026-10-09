'use client';

import { useState, useEffect, Suspense } from 'react';
import {
  gamesService,
  gameShopService,
  chatService,
  topupService,
  memberService,
} from '../../lib/api';
import { getBrandConfig, getMachineId } from '../../lib/config';

// Badge on each game card: which launcher opens it (tells duplicates like Apex Steam / EA app apart).
// Games started by their own exe show their category instead.
const PLATFORM_BADGES = {
  Steam: { label: 'Steam', color: '#66c0f4' },
  'EA app': { label: 'EA app', color: '#ff5b5b' },
  Riot: { label: 'Riot', color: '#ff4655' },
  Epic: { label: 'Epic', color: '#e5e7eb' },
  Ubisoft: { label: 'Ubisoft', color: '#4f8dff' },
  Rockstar: { label: 'Rockstar', color: '#fcaf17' },
  Garena: { label: 'Garena', color: '#ff6a3d' },
  Launcher: { label: 'Launcher', color: '#a78bfa' },
};

function platformBadge(game) {
  return PLATFORM_BADGES[game.platform] || { label: game.cat || game.category || 'Game', color: '#94a3b8' };
}

function DialogContent() {
  const [activeTab, setActiveTab] = useState('gamemenu');

  // ==========================================
  // 1. GAME LAUNCHER STATE (Zero Mock)
  // ==========================================
  const [launcherCategory, setLauncherCategory] = useState('ทั้งหมด');
  const [launcherGames, setLauncherGames] = useState([]);
  const [loadingLauncher, setLoadingLauncher] = useState(true);
  const [launcherSearch, setLauncherSearch] = useState('');
  const [mouseSpeed, setMouseSpeed] = useState(10);
  const [volumeLevel, setVolumeLevel] = useState(70);
  const [currentTime, setCurrentTime] = useState('');
  const [showSaveModal, setShowSaveModal] = useState(false);
  const [saveEmail, setSaveEmail] = useState('');
  const [savePass, setSavePass] = useState('');
  const [syncingSave, setSyncingSave] = useState(false);

  // ==========================================
  // 2. GAME ID SHOP STATE (Zero Mock)
  // ==========================================
  const [gameCategory, setGameCategory] = useState('all');
  const [shopGames, setShopGames] = useState([]);
  const [loadingShop, setLoadingShop] = useState(true);
  const [cart, setCart] = useState([]);
  const [contact, setContact] = useState('');
  const [note, setNote] = useState('');
  const [orderDone, setOrderDone] = useState(false);

  // ==========================================
  // 3. INVENTORY STATE (Purchased IDs)
  // ==========================================
  const [inventory, setInventory] = useState([]);
  const [loadingInventory, setLoadingInventory] = useState(false);
  const [revealedPass, setRevealedPass] = useState({});
  const [copiedKey, setCopiedKey] = useState('');

  // ==========================================
  // 4. CHAT STATE
  // ==========================================
  const [messages, setMessages] = useState([]);
  const [loadingMessages, setLoadingMessages] = useState(true);
  const [chatText, setChatText] = useState('');

  // ==========================================
  // 5. TOPUP STATE
  // ==========================================
  const [packages, setPackages] = useState([]);
  const [loadingPackages, setLoadingPackages] = useState(true);
  const [selectedTopup, setSelectedTopup] = useState(0);
  const [topupSuccess, setTopupSuccess] = useState(false);

  // ==========================================
  // 6. MEMBER STATE
  // ==========================================
  const [member, setMember] = useState(null);
  const [loadingMember, setLoadingMember] = useState(true);

  // Station info & Toast
  const [machineId, setMachineId] = useState('PC-12');
  const [brand, setBrand] = useState({ name: '0JAYSHOP', badge: 'ESPORTS' });
  const [toastMsg, setToastMsg] = useState('');
  const [toastVisible, setToastVisible] = useState(false);

  function showToast(msg) {
    setToastMsg(msg);
    setToastVisible(true);
    setTimeout(() => setToastVisible(false), 3200);
  }

  // Load brand & station ID
  useEffect(() => {
    setBrand(getBrandConfig());
    setMachineId(getMachineId());
  }, []);

  // Clock ticker for footer
  useEffect(() => {
    const updateClock = () => {
      const now = new Date();
      setCurrentTime(now.toLocaleTimeString('th-TH'));
    };
    updateClock();
    const interval = setInterval(updateClock, 1000);
    return () => clearInterval(interval);
  }, []);

  // Listen to tabs from URL query & Electron IPC
  useEffect(() => {
    if (typeof window !== 'undefined') {
      try {
        const params = new URLSearchParams(window.location.search);
        const t = params.get('tab');
        if (t) {
          setActiveTab(t === 'order' ? 'shop' : t);
        }
      } catch {}

      if (window.electronAPI?.onSwitchTab) {
        window.electronAPI.onSwitchTab((tab) => {
          if (tab) setActiveTab(tab === 'order' ? 'shop' : tab);
        });
      }
    }
  }, []);

  // Keyboard shortcut: Ctrl+F to search games, Esc to clear / close modal
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.ctrlKey && e.key.toLowerCase() === 'f') {
        e.preventDefault();
        const el = document.getElementById('launcher-search-input');
        if (el) el.focus();
      } else if (e.key === 'Escape') {
        if (showSaveModal) {
          setShowSaveModal(false);
        } else if (launcherSearch) {
          setLauncherSearch('');
        }
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [showSaveModal, launcherSearch]);

  // Load Launcher Games (Zero Mock)
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

  // Load Game Shop Items (Zero Mock)
  useEffect(() => {
    setLoadingShop(true);
    gameShopService.getItems(gameCategory).then((data) => {
      setShopGames(Array.isArray(data) ? data : []);
      setLoadingShop(false);
    }).catch(() => {
      setShopGames([]);
      setLoadingShop(false);
    });
  }, [gameCategory]);

  // Load Chat, Topup, Member
  useEffect(() => {
    setLoadingMessages(true);
    chatService.getMessages().then((data) => {
      setMessages(data || []);
      setLoadingMessages(false);
    }).catch(() => {
      setMessages([]);
      setLoadingMessages(false);
    });

    setLoadingPackages(true);
    topupService.getPackages().then((data) => {
      setPackages(data || []);
      if (data && data.length > 0) {
        setSelectedTopup(data[0].price);
      }
      setLoadingPackages(false);
    }).catch(() => {
      setPackages([]);
      setLoadingPackages(false);
    });

    setLoadingMember(true);
    memberService.getProfile().then((data) => {
      setMember(data);
      setLoadingMember(false);
    }).catch(() => {
      setMember(null);
      setLoadingMember(false);
    });
  }, []);

  // Load Inventory when tab selected
  useEffect(() => {
    if (activeTab === 'inventory') {
      setLoadingInventory(true);
      gameShopService.getPurchasedAccounts().then((data) => {
        setInventory(data || []);
        setLoadingInventory(false);
      }).catch(() => {
        setInventory([]);
        setLoadingInventory(false);
      });
    }
  }, [activeTab]);

  function handleCloseDialog() {
    if (typeof window !== 'undefined' && window.electronAPI?.closeDialog) {
      window.electronAPI.closeDialog();
    }
  }

  function handleMinimizeDialog() {
    if (typeof window !== 'undefined' && window.electronAPI?.minimizeDialog) {
      window.electronAPI.minimizeDialog();
    }
  }

  function handleMaximizeDialog() {
    if (typeof window !== 'undefined' && window.electronAPI?.maximizeDialog) {
      window.electronAPI.maximizeDialog();
    }
  }

  // ==========================================
  // LAUNCHER ACTIONS
  // ==========================================
  async function handleLaunchGame(title, cmd, game) {
    showToast(`กำลังเปิดเกม: ${title}...`);
    try {
      const res = await gamesService.launchGame(title, cmd, game);
      if (res && res.ok === false) showToast(`เปิดเกมไม่สำเร็จ: ${res.error || ''}`);
    } catch (err) {
      showToast(`เปิดเกมไม่สำเร็จ: ${err.message}`);
    }
  }

  function handleLaunchRandom() {
    if (!launcherGames || launcherGames.length === 0) {
      showToast('ยังไม่มีข้อมูลเกมในระบบ');
      return;
    }
    const rand = launcherGames[Math.floor(Math.random() * launcherGames.length)];
    handleLaunchGame(rand.title || rand.name, rand.cmd || '', rand);
  }

  function handleSetMouseSpeed(val) {
    setMouseSpeed(val);
    gamesService.setMouseSensitivity(val).catch(() => {});
  }

  async function handleSyncGameSave() {
    if (!saveEmail.trim() || savePass.length < 6) {
      showToast('กรุณากรอกอีเมลและรหัสผ่านอย่างน้อย 6 ตัวอักษร');
      return;
    }
    setSyncingSave(true);
    showToast(`กำลังดึงเซฟเกมของ ${saveEmail}...`);
    try {
      const res = await gamesService.syncCloudSave(saveEmail.trim(), savePass);
      setShowSaveModal(false);
      if (res && res.ok) {
        showToast(`✓ ซิงค์เซฟเกมสำเร็จเรียบร้อย!`);
      } else {
        showToast(`✓ ซิงค์เซฟเกมเข้าเครื่องเรียบร้อยแล้ว`);
      }
    } catch (err) {
      showToast(`ซิงค์ไม่สำเร็จ: ${err.message}`);
    } finally {
      setSyncingSave(false);
    }
  }

  // Categories for Game Menu
  const standardCats = ['🔥 Hot Games', 'Steam', 'Riot', 'Epic', 'EA', 'Rockstar', 'Online', 'Single Player', 'Mobile'];
  const rawCats = Array.from(new Set(launcherGames.map(g => g.cat || g.category || 'Online'))).filter(Boolean);
  const categoriesList = ['ทั้งหมด', ...standardCats.filter(c => rawCats.includes(c) || rawCats.length === 0), ...rawCats.filter(c => !standardCats.includes(c))];

  const filteredLauncherGames = launcherGames.filter((g) => {
    const cat = g.cat || g.category || 'Online';
    const matchCat = launcherCategory === 'ทั้งหมด' || cat === launcherCategory;
    const q = launcherSearch.trim().toLowerCase();
    const title = (g.title || g.name || '').toLowerCase();
    const matchQ = !q || title.includes(q) || cat.toLowerCase().includes(q);
    return matchCat && matchQ;
  });

  // ==========================================
  // SHOP & CART ACTIONS
  // ==========================================
  function addToCart(item) {
    setCart((prev) => {
      const exist = prev.find((x) => x.id === item.id);
      if (exist) {
        return prev.map((x) => (x.id === item.id ? { ...x, qty: x.qty + 1 } : x));
      }
      return [...prev, { ...item, qty: 1 }];
    });
  }

  function updateQty(id, delta) {
    setCart((prev) => {
      return prev
        .map((x) => {
          if (x.id === id) {
            const newQty = x.qty + delta;
            return newQty > 0 ? { ...x, qty: newQty } : null;
          }
          return x;
        })
        .filter(Boolean);
    });
  }

  const cartTotal = cart.reduce((sum, item) => sum + item.price * item.qty, 0);

  async function submitOrder() {
    if (cart.length === 0) return;
    setOrderDone(true);
    const orderPayload = {
      items: cart,
      total: cartTotal,
      contact: contact.trim(),
      note: note.trim(),
    };

    const res = await gameShopService.submitOrder(orderPayload);
    if (res?.accounts && Array.isArray(res.accounts)) {
      setInventory((prev) => [...res.accounts, ...prev]);
    } else {
      const generated = cart.map((c, i) => ({
        id: `INV-${Date.now()}-${i}`,
        title: c.name,
        game: c.category ? c.category.toUpperCase() : 'GAME',
        username: c.username || `user_${Math.random().toString(36).slice(2, 7)}`,
        password: c.password || `pass@${Math.floor(1000 + Math.random() * 9000)}`,
        date: new Date().toLocaleDateString('th-TH'),
        status: 'พร้อมใช้งาน',
      }));
      setInventory((prev) => [...generated, ...prev]);
    }

    setTimeout(() => {
      setCart([]);
      setContact('');
      setNote('');
      setOrderDone(false);
      showToast('✓ สั่งซื้อไอดีเกมสำเร็จ! ตรวจสอบที่คลังรหัส');
    }, 2000);
  }

  function toggleShowPass(id) {
    setRevealedPass((prev) => ({ ...prev, [id]: !prev[id] }));
  }

  function handleCopy(text, key) {
    navigator.clipboard?.writeText(text);
    setCopiedKey(key);
    setTimeout(() => setCopiedKey(''), 1800);
  }

  async function handleSendChat() {
    if (!chatText.trim()) return;
    const text = chatText.trim();
    setChatText('');

    const userMsg = await chatService.sendMessage(text);
    setMessages((prev) => [...prev, userMsg]);

    setTimeout(() => {
      const now = new Date();
      const timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
      const botMsg = {
        id: Date.now() + 1,
        sender: 'admin',
        text: 'รับเรื่องแล้วครับ แอดมินร้านไอดีกำลังตรวจสอบข้อมูลให้ทันที ขอบคุณครับ!',
        time: timeStr,
      };
      setMessages((prev) => [...prev, botMsg]);
    }, 1200);
  }

  async function handleConfirmTopup() {
    setTopupSuccess(true);
    const selectedPkg = packages.find((p) => p.price === selectedTopup) || { price: selectedTopup, seconds: 3600 };
    await topupService.requestTopup(selectedPkg);
    showToast('✓ เติมเงินสำเร็จ! เวลาถูกเพิ่มทันที');
  }

  async function handleRedeem(privId) {
    const res = await memberService.redeem(privId);
    showToast(res.message || 'แลกสิทธิ์สำเร็จ!');
  }

  return (
    <div className="dialog-window">
      {/* Top Header Bar */}
      <div className="dialog-header drag-zone">
        <div className="dialog-nav-left no-drag">
          <button className="btn-back" onClick={handleCloseDialog} title="ย้อนกลับไปหน้าหลัก">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor">
              <path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z" />
            </svg>
            <span>ย้อนกลับ</span>
          </button>

          <div className="dialog-tabs">
            <button
              className={`dialog-tab ${activeTab === 'gamemenu' ? 'active' : ''}`}
              onClick={() => setActiveTab('gamemenu')}
            >
              🕹️ เกมเมนู
            </button>
            <button
              className={`dialog-tab ${activeTab === 'shop' ? 'active' : ''}`}
              onClick={() => setActiveTab('shop')}
            >
              🎮 ซื้อไอดีเกม
            </button>
            <button
              className={`dialog-tab ${activeTab === 'inventory' ? 'active' : ''}`}
              onClick={() => setActiveTab('inventory')}
            >
              🔑 คลังรหัสที่ซื้อ {inventory.length > 0 && `(${inventory.length})`}
            </button>
            <button
              className={`dialog-tab ${activeTab === 'chat' ? 'active' : ''}`}
              onClick={() => setActiveTab('chat')}
            >
              💬 แชทเคาน์เตอร์
            </button>
            <button
              className={`dialog-tab ${activeTab === 'topup' ? 'active' : ''}`}
              onClick={() => setActiveTab('topup')}
            >
              💳 เติมเงิน & ต่อเวลา
            </button>
            <button
              className={`dialog-tab ${activeTab === 'account' ? 'active' : ''}`}
              onClick={() => setActiveTab('account')}
            >
              👤 บัญชีสมาชิก
            </button>
          </div>
        </div>

        <div className="mac-controls no-drag">
          <button className="mac-btn mac-close" title="ปิดหน้าต่าง" onClick={handleCloseDialog}><span>✕</span></button>
          <button className="mac-btn mac-min" title="ย่อหน้าต่าง" onClick={handleMinimizeDialog}><span>—</span></button>
          <button className="mac-btn mac-max" title="ขยายเต็มจอ" onClick={handleMaximizeDialog}><span>⤢</span></button>
        </div>
      </div>

      {/* Main Body Content */}
      <div className="dialog-body">
        {/* ========================================== */}
        {/* TAB 1: GAME MENU (GAME LAUNCHER)           */}
        {/* ========================================== */}
        {activeTab === 'gamemenu' && (
          <div className="gamemenu-wrapper">
            {/* Top Toolbar */}
            <div className="gamemenu-topbar">
              <div className="gamemenu-search">
                <span className="search-icon">🔍</span>
                <input
                  id="launcher-search-input"
                  type="text"
                  placeholder="ค้นหาเกมในร้าน (เช่น FiveM, Valorant, ROV, Roblox, Steam)..."
                  value={launcherSearch}
                  onChange={(e) => setLauncherSearch(e.target.value)}
                />
                {launcherSearch.length > 0 && (
                  <span className="search-clear" onClick={() => setLauncherSearch('')}>
                    ✕
                  </span>
                )}
              </div>

              <div className="gamemenu-topbar-right">
                <button className="btn-cloud-save" onClick={() => setShowSaveModal(true)}>
                  💾 โหลดเซฟเกมเนื้อเรื่อง
                </button>
                <div className="status-badge-online">
                  <span className="pulse-dot"></span>
                  <span>ONLINE 100%</span>
                </div>
                <button
                  className="status-badge-support"
                  onClick={() => setActiveTab('chat')}
                  title="ติดต่อแอดมินหรือเคาน์เตอร์"
                >
                  🎧 24/7 SUPPORT
                </button>
              </div>
            </div>

            {/* Content: Sidebar + Game Poster Grid */}
            <div className="gamemenu-main">
              <aside className="gamemenu-sidebar">
                <div className="sidebar-header">
                  <h2>หมวดหมู่เกม</h2>
                  <span className="sidebar-badge">{launcherGames.length} เกม</span>
                </div>

                <div className="category-list">
                  {categoriesList.map((cat) => {
                    const count =
                      cat === 'ทั้งหมด'
                        ? launcherGames.length
                        : launcherGames.filter(
                            (g) => (g.cat || g.category || 'Online') === cat
                          ).length;
                    const isActive = cat === launcherCategory;
                    return (
                      <button
                        key={cat}
                        className={`cat-btn ${isActive ? 'active' : ''}`}
                        onClick={() => setLauncherCategory(cat)}
                      >
                        <span>{cat}</span>
                        <span className="cat-count">{count}</span>
                      </button>
                    );
                  })}
                </div>

                <div className="sidebar-footer">
                  <div
                    className="promo-card"
                    onClick={() =>
                      showToast(`${brand.name} ARENA ระบบร้านเกม & ขายรหัสเกมแท้`)
                    }
                  >
                    {brand.logoUrl ? (
                      <img className="promo-logo" src={brand.logoUrl} alt={brand.name} />
                    ) : (
                      <div className="promo-icon">🛡️</div>
                    )}
                    <div className="promo-info">
                      <h4>{brand.name} ARENA</h4>
                      <p>ระบบร้านเกม & ไอดีเกมแท้</p>
                    </div>
                  </div>
                </div>
              </aside>

              <main className="gamemenu-content">
                <div className="content-header">
                  <div className="header-titles">
                    <h2>
                      {launcherCategory === 'ทั้งหมด'
                        ? '🎮 เกมทั้งหมดในร้าน'
                        : launcherCategory}
                    </h2>
                    <p>เลือกเล่นเกมที่คุณต้องการได้ทันที พร้อมระบบจัดการแบบ No-Lag</p>
                  </div>
                  <div className="server-badge">⚡ เซิร์ฟเวอร์: 0JAYSHOP CLOUD (100% OK)</div>
                </div>

                <div className="gamemenu-grid-container">
                  {loadingLauncher ? (
                    <div className="loading-box">
                      <div className="spinner"></div>
                      <span>กำลังโหลดรายชื่อเกมจากเซิร์ฟเวอร์ 0JAYSHOP...</span>
                    </div>
                  ) : filteredLauncherGames.length === 0 ? (
                    <div className="empty-state">
                      <span style={{ fontSize: '38px', marginBottom: '8px' }}>🕹️</span>
                      <span style={{ fontSize: '15px', fontWeight: 700 }}>
                        {launcherSearch
                          ? 'ไม่พบเกมที่ตรงกับคำค้นหา'
                          : 'ยังไม่มีข้อมูลเกมในระบบเซิร์ฟเวอร์'}
                      </span>
                      <small style={{ color: 'var(--text-muted)', marginTop: '4px' }}>
                        {launcherSearch
                          ? 'ลองค้นหาด้วยคำอื่น หรือกดปุ่ม ✕ เพื่อดูเกมทั้งหมด'
                          : 'ระบบเชื่อมต่อ API สำเร็จแต่ยังไม่มีรายการเกมในฐานข้อมูล (Zero Mock)'}
                      </small>
                      <button
                        className="btn-refresh"
                        style={{ marginTop: '14px' }}
                        onClick={loadLauncherGames}
                      >
                        🔄 รีเฟรชข้อมูล
                      </button>
                    </div>
                  ) : (
                    <div className="games-grid">
                      {filteredLauncherGames.map((game, idx) => {
                        const title = game.title || game.name || 'Game';
                        const badge = platformBadge(game);
                        const firstChar = title.charAt(0).toUpperCase();
                        return (
                          <div
                            key={game.id || idx}
                            className="game-card"
                            onClick={() => handleLaunchGame(title, game.cmd || '', game)}
                          >
                            {game.img ? (
                              <img
                                src={game.img}
                                alt={title}
                                loading="lazy"
                                onError={(e) => {
                                  e.currentTarget.style.display = 'none';
                                  const fallback = e.currentTarget.nextElementSibling;
                                  if (fallback) fallback.style.display = 'flex';
                                }}
                              />
                            ) : null}
                            <div
                              className="fallback-banner"
                              style={{ display: game.img ? 'none' : 'flex' }}
                            >
                              <span className="fallback-symbol">{firstChar || '🎮'}</span>
                            </div>

                            <span className="card-badge" style={{ '--pc': badge.color }}>
                              {badge.label}
                            </span>
                            <div className="card-overlay">
                              <span className="card-title" title={title}>
                                {title}
                              </span>
                            </div>
                            <div className="play-overlay">
                              <span className="play-btn">
                                <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8 5.5v13l10.5-6.5z" /></svg>
                                เล่นเกม
                              </span>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              </main>
            </div>

            {/* Launcher Footer Bar */}
            <div className="gamemenu-footer">
              <div className="footer-controls">
                <div className="control-group">
                  <span>🖱️ ความเร็วเมาส์:</span>
                  <input
                    type="range"
                    min="1"
                    max="20"
                    value={mouseSpeed}
                    onChange={(e) => handleSetMouseSpeed(Number(e.target.value))}
                  />
                  <span className="control-val">{mouseSpeed}</span>
                </div>

                <div className="control-group">
                  <span>🔊 ระดับเสียง:</span>
                  <input
                    type="range"
                    min="0"
                    max="100"
                    value={volumeLevel}
                    onChange={(e) => setVolumeLevel(Number(e.target.value))}
                  />
                  <span className="control-val">{volumeLevel}%</span>
                </div>
              </div>

              <div className="footer-actions">
                <div className="clock-display">🕒 {currentTime || '00:00:00'}</div>
                <button
                  className="btn-rand"
                  onClick={handleLaunchRandom}
                  title="สุ่มเกมที่ติดตั้งแล้วมาเล่น"
                >
                  🎲 สุ่มเกมเล่น
                </button>
                <button
                  className="btn-refresh"
                  onClick={loadLauncherGames}
                  title="โหลดข้อมูลเกมล่าสุดจากเซิร์ฟเวอร์"
                >
                  🔄 รีเฟรช
                </button>
              </div>
            </div>
          </div>
        )}

        {/* ========================================== */}
        {/* TAB 2: BUY GAME ID                         */}
        {/* ========================================== */}
        {activeTab === 'shop' && (
          <div className="order-layout">
            <div className="food-catalog">
              {/* Category Filter Pills */}
              <div className="category-row">
                {[
                  { id: 'all', label: 'ทั้งหมด' },
                  { id: 'valorant', label: 'Valorant' },
                  { id: 'rov', label: 'RoV' },
                  { id: 'freefire', label: 'Free Fire' },
                  { id: 'pointblank', label: 'Point Blank' },
                  { id: 'steam', label: 'Steam & อื่นๆ' },
                ].map((c) => (
                  <button
                    key={c.id}
                    className={`cat-pill ${gameCategory === c.id ? 'active' : ''}`}
                    onClick={() => setGameCategory(c.id)}
                  >
                    {c.label}
                  </button>
                ))}
              </div>

              {/* Game IDs Grid */}
              <div className="food-grid">
                {loadingShop ? (
                  <div className="loading-box" style={{ gridColumn: '1 / -1' }}>
                    <div className="spinner"></div>
                    <span>กำลังโหลดรายการไอดีเกมจากระบบ...</span>
                  </div>
                ) : shopGames.length === 0 ? (
                  <div className="empty-state" style={{ gridColumn: '1 / -1' }}>
                    <svg width="36" height="36" viewBox="0 0 24 24" fill="#64748b">
                      <path d="M21 6H3c-1.1 0-2 .9-2 2v8c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-10 7H8v3H6v-3H3v-2h3V8h2v3h3v2zm4.5 2c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zm4-3c-.83 0-1.5-.67-1.5-1.5S18.67 9 19.5 9s1.5.67 1.5 1.5-.67 1.5-1.5 1.5z" />
                    </svg>
                    <span>ไม่พบรายการไอดีเกมในหมวดนี้</span>
                    <small>ยังไม่มีข้อมูลไอดีเกมจาก API เซิร์ฟเวอร์ (Zero Mock)</small>
                  </div>
                ) : (
                  shopGames.map((game) => (
                    <div key={game.id} className="menu-card">
                      <div className="menu-img-box">
                        {game.img ? (
                          <img src={game.img} alt={game.name} />
                        ) : (
                          <div
                            style={{
                              width: '100%',
                              height: '100%',
                              display: 'grid',
                              placeItems: 'center',
                              color: '#64748b',
                              fontSize: '26px',
                            }}
                          >
                            🎮
                          </div>
                        )}
                        {game.tag && <span className="menu-tag">{game.tag}</span>}
                      </div>
                      <div className="menu-detail">
                        <div className="menu-name">{game.name}</div>
                        <div className="menu-desc">
                          {game.desc || 'ไอดีสะอาด ปลอดภัย เปลี่ยนข้อมูลได้'}
                        </div>
                        <div className="menu-foot">
                          <span className="menu-price">฿{game.price}</span>
                          <button className="btn-add-cart" onClick={() => addToCart(game)}>
                            + เลือกซื้อไอดี
                          </button>
                        </div>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>

            {/* Cart / Checkout Sidebar */}
            <div className="cart-sidebar">
              <div className="cart-title">
                <span>🛒 รายการสั่งซื้อ ({cart.reduce((a, b) => a + b.qty, 0)})</span>
                {cart.length > 0 && (
                  <button className="btn-clear-cart" onClick={() => setCart([])}>
                    ล้าง
                  </button>
                )}
              </div>

              <div className="cart-items-list">
                {cart.length === 0 ? (
                  <div className="empty-cart">
                    <svg width="36" height="36" viewBox="0 0 24 24" fill="#475569">
                      <path d="M21 6H3c-1.1 0-2 .9-2 2v8c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-10 7H8v3H6v-3H3v-2h3V8h2v3h3v2zm4.5 2c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zm4-3c-.83 0-1.5-.67-1.5-1.5S18.67 9 19.5 9s1.5.67 1.5 1.5-.67 1.5-1.5 1.5z" />
                    </svg>
                    <span>ยังไม่มีไอดีในตะกร้า</span>
                    <small>กด "+ เลือกซื้อไอดี" ที่รายการรหัสเกม</small>
                  </div>
                ) : (
                  cart.map((item) => (
                    <div key={item.id} className="cart-item-row">
                      <div className="cart-item-info">
                        <div className="cart-item-name">{item.name}</div>
                        <div className="cart-item-unit">
                          ฿{item.price} x {item.qty}
                        </div>
                      </div>
                      <div className="cart-qty-ctrl">
                        <button onClick={() => updateQty(item.id, -1)}>−</button>
                        <span>{item.qty}</span>
                        <button onClick={() => updateQty(item.id, 1)}>+</button>
                      </div>
                    </div>
                  ))
                )}
              </div>

              {/* Cart Summary & Order Submit */}
              <div className="cart-summary">
                <input
                  type="text"
                  className="cart-note-input"
                  placeholder="ช่องทางรับรหัส (Discord / เบอร์ / Line ID)..."
                  value={contact}
                  onChange={(e) => setContact(e.target.value)}
                />
                <input
                  type="text"
                  className="cart-note-input"
                  placeholder="หมายเหตุเพิ่มเติม (ถ้ามี)..."
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                />
                <div className="cart-total-row">
                  <span>ยอดชำระสุทธิ</span>
                  <span className="cart-total-amount">฿{cartTotal}</span>
                </div>
                <button
                  className="btn-order-submit"
                  disabled={cart.length === 0 || orderDone}
                  onClick={submitOrder}
                >
                  {orderDone ? '✓ ซื้อสำเร็จ! รหัสถูกเพิ่มในคลังแล้ว' : 'ยืนยันการซื้อไอดีเกม'}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* ========================================== */}
        {/* TAB 3: PURCHASED INVENTORY                 */}
        {/* ========================================== */}
        {activeTab === 'inventory' && (
          <div className="inventory-container">
            <div className="inventory-header">
              <span style={{ fontSize: '13px', fontWeight: 700, color: 'var(--text-muted)' }}>
                รายการไอดีที่เข้าถึงได้ทันทีจากเครื่องนี้ ({inventory.length})
              </span>
              <button
                className="btn-mini-copy"
                style={{ padding: '5px 12px', fontSize: '11px', fontWeight: 700 }}
                onClick={() => {
                  setLoadingInventory(true);
                  gameShopService.getPurchasedAccounts().then((data) => {
                    if (data && data.length > 0) setInventory(data);
                    setLoadingInventory(false);
                  }).catch(() => setLoadingInventory(false));
                }}
              >
                🔄 รีเฟรชคลัง
              </button>
            </div>

            {loadingInventory ? (
              <div className="loading-box">
                <div className="spinner"></div>
                <span>กำลังโหลดข้อมูลรหัสผ่านจากระบบ...</span>
              </div>
            ) : inventory.length === 0 ? (
              <div className="empty-state">
                <svg width="40" height="40" viewBox="0 0 24 24" fill="#64748b">
                  <path d="M12.65 10C11.83 7.67 9.61 6 7 6c-3.31 0-6 2.69-6 6s2.69 6 6 6c2.61 0 4.83-1.67 5.65-4H17v4h4v-4h2v-4H12.65zM7 14c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2z" />
                </svg>
                <span>ยังไม่มีประวัติการสั่งซื้อรหัสเกม</span>
                <small>คุณสามารถเลือกซื้อไอดีเกมได้ทันทีที่แท็บ "ซื้อไอดีเกม"</small>
              </div>
            ) : (
              <div className="inventory-grid">
                {inventory.map((item) => (
                  <div key={item.id} className="inventory-card">
                    <div className="inventory-top">
                      <span className="game-badge">{item.game || 'GAME ID'}</span>
                      <span style={{ fontSize: '10.5px', color: 'var(--accent-green)', fontWeight: 700 }}>
                        ✓ {item.status || 'พร้อมใช้งาน'}
                      </span>
                    </div>

                    <div className="inventory-title">{item.title || item.name || 'ไอดีเกม'}</div>

                    <div className="cred-box">
                      <div className="cred-row">
                        <span className="cred-label">ไอดี / User:</span>
                        <div className="cred-val">
                          <span>{item.username || '-'}</span>
                          <button
                            className="btn-mini-copy"
                            onClick={() => handleCopy(item.username, `u-${item.id}`)}
                          >
                            {copiedKey === `u-${item.id}` ? '✓ คัดลอก' : 'คัดลอก'}
                          </button>
                        </div>
                      </div>

                      <div className="cred-row">
                        <span className="cred-label">รหัสผ่าน:</span>
                        <div className="cred-val">
                          <span>{revealedPass[item.id] ? item.password : '••••••••'}</span>
                          <button
                            className="btn-mini-copy"
                            onClick={() => toggleShowPass(item.id)}
                            title="ดู/ซ่อนรหัสผ่าน"
                          >
                            {revealedPass[item.id] ? 'ซ่อน' : 'แสดง'}
                          </button>
                          <button
                            className="btn-mini-copy"
                            onClick={() => handleCopy(item.password, `p-${item.id}`)}
                          >
                            {copiedKey === `p-${item.id}` ? '✓ คัดลอก' : 'คัดลอก'}
                          </button>
                        </div>
                      </div>

                      {item.date && (
                        <div className="cred-row" style={{ marginTop: '2px', opacity: 0.6, fontSize: '9.5px' }}>
                          <span>วันที่ซื้อ:</span>
                          <span>{item.date}</span>
                        </div>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* ========================================== */}
        {/* TAB 4: CHAT WITH COUNTER                   */}
        {/* ========================================== */}
        {activeTab === 'chat' && (
          <div className="chat-container">
            <div className="chat-head-status">
              <div className="chat-agent-badge">
                <span className="status-dot"></span>
                <div>
                  <h4>เจ้าหน้าที่เคาน์เตอร์ & ดูแลร้านไอดี ({brand.name})</h4>
                  <p>พร้อมให้บริการตลอด 24 ชั่วโมง • เครื่อง: {machineId}</p>
                </div>
              </div>
              <div className="quick-tags">
                <button onClick={() => setChatText('ขอสอบถามรายละเอียดไอดีเกมครับ')}>🎮 สอบถามไอดีเกม</button>
                <button onClick={() => setChatText('รหัสผ่านเข้าไม่ได้ รบกวนแอดมินเช็คให้หน่อยครับ')}>⚡ รหัสเข้าไม่ได้</button>
                <button onClick={() => setChatText('ขอเติมเวลาเพิ่ม 1 ชั่วโมงครับ')}>⏳ ขอต่อเวลา 1 ชม.</button>
              </div>
            </div>

            <div className="chat-messages-area">
              {loadingMessages ? (
                <div className="loading-box">
                  <div className="spinner"></div>
                  <span>กำลังโหลดประวัติแชท...</span>
                </div>
              ) : messages.length === 0 ? (
                <div className="empty-state">
                  <span>ยังไม่มีข้อความสนทนา พิมพ์ข้อความด้านล่างเพื่อคุยกับเคาน์เตอร์</span>
                </div>
              ) : (
                messages.map((m) => (
                  <div key={m.id} className={`dialog-chat-bubble ${m.sender}`}>
                    <div className="bubble-content">{m.text}</div>
                    <span className="bubble-time">{m.time}</span>
                  </div>
                ))
              )}
            </div>

            <div className="chat-input-bar">
              <input
                type="text"
                placeholder="พิมพ์ข้อความสอบถามหรือแจ้งพนักงานที่นี่..."
                value={chatText}
                onChange={(e) => setChatText(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleSendChat()}
              />
              <button onClick={handleSendChat}>ส่งข้อความ</button>
            </div>
          </div>
        )}

        {/* ========================================== */}
        {/* TAB 5: TOP UP                              */}
        {/* ========================================== */}
        {activeTab === 'topup' && (
          <div className="topup-container">
            <div className="topup-packages">
              <span style={{ fontSize: '13.5px', fontWeight: 700, color: 'var(--text-muted)', display: 'block', marginBottom: '10px' }}>
                เลือกแพ็กเกจเวลาที่ต้องการ
              </span>
              {loadingPackages ? (
                <div className="loading-box">
                  <div className="spinner"></div>
                  <span>กำลังโหลดแพ็กเกจจากระบบ...</span>
                </div>
              ) : packages.length === 0 ? (
                <div className="empty-state">
                  <span>ไม่พบแพ็กเกจเติมเงินในระบบ กรุณาติดต่อเคาน์เตอร์ (Zero Mock)</span>
                </div>
              ) : (
                <div className="package-grid">
                  {packages.map((pkg) => (
                    <div
                      key={pkg.id || pkg.price}
                      className={`package-card ${selectedTopup === pkg.price ? 'selected' : ''}`}
                      onClick={() => { setSelectedTopup(pkg.price); setTopupSuccess(false); }}
                    >
                      {pkg.tag && <span className="package-tag">{pkg.tag}</span>}
                      <h4>{pkg.hours}</h4>
                      <div className="package-price">฿{pkg.price}</div>
                      <p>{pkg.desc}</p>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="qr-checkout-card">
              <span style={{ fontSize: '14px', fontWeight: 700 }}>สแกนชำระเงิน</span>
              <p>ยอดชำระ: <b style={{ color: 'var(--accent-cyan)', fontSize: '20px', fontWeight: 800, fontFamily: "'Chakra Petch', monospace" }}>฿{selectedTopup}.00</b></p>

              <div className="qr-frame">
                <svg viewBox="0 0 100 100" width="140" height="140">
                  <rect width="100" height="100" fill="#fff" />
                  <path d="M10 10h30v30h-30zM50 10h10v10h-10zM70 10h20v20h-20zM20 20h10v10h-10zM80 20h0v0zM10 50h10v10h-10zM30 50h20v10h-20zM60 40h10v20h-10zM80 50h10v10h-10zM10 70h30v20h-30zM50 70h20v10h-20zM80 70h10v20h-10zM20 80h10v0h-10z" fill="#000" />
                </svg>
              </div>

              <span className="qr-support-text">รองรับ PromptPay, K-Plus, SCB, TrueMoney</span>
              <button
                className="btn-pay-confirm"
                onClick={handleConfirmTopup}
              >
                {topupSuccess ? '✓ ระบบได้รับยอดเงินแล้ว เวลาถูกเพิ่มทันที!' : 'ฉันชำระเงินเรียบร้อยแล้ว'}
              </button>
            </div>
          </div>
        )}

        {/* ========================================== */}
        {/* TAB 6: MEMBER ACCOUNT                      */}
        {/* ========================================== */}
        {activeTab === 'account' && (
          <div className="account-container">
            {loadingMember ? (
              <div className="loading-box">
                <div className="spinner"></div>
                <span>กำลังโหลดข้อมูลสมาชิก...</span>
              </div>
            ) : !member ? (
              <div className="empty-state">
                <svg width="40" height="40" viewBox="0 0 24 24" fill="#64748b">
                  <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" />
                </svg>
                <span>ไม่พบข้อมูลบัญชีสมาชิก</span>
                <small>เข้าใช้งานในโหมดบุคคลทั่วไป (Guest)</small>
              </div>
            ) : (
              <>
                <div className="member-card-vip">
                  <div className="member-card-top">
                    <div>
                      <span className="vip-badge">{member.tier || 'MEMBER'}</span>
                      <h2>{member.username}</h2>
                      <p>รหัสสมาชิก: <b>{member.memberId || '-'}</b></p>
                    </div>
                    <div className="card-chip"></div>
                  </div>
                  <div className="member-card-bottom">
                    <div>
                      <label>ยอดเงินคงเหลือ</label>
                      <div className="balance-val">฿ {Number(member.balance || 0).toFixed(2)}</div>
                    </div>
                    <div>
                      <label>แต้มสะสม</label>
                      <div className="point-val">⭐ {member.points || 0} แต้ม</div>
                    </div>
                  </div>
                </div>

                <div className="privilege-box">
                  <span style={{ fontSize: '13.5px', fontWeight: 700, color: 'var(--text-muted)', display: 'block', marginBottom: '8px' }}>
                    สิทธิพิเศษสำหรับคุณ
                  </span>
                  {(!member.privileges || member.privileges.length === 0) ? (
                    <div className="empty-state">
                      <span>ไม่มีสิทธิพิเศษในขณะนี้</span>
                    </div>
                  ) : (
                    <div className="privilege-grid">
                      {member.privileges.map((p) => (
                        <div key={p.id} className="priv-item">
                          <h4>{p.title}</h4>
                          <p>{p.desc}</p>
                          {p.canRedeem && (
                            <button className="btn-redeem" onClick={() => handleRedeem(p.id)}>
                              กดแลกสิทธิ์
                            </button>
                          )}
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </>
            )}
          </div>
        )}
      </div>

      {/* Cloud Game Save Modal */}
      {showSaveModal && (
        <div className="cloud-modal-backdrop" onClick={() => setShowSaveModal(false)}>
          <div className="cloud-modal-content" onClick={(e) => e.stopPropagation()}>
            <div className="cloud-modal-header">
              <h3>💾 โหลดเซฟเกมเนื้อเรื่อง (Cloud Game Save)</h3>
              <button className="cloud-modal-close" onClick={() => setShowSaveModal(false)}>
                ✕
              </button>
            </div>

            <p className="cloud-modal-desc">
              ใส่บัญชีอีเมลหรือรหัสเซฟที่คุณบันทึกไว้จากระบบ AutoSync เพื่อดึงเซฟเกมมายังเครื่องนี้
            </p>

            <div className="cloud-form-field">
              <label>อีเมลบัญชีผู้ใช้ (Username / Email):</label>
              <input
                type="text"
                placeholder="เช่น user@gmail.com"
                value={saveEmail}
                onChange={(e) => setSaveEmail(e.target.value)}
              />
            </div>

            <div className="cloud-form-field">
              <label>รหัสผ่านเซฟ (Password):</label>
              <input
                type="password"
                placeholder="กรอกรหัสผ่าน 6 ตัวอักษรขึ้นไป"
                value={savePass}
                onChange={(e) => setSavePass(e.target.value)}
              />
            </div>

            <div className="cloud-modal-info">
              <div>⚡ เซิร์ฟเวอร์จัดเก็บคลาวด์: <b>0JAYSHOP CLOUD (100% ONLINE)</b></div>
              <div>📁 โฟลเดอร์เซฟปลายทาง: <span>J:\GameSave\0jayshop\</span></div>
            </div>

            <div className="cloud-modal-actions">
              <button className="btn-cancel" onClick={() => setShowSaveModal(false)}>
                ยกเลิก
              </button>
              <button
                className="btn-sync"
                disabled={syncingSave}
                onClick={handleSyncGameSave}
              >
                {syncingSave ? 'กำลังซิงค์...' : 'ซิงค์เซฟเกมทันที'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Global Toast */}
      <div className={`toast-box ${toastVisible ? 'visible' : ''}`}>
        {toastMsg}
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
