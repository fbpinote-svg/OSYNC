// Line icons for the game menu (17 Nov: no emoji anywhere - the owner's choice). 24x24 grid, stroke = currentColor,
// so a button's text colour is the icon colour. <Icon name="play" fill /> = a filled shape instead of a line.
const P = {
  grid: 'M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z',
  globe: 'M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18zM3.5 9h17M3.5 15h17M12 3c2.4 2.6 3.6 5.6 3.6 9s-1.2 6.4-3.6 9c-2.4-2.6-3.6-5.6-3.6-9s1.2-6.4 3.6-9z',
  sparkles: 'M11 3l1.9 5.1L18 10l-5.1 1.9L11 17l-1.9-5.1L4 10l5.1-1.9zM18.5 14.5l.9 2.1 2.1.9-2.1.9-.9 2.1-.9-2.1-2.1-.9 2.1-.9z',
  gem: 'M7 4h10l4 5-9 11L3 9zM3 9h18M10 4l2 16 2-16',
  apps: 'M5 4h4a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1zM15 4h4a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1h-4a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1zM5 14h4a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-4a1 1 0 0 1 1-1zM15 14h4a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1h-4a1 1 0 0 1-1-1v-4a1 1 0 0 1 1-1z',
  rocket: 'M14 4.5c2.2-1.4 4.6-1.6 6-1.5.1 1.4-.1 3.8-1.5 6L13 14.5 9.5 11zM9.5 11L6 10.5l-2 2 4 1.5M13 14.5l.5 3.5-2 2-1.5-4M6.5 17.5C5 19 4.5 20 4 20c0-.5 1-1.5 2.5-3M15.5 8.5h.01',
  gamepad: 'M7 8h10a4.5 4.5 0 0 1 4.4 5.5l-.6 2.6a2.5 2.5 0 0 1-4.3 1.1L14.5 15h-5l-2 2.2a2.5 2.5 0 0 1-4.3-1.1l-.6-2.6A4.5 4.5 0 0 1 7 8zM8 10.5v3M6.5 12h3M15.5 11h.01M17.5 13h.01',
  book: 'M5 4.5A1.5 1.5 0 0 1 6.5 3H19v15H6.5A1.5 1.5 0 0 0 5 19.5zM5 19.5A1.5 1.5 0 0 0 6.5 21H19',
  phone: 'M8 3h8a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM11 18h2',
  shuffle: 'M16 4h4v4M20 4l-6.5 6.5M4 20l6-6M16 20h4v-4M20 20L4 4',
  refresh: 'M20 12a8 8 0 1 1-2.3-5.7M20 4v5h-5',
  x: 'M6 6l12 12M18 6L6 18',
  play: 'M8 5.5v13a.6.6 0 0 0 .9.5l10.4-6.5a.6.6 0 0 0 0-1L8.9 5a.6.6 0 0 0-.9.5z',
  folder: 'M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z',
  copy: 'M9 9h10a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1V10a1 1 0 0 1 1-1zM5 15H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v1',
  star: 'M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.3-4.1 5.9-.9z',
  megaphone: 'M4 10v4a1 1 0 0 0 1 1h2l6 4V5L7 9H5a1 1 0 0 0-1 1zM17 9a4.5 4.5 0 0 1 0 6',
  bolt: 'M13.5 2.5L5 13.5h6l-1 8 8.5-11h-6z',
  sliders: 'M4 7h9M17 7h3M4 12h3M11 12h9M4 17h11M19 17h1M15 5v4M9 10v4M17 15v4',
  diamond: 'M12 3l8 9-8 9-8-9zM8 12h8',
  aperture: 'M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18zM14.3 3.3L9 12.5M20.6 9.5H10.2M18.4 18.2L13 9M9.7 20.7L15 11.5M3.4 14.5h10.4M5.6 5.8l5.4 9.2',
  road: 'M9 3L5.5 21M15 3l3.5 18M12 5v2.5M12 10.5V13M12 16v2.5',
  monitor: 'M4 4h16a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1zM8.5 20h7M12 16v4',
  chip: 'M8 7h8a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1zM10 3v4M14 3v4M10 17v4M14 17v4M3 10h4M3 14h4M17 10h4M17 14h4',
  check: 'M5 12.5l4.5 4.5L19 7.5',
  chevron: 'M9.5 6l6 6-6 6',
  trash: 'M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3',
  download: 'M12 4v11M7.5 10.5L12 15l4.5-4.5M5 19.5h14',
  scan: 'M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3M7 12h10',
};

export default function Icon({ name, size = 20, fill = false, className = '', style }) {
  return (
    <svg className={`ico${fill ? ' fill' : ''}${className ? ' ' + className : ''}`} viewBox="0 0 24 24" width={size} height={size}
      aria-hidden="true" style={style} fill={fill ? 'currentColor' : 'none'} stroke={fill ? 'none' : 'currentColor'}
      strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d={P[name] || P.gamepad} />
    </svg>
  );
}

// category button icon when this PC has no launcher icon for the category
export const CATEGORY_ICON = {
  Online: 'globe', 'Anime RPG': 'sparkles', Gacha: 'gem', HoYoPlay: 'sparkles', 'Single Player': 'book', Mobile: 'phone',
  Emulator: 'gamepad', Apps: 'apps', Launchers: 'rocket',
};
