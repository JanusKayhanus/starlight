import { C, iconFrame, star, sparkle, rays, squircle } from './lib.mjs';

// A translucent glass solid: soft cast shadow, tinted body, frosted backdrop,
// inner edge glow, specular top highlight and a lit rim.
function glass(id, d, { stops, opacity = 1, shadow = '#8a5a12', shadowOp = 0.35, backdrop = '', hiOp = 0.85, rimOp = 0.9, dy = 16, blurBack = 'b24', edge = '#fff', inner = 'innerGlow' }) {
  return {
    defs: `
    <clipPath id="${id}C"><path d="${d}" clip-rule="evenodd"/></clipPath>
    <linearGradient id="${id}F" x1="0.2" y1="0" x2="0.8" y2="1">${stops.map(([o, c, a = 1]) => `<stop offset="${o}" stop-color="${c}" stop-opacity="${a}"/>`).join('')}</linearGradient>
    <linearGradient id="${id}H" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity="${hiOp}"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
    <linearGradient id="${id}R" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff" stop-opacity="${rimOp}"/><stop offset=".45" stop-color="#fff" stop-opacity=".1"/><stop offset="1" stop-color="#fff" stop-opacity="${rimOp * 0.6}"/></linearGradient>`,
    body: `
    <path d="${d}" fill="${shadow}" fill-rule="evenodd" opacity="${shadowOp}" transform="translate(0 ${dy})" filter="url(#b24)"/>
    ${backdrop ? `<g clip-path="url(#${id}C)"><g filter="url(#${blurBack})">${backdrop}</g></g>` : ''}
    <path d="${d}" fill="url(#${id}F)" fill-rule="evenodd" opacity="${opacity}" filter="url(#${inner})"/>
    <g clip-path="url(#${id}C)">
      <ellipse cx="${C}" cy="250" rx="420" ry="260" fill="url(#${id}H)" opacity=".55"/>
      <path d="${d}" fill="none" stroke="${edge}" stroke-opacity=".55" stroke-width="14" transform="translate(0 -6)" filter="url(#b4)"/>
    </g>
    <path d="${d}" fill="none" stroke="url(#${id}R)" stroke-width="5" clip-path="url(#${id}C)"/>`,
  };
}

const rayGrad = (id, color, op = 0.7, cx = C, cy = C, r = 420) =>
  `<radialGradient id="${id}" gradientUnits="userSpaceOnUse" cx="${cx}" cy="${cy}" r="${r}">
     <stop offset="0" stop-color="${color}" stop-opacity="${op}"/><stop offset=".55" stop-color="${color}" stop-opacity="${op * 0.35}"/><stop offset="1" stop-color="${color}" stop-opacity="0"/></radialGradient>`;
const glow = (id, color, op = 1) =>
  `<radialGradient id="${id}"><stop offset="0" stop-color="${color}" stop-opacity="${op}"/><stop offset=".45" stop-color="${color}" stop-opacity="${op * 0.4}"/><stop offset="1" stop-color="${color}" stop-opacity="0"/></radialGradient>`;

// Orbit's midnight background: deep indigo gradient with a scatter of tiny stars.
const midnightDefs = `<linearGradient id="bg" x1="0" y1="0" x2="0.3" y2="1"><stop offset="0" stop-color="#34305A"/><stop offset="1" stop-color="#0F1128"/></linearGradient>`;
const midnightSky = (stars = [[210, 230, 3], [250, 820, 2.4], [840, 250, 2.8], [770, 170, 1.8], [180, 610, 2], [880, 560, 1.6], [640, 860, 2.2], [380, 160, 1.6]]) =>
  `<rect width="1024" height="1024" fill="url(#bg)"/>` +
  stars.map(([x, y, r]) => `<circle cx="${x}" cy="${y}" r="${r}" fill="#FFF3D0" opacity=".85"/>`).join('');

// 1 — Radiance: a plump golden glass star over a frosted halo-star, sun-rays fanning out behind.
export function radiance() {
  const cy = 528, d = star(C, cy, 262, 134, 34);
  const back = star(C, cy, 330, 168, 44, 5, -54);
  const burst = rays(C, cy, 32, 430, 330, 4.2, 2.6, -90);
  const g1 = glass('s', d, {
    stops: [[0, '#FFF4C9'], [0.4, '#F8CF67'], [1, '#D88F22']],
    backdrop: `<path d="${burst}" fill="#fff"/>`, shadow: '#9a5e0c', shadowOp: 0.45, edge: '#FFF6D8',
  });
  const g0 = glass('h', back, {
    stops: [[0, '#FFFFFF', 0.55], [0.5, '#FBE4AE', 0.4], [1, '#F0BD5E', 0.55]],
    backdrop: `<rect width="1024" height="1024" fill="#F8E6BE"/><path d="${burst}" fill="#E9A631"/>`, blurBack: 'b10',
    shadow: '#a86c14', shadowOp: 0.2, inner: 'innerGlowSoft',
  });
  return iconFrame({
    defs: g1.defs + g0.defs + rayGrad('rg', '#E9A631', 0.95, C, cy, 440) + glow('halo', '#FFF2C4') + `
      <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFBF1"/><stop offset=".6" stop-color="#F9EACB"/><stop offset="1" stop-color="#F0D6A4"/></linearGradient>
      <radialGradient id="spec" cx=".38" cy=".3" r=".35"><stop offset="0" stop-color="#fff" stop-opacity=".85"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>`,
    bg: `<rect width="1024" height="1024" fill="url(#bg)"/>`,
    content: `
      <circle cx="${C}" cy="${cy}" r="430" fill="url(#halo)"/>
      <path d="${burst}" fill="url(#rg)" filter="url(#b4)"/>
      ${g0.body}
      ${g1.body}
      <path d="${d}" fill="url(#spec)"/>`,
  });
}

// 2 — Twin Stars: a solid gold sparkle behind a frosted-glass sparkle (Screen Sharing-style overlap).
export function twin() {
  const backD = sparkle(415, 415, 255, 255, 0.2);
  const frontD = sparkle(615, 615, 245, 245, 0.2);
  const backFill = `<path d="${backD}" fill="url(#gold)"/>`;
  const front = glass('f', frontD, {
    stops: [[0, '#FFFFFF', 0.42], [0.5, '#FFF4D6', 0.18], [1, '#F2D290', 0.32]],
    backdrop: `<rect width="1024" height="1024" fill="url(#bg)"/>${backFill}<circle cx="415" cy="415" r="120" fill="#FFF6D6"/>`,
    blurBack: 'b24', shadow: '#6e4a0c', shadowOp: 0.38, hiOp: 0.95, rimOp: 1,
  });
  return iconFrame({
    defs: front.defs + rayGrad('rg', '#FFFFFF', 0.9, 415, 415, 380) + glow('halo', '#FFF6D6', 0.95) + glow('core', '#FFFFFF', 1) + `
      <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FAEDCF"/><stop offset=".55" stop-color="#F0D396"/><stop offset="1" stop-color="#DDAE62"/></linearGradient>
      <linearGradient id="gold" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFF0BA"/><stop offset=".5" stop-color="#F2BC4C"/><stop offset="1" stop-color="#C47E1C"/></linearGradient>`,
    bg: `<rect width="1024" height="1024" fill="url(#bg)"/>`,
    content: `
      <circle cx="415" cy="415" r="340" fill="url(#halo)"/>
      <path d="${rays(415, 415, 16, 380, 260, 7, 4, -90)}" fill="url(#rg)" filter="url(#b10)"/>
      <path d="${backD}" fill="#8a5a12" opacity=".32" transform="translate(0 16)" filter="url(#b24)"/>
      <path d="${backD}" fill="url(#gold)" filter="url(#innerGlow)"/>
      <circle cx="415" cy="415" r="110" fill="url(#core)" opacity=".9"/>
      ${front.body}`,
  });
}

// 3 — Orbit: a golden glass star wrapped by a translucent ring of light, on a midnight sky.
export function orbit() {
  const cy = 512, d = sparkle(C, cy, 250, 250, 0.2);
  const tilt = -22, rx = 390, ry = 128, t = 62;
  const ring = `M${C - rx},${cy} a${rx},${ry} 0 1,0 ${2 * rx},0 a${rx},${ry} 0 1,0 ${-2 * rx},0Z` +
    `M${C - rx + t},${cy} a${rx - t},${ry - t * 0.6} 0 1,0 ${2 * (rx - t)},0 a${rx - t},${ry - t * 0.6} 0 1,0 ${-2 * (rx - t)},0Z`;
  const starFill = `<path d="${d}" fill="url(#sF)"/>`;
  const s = glass('s', d, { stops: [[0, '#FFF6D2'], [0.45, '#F6C85E'], [1, '#C98320']], shadow: '#000', shadowOp: 0.5, edge: '#FFF2C8' });
  const ringFront = glass('rf', ring, {
    stops: [[0, '#FFF6DC', 0.85], [0.5, '#F8D17C', 0.7], [1, '#D99634', 0.85]],
    backdrop: `<g transform="rotate(${-tilt} ${C} ${cy})">${starFill}</g>`, blurBack: 'b10', shadow: '#000', shadowOp: 0.3, dy: 10,
  });
  const ringBack = glass('rb', ring, { stops: [[0, '#FFF6DC', 0.85], [0.5, '#F8D17C', 0.7], [1, '#D99634', 0.85]], shadow: '#000', shadowOp: 0.3, dy: 10 });
  return iconFrame({
    rim: 0.45, sheen: 0.14,
    defs: s.defs + ringFront.defs + ringBack.defs + `<radialGradient id="spec" cx=".4" cy=".32" r=".32"><stop offset="0" stop-color="#fff" stop-opacity=".9"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>` + glow('core', '#FFD983', 0.8) + rayGrad('rg', '#FFD77A', 0.85, C, cy, 420) + `
      ${midnightDefs}
      <linearGradient id="ringBack" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#E9AE48" stop-opacity=".85"/><stop offset=".5" stop-color="#A9721F" stop-opacity=".75"/><stop offset="1" stop-color="#E9AE48" stop-opacity=".85"/></linearGradient>
      <clipPath id="frontHalf"><rect x="0" y="${cy}" width="1024" height="600"/></clipPath>
      <clipPath id="backHalf"><rect x="0" y="0" width="1024" height="${cy}"/></clipPath>`,
    bg: midnightSky(),
    content: `
      <circle cx="${C}" cy="${cy}" r="400" fill="url(#core)" opacity=".55"/>
      <path d="${rays(C, cy, 16, 400, 290, 4, 2.4, -90)}" fill="url(#rg)" filter="url(#b4)"/>
      <g transform="rotate(${tilt} ${C} ${cy})">${ringBack.body}</g>
      ${s.body}
      <path d="${d}" fill="url(#spec)"/>
      <g transform="rotate(${tilt} ${C} ${cy})"><g clip-path="url(#frontHalf)">${ringFront.body}</g></g>`,
  });
}

// 4 — Flare: tall sparkle with an anamorphic streak and overlapping translucent glass discs.
export function flare({ night = false } = {}) {
  const cy = 500, main = sparkle(C, cy, 200, 300, 0.13);
  const g = glass('m', main, { stops: [[0, '#FFFDF4'], [0.4, '#FFE7A4'], [1, '#E7A83C']], hiOp: 0.95,
    ...(night ? { shadow: '#000', shadowOp: 0.5, edge: '#FFF2C8' } : { shadowOp: 0.3 }) });
  const disc = (id, cx, cyy, r, a, b) => `
    <radialGradient id="${id}" cx=".35" cy=".3" r=".8"><stop offset="0" stop-color="${a}" stop-opacity=".6"/><stop offset="1" stop-color="${b}" stop-opacity=".55"/></radialGradient>`;
  // On the night sky the discs become lit bokeh: a faint gold body brightening toward a glowing rim.
  const discUse = night
    ? (id, cx, cyy, r) => `
    <circle cx="${cx}" cy="${cyy}" r="${r}" fill="url(#bokeh)"/>
    <circle cx="${cx}" cy="${cyy}" r="${r - 3}" fill="none" stroke="#FFD27A" stroke-opacity=".55" stroke-width="8" filter="url(#b4)"/>
    <circle cx="${cx}" cy="${cyy}" r="${r - 2}" fill="none" stroke="url(#discRim)" stroke-width="3"/>`
    : (id, cx, cyy, r) => `
    <circle cx="${cx}" cy="${cyy + 10}" r="${r}" fill="#9a640f" opacity=".12" filter="url(#b24)"/>
    <circle cx="${cx}" cy="${cyy}" r="${r}" fill="url(#${id})" filter="url(#innerGlow)"/>
    <circle cx="${cx}" cy="${cyy}" r="${r - 2}" fill="none" stroke="url(#discRim)" stroke-width="4"/>`;
  return iconFrame({
    ...(night ? { rim: 0.45, sheen: 0.14 } : {}),
    defs: g.defs + (night ? glow('core', '#FFD983', 0.5) + glow('core2', '#FFF6D6', 0.9) : glow('core', '#FFF6D6')) + (night
      ? `<radialGradient id="bokeh"><stop offset="0" stop-color="#FFD983" stop-opacity=".1"/><stop offset=".75" stop-color="#FFD27A" stop-opacity=".2"/><stop offset="1" stop-color="#FFE3A6" stop-opacity=".42"/></radialGradient>`
      : disc('d1', 0, 0, 0, '#FFE3A0', '#E39A2E') + disc('d2', 0, 0, 0, '#FFF0C8', '#EDAE45') + disc('d3', 0, 0, 0, '#FFE9B4', '#E8A23A')) + `
      <linearGradient id="discRim" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".95"/><stop offset=".5" stop-color="#fff" stop-opacity=".1"/><stop offset="1" stop-color="#fff" stop-opacity=".6"/></linearGradient>
      ${night ? midnightDefs : `<linearGradient id="bg" x1="0" y1="0" x2="0.4" y2="1"><stop offset="0" stop-color="#FFF8E9"/><stop offset=".7" stop-color="#F5E0B4"/><stop offset="1" stop-color="#EBC88C"/></linearGradient>`}
      <linearGradient id="streak" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset=".5" stop-color="#fff"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>`,
    bg: night ? midnightSky([[200, 220, 3], [840, 240, 2.6], [160, 560, 2], [880, 520, 1.8], [620, 880, 2.2], [400, 150, 1.6], [860, 860, 2]]) : `<rect width="1024" height="1024" fill="url(#bg)"/>`,
    content: `
      ${night ? '' : discUse('d1', 350, 700, 140) + discUse('d2', 480, 760, 95) + discUse('d3', 700, 320, 90)}
      <circle cx="${C}" cy="${cy}" r="${night ? 360 : 330}" fill="url(#core)"/>
      ${night ? discUse('d1', 350, 700, 140) + discUse('d2', 480, 760, 95) + discUse('d3', 700, 320, 90) : ''}
      ${night ? `<circle cx="${C}" cy="${cy}" r="170" fill="url(#core2)"/>` : ''}
      <path d="${sparkle(C, cy, 140, 140, 0.18)}" transform="rotate(45 ${C} ${cy})" fill="#F0B94C" opacity=".6" filter="url(#b4)"/>
      ${g.body}
      <rect x="130" y="${cy - 6}" width="764" height="12" rx="6" fill="url(#streak)" filter="url(#b4)"/>
      <rect x="230" y="${cy - 2}" width="564" height="4" rx="2" fill="url(#streak)"/>
      <circle cx="${C}" cy="${cy}" r="46" fill="#fff" filter="url(#b10)"/>
      <path d="${sparkle(740, 715, 52, 70, 0.16)}" fill="${night ? '#FFF3D0' : '#fff'}" opacity=".95" filter="url(#innerGlow)"/>
      <path d="${sparkle(290, 285, 32, 44, 0.16)}" fill="${night ? '#FFF3D0' : '#fff'}" opacity=".85"/>`,
  });
}

// 5 — Layers: three stacked translucent stars receding in depth (Tahoe "liquid glass").
export function layers() {
  const cy = 525;
  const d3 = star(C + 84, cy - 84, 232, 118, 30), d2 = star(C + 38, cy - 38, 250, 128, 32), d1 = star(C - 12, cy + 12, 266, 136, 34);
  const burst = rays(C + 84, cy - 84, 24, 520, 380, 6, 3.5, -90);
  const g3 = glass('l3', d3, { stops: [[0, '#F4BC4E', 1], [1, '#A9620E', 1]], shadowOp: 0.3, hiOp: 0.45, inner: 'innerGlowSoft', edge: '#FFD98A' });
  const g2 = glass('l2', d2, { stops: [[0, '#FFDB85', 0.85], [1, '#D38A22', 0.85]], shadowOp: 0.3, hiOp: 0.6, inner: 'innerGlowSoft', edge: '#FFE7B0',
    backdrop: `<path d="${d3}" fill="#D99634"/>` });
  const g1 = glass('l1', d1, { stops: [[0, '#FFFBEE', 0.7], [0.55, '#FBE3A6', 0.45], [1, '#F0BC56', 0.6]], shadowOp: 0.3, hiOp: 0.95, rimOp: 1,
    backdrop: `<path d="${burst}" fill="#fff" opacity=".5"/><path d="${d3}" fill="#D99634"/><path d="${d2}" fill="#EDB651"/>` });
  return iconFrame({
    defs: g1.defs + g2.defs + g3.defs + rayGrad('rg', '#FFF8E0', 0.9, C + 84, cy - 84, 520) + `
      <radialGradient id="bg" cx=".65" cy=".3" r=".9"><stop offset="0" stop-color="#FDF0CF"/><stop offset=".55" stop-color="#F0CD8C"/><stop offset="1" stop-color="#D49B4A"/></radialGradient>`,
    bg: `<rect width="1024" height="1024" fill="url(#bg)"/>`,
    content: `
      <path d="${burst}" fill="url(#rg)" filter="url(#b4)"/>
      ${g3.body}${g2.body}${g1.body}`,
  });
}

// 4b — Flare Night: Flare on Orbit's midnight sky.
export const flareNight = () => flare({ night: true });

export const all = { radiance, twin, orbit, flare, flareNight, layers };
