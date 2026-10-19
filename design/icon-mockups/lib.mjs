// Shared geometry helpers for the Starlight icon mockups.
export const C = 512; // canvas centre (1024 x 1024 macOS icon grid)

// macOS-style continuous-corner squircle: 824pt body inset 100pt from the canvas.
export function squircle(size = 824, cx = C, cy = C, n = 4.3) {
  const a = size / 2, pts = [];
  for (let i = 0; i < 360; i++) {
    const t = (i / 360) * Math.PI * 2, c = Math.cos(t), s = Math.sin(t);
    pts.push([cx + a * Math.sign(c) * Math.abs(c) ** (2 / n), cy + a * Math.sign(s) * Math.abs(s) ** (2 / n)]);
  }
  return 'M' + pts.map(p => p.map(v => v.toFixed(2)).join(',')).join('L') + 'Z';
}

// Polygon with softly rounded vertices.
export function rounded(points, r) {
  const n = points.length; let d = '';
  for (let i = 0; i < n; i++) {
    const p = points[i], a = points[(i - 1 + n) % n], b = points[(i + 1) % n];
    const ua = unit(a, p), ub = unit(b, p);
    const ra = Math.min(r, dist(a, p) / 2), rb = Math.min(r, dist(b, p) / 2);
    const p1 = [p[0] + ua[0] * ra, p[1] + ua[1] * ra], p2 = [p[0] + ub[0] * rb, p[1] + ub[1] * rb];
    d += (i ? 'L' : 'M') + f(p1) + 'Q' + f(p) + ' ' + f(p2);
  }
  return d + 'Z';
}
const unit = (a, p) => { const dx = a[0] - p[0], dy = a[1] - p[1], l = Math.hypot(dx, dy); return [dx / l, dy / l]; };
const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);
const f = p => p[0].toFixed(2) + ',' + p[1].toFixed(2);

export function starPoints(cx, cy, R, r, k = 5, rot = -90) {
  const pts = [];
  for (let i = 0; i < k * 2; i++) {
    const ang = ((rot + (i * 180) / k) * Math.PI) / 180, rad = i % 2 ? r : R;
    pts.push([cx + rad * Math.cos(ang), cy + rad * Math.sin(ang)]);
  }
  return pts;
}
export const star = (cx, cy, R, r, round = 18, k = 5, rot = -90) => rounded(starPoints(cx, cy, R, r, k, rot), round);

// Four-point "sparkle" star with concave sides. rx/ry are the arm lengths, w the waist.
export function sparkle(cx, cy, rx, ry = rx, w = 0.14) {
  const kx = rx * w, ky = ry * w;
  return `M${cx},${cy - ry} C${cx + kx * 0.6},${cy - ky * 1.6} ${cx + kx * 1.6},${cy - ky * 0.6} ${cx + rx},${cy}` +
    ` C${cx + kx * 1.6},${cy + ky * 0.6} ${cx + kx * 0.6},${cy + ky * 1.6} ${cx},${cy + ry}` +
    ` C${cx - kx * 0.6},${cy + ky * 1.6} ${cx - kx * 1.6},${cy + ky * 0.6} ${cx - rx},${cy}` +
    ` C${cx - kx * 1.6},${cy - ky * 0.6} ${cx - kx * 0.6},${cy - ky * 1.6} ${cx},${cy - ry}Z`;
}

// Thin tapered light rays radiating from a point.
export function rays(cx, cy, count, long, short, wLong, wShort, offset = 0) {
  let d = '';
  for (let i = 0; i < count; i++) {
    const ang = ((offset + (i * 360) / count) * Math.PI) / 180;
    const L = i % 2 ? short : long, w = ((i % 2 ? wShort : wLong) * Math.PI) / 180;
    const p1 = [cx + L * Math.cos(ang - w / 2), cy + L * Math.sin(ang - w / 2)];
    const tip = [cx + L * 1.04 * Math.cos(ang), cy + L * 1.04 * Math.sin(ang)];
    const p2 = [cx + L * Math.cos(ang + w / 2), cy + L * Math.sin(ang + w / 2)];
    d += `M${cx},${cy}L${f(p1)}Q${f(tip)} ${f(p2)}Z`;
  }
  return d;
}

// Filters reused by every concept.
export const commonDefs = `
  <filter id="iconShadow" x="-20%" y="-20%" width="140%" height="150%">
    <feGaussianBlur in="SourceAlpha" stdDeviation="14"/><feOffset dy="12"/>
    <feComponentTransfer><feFuncA type="linear" slope="0.28"/></feComponentTransfer>
    <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <filter id="innerGlow" x="-10%" y="-10%" width="120%" height="120%">
    <feFlood flood-color="#fff"/><feComposite in2="SourceAlpha" operator="out"/>
    <feGaussianBlur stdDeviation="10"/><feComposite in2="SourceAlpha" operator="in" result="g"/>
    <feComponentTransfer in="g" result="g2"><feFuncA type="linear" slope="0.9"/></feComponentTransfer>
    <feMerge><feMergeNode in="SourceGraphic"/><feMergeNode in="g2"/></feMerge>
  </filter>
  <filter id="innerGlowSoft" x="-10%" y="-10%" width="120%" height="120%">
    <feFlood flood-color="#fff"/><feComposite in2="SourceAlpha" operator="out"/>
    <feGaussianBlur stdDeviation="4"/><feComposite in2="SourceAlpha" operator="in" result="g"/>
    <feComponentTransfer in="g" result="g2"><feFuncA type="linear" slope="0.45"/></feComponentTransfer>
    <feMerge><feMergeNode in="SourceGraphic"/><feMergeNode in="g2"/></feMerge>
  </filter>
  <filter id="b4"><feGaussianBlur stdDeviation="4"/></filter>
  <filter id="b10" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="10"/></filter>
  <filter id="b24" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="24"/></filter>
  <filter id="b40" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="40"/></filter>
`;

// Squircle body with a glassy rim + top sheen, wrapping arbitrary content.
export function iconFrame({ bg, content, rim = 0.75, sheen = 0.35, defs = '' }) {
  const sq = squircle();
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
<defs>${commonDefs}${defs}
  <clipPath id="sq"><path d="${sq}"/></clipPath>
  <linearGradient id="rimG" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="${rim}"/><stop offset=".35" stop-color="#fff" stop-opacity="0"/>
    <stop offset=".7" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#fff" stop-opacity="${rim * 0.5}"/>
  </linearGradient>
  <linearGradient id="sheenG" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="${sheen}"/><stop offset=".5" stop-color="#fff" stop-opacity="0"/>
  </linearGradient>
</defs>
<g filter="url(#iconShadow)">
  <g clip-path="url(#sq)">
    ${bg}
    ${content}
    <rect x="100" y="100" width="824" height="824" fill="url(#sheenG)"/>
  </g>
  <path d="${sq}" fill="none" stroke="url(#rimG)" stroke-width="6" clip-path="url(#sq)"/>
  <path d="${sq}" fill="none" stroke="#000" stroke-opacity=".08" stroke-width="1.5"/>
</g>
</svg>`;
}
