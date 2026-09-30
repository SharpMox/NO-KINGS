/* ============================================================
 *  board.js
 *  Shared SVG board renderer for every NO-KINGS piece page.
 *  Exposes globals: N, SQ, SIZE, svgCenter, squareRect, describeMoves,
 *  renderBoard, renderMove.
 *
 *  Each page also drops its own renderCard / renderMiniCard / page-
 *  specific JS inline; only the board diagram primitives live here.
 * ============================================================ */
(function (global) {
  const N = 9;
  const SQ = 36;
  const SIZE = N * SQ;

  function svgCenter(x, y) {
    return { cx: (x + 4) * SQ + SQ / 2, cy: (4 - y) * SQ + SQ / 2 };
  }
  function squareRect(x, y) {
    return { sx: (x + 4) * SQ, sy: (4 - y) * SQ };
  }

  function describeMoves(piece) {
    const parts = [];
    for (const m of piece.moves) {
      if (m.kind === 'dots')   parts.push(`${m.squares.length} leap targets`);
      if (m.kind === 'rings')  parts.push(`${m.squares.length} move-only squares`);
      if (m.kind === 'xs')     parts.push(`${m.squares.length} capture-only squares`);
      if (m.kind === 'rays')   parts.push(`slides in ${m.dirs.length} directions`);
      if (m.kind === 'rider')  parts.push('rider continues past the diagram');
      if (m.kind === 'hop' || m.kind === 'capture-hop') parts.push('hops over a hurdle');
    }
    return `${piece.name}: ${parts.join('; ')}.`;
  }

  function renderBoard(piece) {
    let svg = `<svg viewBox="0 0 ${SIZE} ${SIZE}" class="board" role="img" aria-label="${piece.name} movement diagram">`;
    svg += `<title>${piece.name} — movement diagram</title>`;
    svg += `<desc>${describeMoves(piece)} ${piece.description}</desc>`;

    // Squares
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N; c++) {
        const isLight = (r + c) % 2 === 0;
        const fill = isLight ? 'var(--sq-light)' : 'var(--sq-dark)';
        svg += `<rect x="${c*SQ}" y="${r*SQ}" width="${SQ}" height="${SQ}" fill="${fill}"/>`;
      }
    }

    // Moves
    for (const move of piece.moves) {
      svg += renderMove(move);
    }

    // Piece glyph at centre (or piece_at if set)
    const piecePos = piece.piece_at || [0, 0];
    const { cx, cy } = svgCenter(piecePos[0], piecePos[1]);
    if (piece.glyph) {
      svg += `<text x="${cx}" y="${cy + SQ*0.04}" text-anchor="middle" dominant-baseline="central" font-size="${SQ*0.85}" fill="var(--text)" style="font-family: 'Apple Symbols','Segoe UI Symbol','Noto Sans Symbols 2',serif;">${piece.glyph}</text>`;
    } else {
      const r = SQ * 0.36;
      svg += `<circle cx="${cx}" cy="${cy}" r="${r}" fill="var(--piece-disc)"/>`;
      const len = (piece.letter || '?').length;
      // len>=3 → shrink (inversion's iKi++ etc.); len==2 → 0.30;
      // CJK single glyph (codepoint > 0x2E00) → slightly smaller; else 0.48.
      const fontSize = len >= 3 ? SQ*0.22
                     : len >= 2 ? SQ*0.30
                     : (piece.letter && piece.letter.charCodeAt(0) > 0x2E00 ? SQ*0.46 : SQ*0.48);
      svg += `<text x="${cx}" y="${cy + SQ*0.02}" text-anchor="middle" dominant-baseline="central" font-size="${fontSize}" font-weight="700" fill="var(--piece-disc-text)" style="font-family: 'Hiragino Sans','Noto Sans CJK JP',-apple-system,sans-serif;">${piece.letter || ''}</text>`;
    }
    svg += `</svg>`;
    return svg;
  }

  function renderMove(move) {
    switch (move.kind) {
      case 'dots':
        return move.squares.map(([x, y]) => {
          const { cx, cy } = svgCenter(x, y);
          return `<circle cx="${cx}" cy="${cy}" r="${SQ*0.22}" fill="var(--move-color)"/>`;
        }).join('');

      case 'rings':
        return move.squares.map(([x, y]) => {
          const { cx, cy } = svgCenter(x, y);
          return `<circle cx="${cx}" cy="${cy}" r="${SQ*0.22}" fill="none" stroke="var(--move-color)" stroke-width="2.5"/>`;
        }).join('');

      case 'xs':
        return move.squares.map(([x, y]) => {
          const { cx, cy } = svgCenter(x, y);
          const r = SQ * 0.22;
          return `<line x1="${cx-r}" y1="${cy-r}" x2="${cx+r}" y2="${cy+r}" stroke="var(--capture-color)" stroke-width="3" stroke-linecap="round"/>` +
                 `<line x1="${cx+r}" y1="${cy-r}" x2="${cx-r}" y2="${cy+r}" stroke="var(--capture-color)" stroke-width="3" stroke-linecap="round"/>`;
        }).join('');

      case 'rays': {
        const fromSq = move.from || [0, 0];
        const maxRange = move.maxRange || Infinity;
        return move.dirs.map(([dx, dy]) => {
          let lastX = fromSq[0], lastY = fromSq[1];
          let stepX = fromSq[0], stepY = fromSq[1];
          let steps = 0;
          while (steps < maxRange) {
            stepX += dx; stepY += dy;
            if (Math.abs(stepX) > 4 || Math.abs(stepY) > 4) break;
            lastX = stepX; lastY = stepY;
            steps++;
          }
          if (lastX === fromSq[0] && lastY === fromSq[1]) return '';
          const start = svgCenter(fromSq[0], fromSq[1]);
          const end   = svgCenter(lastX, lastY);
          const angle = Math.atan2(end.cy - start.cy, end.cx - start.cx);
          const lineStart = {
            x: start.cx + Math.cos(angle) * SQ * 0.42,
            y: start.cy + Math.sin(angle) * SQ * 0.42
          };
          const tip = { x: end.cx, y: end.cy };
          const arrowLen = SQ * 0.30;
          const arrowWidth = SQ * 0.16;
          const base = {
            x: tip.x - Math.cos(angle) * arrowLen,
            y: tip.y - Math.sin(angle) * arrowLen
          };
          const perp = { x: -Math.sin(angle) * arrowWidth, y: Math.cos(angle) * arrowWidth };
          return `<line x1="${lineStart.x}" y1="${lineStart.y}" x2="${base.x}" y2="${base.y}" stroke="var(--ray-color)" stroke-width="3.4" stroke-linecap="round"/>` +
                 `<polygon points="${tip.x},${tip.y} ${base.x+perp.x},${base.y+perp.y} ${base.x-perp.x},${base.y-perp.y}" fill="var(--ray-color)"/>`;
        }).join('');
      }

      case 'rider': {
        const start = svgCenter(0, 0);
        const points = [{ cx: start.cx, cy: start.cy }, ...move.dots.map(([x, y]) => svgCenter(x, y))];
        const pathD = `M ${points.map(p => `${p.cx} ${p.cy}`).join(' L ')}`;
        const line = `<path d="${pathD}" stroke="var(--rider-color)" stroke-width="1.4" stroke-dasharray="3 3" fill="none" opacity="0.65"/>`;
        const dots = move.dots.map(([x, y]) => {
          const { cx, cy } = svgCenter(x, y);
          return `<circle cx="${cx}" cy="${cy}" r="${SQ*0.18}" fill="var(--rider-color)"/>`;
        }).join('');
        const lastP = points[points.length - 1];
        const p2 = points[points.length - 2] || start;
        const dxx = lastP.cx - p2.cx;
        const dyy = lastP.cy - p2.cy;
        const len = Math.hypot(dxx, dyy) || 1;
        const dirX = dxx / len, dirY = dyy / len;
        const tipX = lastP.cx + dirX * SQ * 0.40;
        const tipY = lastP.cy + dirY * SQ * 0.40;
        let arrow = '';
        if (tipX >= 4 && tipX <= SIZE - 4 && tipY >= 4 && tipY <= SIZE - 4) {
          const arrowLen = SQ * 0.22;
          const arrowWidth = SQ * 0.13;
          const baseX = tipX - dirX * arrowLen;
          const baseY = tipY - dirY * arrowLen;
          const perpX = -dirY * arrowWidth;
          const perpY = dirX * arrowWidth;
          arrow = `<polygon points="${tipX},${tipY} ${baseX+perpX},${baseY+perpY} ${baseX-perpX},${baseY-perpY}" fill="var(--rider-color)" opacity="0.85"/>`;
        }
        return line + dots + arrow;
      }

      case 'hop': {
        const start = svgCenter(0, 0);
        const h = svgCenter(move.hurdle[0], move.hurdle[1]);
        const t = svgCenter(move.target[0], move.target[1]);
        const path = `<path d="M ${start.cx} ${start.cy} L ${h.cx} ${h.cy} L ${t.cx} ${t.cy}" stroke="var(--hop-target)" stroke-width="1.4" stroke-dasharray="3 3" fill="none" opacity="0.55"/>`;
        const { sx, sy } = squareRect(move.hurdle[0], move.hurdle[1]);
        const hurdleRect = `<rect x="${sx+3}" y="${sy+3}" width="${SQ-6}" height="${SQ-6}" fill="none" stroke="var(--hurdle-color)" stroke-width="2" stroke-dasharray="3 2"/>`;
        const r = SQ * 0.24;
        const target = `<polygon points="${t.cx},${t.cy-r} ${t.cx+r},${t.cy} ${t.cx},${t.cy+r} ${t.cx-r},${t.cy}" fill="var(--hop-target)"/>`;
        return path + hurdleRect + target;
      }

      case 'capture-hop': {
        const start = svgCenter(0, 0);
        const h = svgCenter(move.hurdle[0], move.hurdle[1]);
        const t = svgCenter(move.target[0], move.target[1]);
        const path = `<path d="M ${start.cx} ${start.cy} L ${h.cx} ${h.cy} L ${t.cx} ${t.cy}" stroke="var(--capture-color)" stroke-width="1.4" stroke-dasharray="3 3" fill="none" opacity="0.55"/>`;
        const { sx, sy } = squareRect(move.hurdle[0], move.hurdle[1]);
        const hurdleRect = `<rect x="${sx+3}" y="${sy+3}" width="${SQ-6}" height="${SQ-6}" fill="none" stroke="var(--hurdle-color)" stroke-width="2" stroke-dasharray="3 2"/>`;
        const r = SQ * 0.22;
        const xMark = `<line x1="${t.cx-r}" y1="${t.cy-r}" x2="${t.cx+r}" y2="${t.cy+r}" stroke="var(--capture-color)" stroke-width="3" stroke-linecap="round"/>` +
                      `<line x1="${t.cx+r}" y1="${t.cy-r}" x2="${t.cx-r}" y2="${t.cy+r}" stroke="var(--capture-color)" stroke-width="3" stroke-linecap="round"/>`;
        return path + hurdleRect + xMark;
      }

      case 'move-hop': {
        const start = svgCenter(0, 0);
        const h = svgCenter(move.hurdle[0], move.hurdle[1]);
        const t = svgCenter(move.target[0], move.target[1]);
        const path = `<path d="M ${start.cx} ${start.cy} L ${h.cx} ${h.cy} L ${t.cx} ${t.cy}" stroke="var(--hop-target)" stroke-width="1.4" stroke-dasharray="3 3" fill="none" opacity="0.55"/>`;
        const { sx, sy } = squareRect(move.hurdle[0], move.hurdle[1]);
        const hurdleRect = `<rect x="${sx+3}" y="${sy+3}" width="${SQ-6}" height="${SQ-6}" fill="none" stroke="var(--hurdle-color)" stroke-width="2" stroke-dasharray="3 2"/>`;
        const target = `<circle cx="${t.cx}" cy="${t.cy}" r="${SQ*0.22}" fill="none" stroke="var(--hop-target)" stroke-width="2.5"/>`;
        return path + hurdleRect + target;
      }

      case 'zigzag': {
        const start = svgCenter(0, 0);
        const pts = [start, ...move.points.map(([x, y]) => svgCenter(x, y))];
        const pathD = `M ${pts.map(p => `${p.cx} ${p.cy}`).join(' L ')}`;
        const line = `<path d="${pathD}" stroke="var(--rider-color)" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round" fill="none" opacity="0.75"/>`;
        const dots = move.points.map(([x, y]) => {
          const { cx, cy } = svgCenter(x, y);
          return `<circle cx="${cx}" cy="${cy}" r="${SQ*0.16}" fill="var(--rider-color)"/>`;
        }).join('');
        return line + dots;
      }

      case 'bent-rider': {
        const start = svgCenter(0, 0);
        const pivotC = svgCenter(move.pivot[0], move.pivot[1]);
        const [bdx, bdy] = move.dir;
        let lastX = move.pivot[0], lastY = move.pivot[1];
        while (true) {
          const nx = lastX + bdx, ny = lastY + bdy;
          if (Math.abs(nx) > 4 || Math.abs(ny) > 4) break;
          lastX = nx; lastY = ny;
        }
        const leapAngle = Math.atan2(pivotC.cy - start.cy, pivotC.cx - start.cx);
        const leapStart = {
          x: start.cx + Math.cos(leapAngle) * SQ * 0.42,
          y: start.cy + Math.sin(leapAngle) * SQ * 0.42
        };
        const leapLine = `<line x1="${leapStart.x}" y1="${leapStart.y}" x2="${pivotC.cx}" y2="${pivotC.cy}" stroke="var(--ray-color)" stroke-width="2.6" stroke-linecap="round" opacity="0.85"/>`;
        if (lastX === move.pivot[0] && lastY === move.pivot[1]) {
          const dot = `<circle cx="${pivotC.cx}" cy="${pivotC.cy}" r="${SQ*0.18}" fill="var(--ray-color)"/>`;
          return leapLine + dot;
        }
        const endC = svgCenter(lastX, lastY);
        const slideAngle = Math.atan2(endC.cy - pivotC.cy, endC.cx - pivotC.cx);
        const arrowLen = SQ * 0.28;
        const arrowWidth = SQ * 0.14;
        const tipX = endC.cx, tipY = endC.cy;
        const baseX = tipX - Math.cos(slideAngle) * arrowLen;
        const baseY = tipY - Math.sin(slideAngle) * arrowLen;
        const perpX = -Math.sin(slideAngle) * arrowWidth;
        const perpY =  Math.cos(slideAngle) * arrowWidth;
        const slideLine = `<line x1="${pivotC.cx}" y1="${pivotC.cy}" x2="${baseX}" y2="${baseY}" stroke="var(--ray-color)" stroke-width="2.8" stroke-linecap="round"/>`;
        const arrow = `<polygon points="${tipX},${tipY} ${baseX+perpX},${baseY+perpY} ${baseX-perpX},${baseY-perpY}" fill="var(--ray-color)"/>`;
        const pivotDot = `<circle cx="${pivotC.cx}" cy="${pivotC.cy}" r="${SQ*0.10}" fill="var(--ray-color)"/>`;
        return leapLine + pivotDot + slideLine + arrow;
      }

      case 'reflecting-ray': {
        const maxSteps = move.maxSteps || 10;
        const visited = [];
        let [px, py] = move.from;
        let [dx, dy] = move.dir;
        for (let i = 0; i < maxSteps; i++) {
          let nx = px + dx;
          let ny = py + dy;
          if (nx > 4 || nx < -4) { dx = -dx; nx = px + dx; }
          if (ny > 4 || ny < -4) { dy = -dy; ny = py + dy; }
          if (nx > 4 || nx < -4 || ny > 4 || ny < -4) break;
          visited.push([nx, ny]);
          px = nx; py = ny;
        }
        if (visited.length === 0) return '';
        const startC = svgCenter(move.from[0], move.from[1]);
        const points = [startC, ...visited.map(([x, y]) => svgCenter(x, y))];
        const pathD = `M ${points.map(p => `${p.cx} ${p.cy}`).join(' L ')}`;
        const line = `<path d="${pathD}" stroke="var(--ray-color)" stroke-width="2.6" stroke-linejoin="round" stroke-linecap="round" fill="none" opacity="0.85"/>`;
        const lastP = points[points.length - 1];
        const p2 = points[points.length - 2];
        const ddx = lastP.cx - p2.cx;
        const ddy = lastP.cy - p2.cy;
        const len = Math.hypot(ddx, ddy) || 1;
        const ux = ddx / len, uy = ddy / len;
        const arrowLen = SQ * 0.24;
        const arrowWidth = SQ * 0.14;
        const tipX = lastP.cx, tipY = lastP.cy;
        const baseX = tipX - ux * arrowLen;
        const baseY = tipY - uy * arrowLen;
        const perpX = -uy * arrowWidth;
        const perpY =  ux * arrowWidth;
        const arrow = `<polygon points="${tipX},${tipY} ${baseX+perpX},${baseY+perpY} ${baseX-perpX},${baseY-perpY}" fill="var(--ray-color)"/>`;
        return line + arrow;
      }

      default: return '';
    }
  }

  global.N = N;
  global.SQ = SQ;
  global.SIZE = SIZE;
  global.svgCenter = svgCenter;
  global.squareRect = squareRect;
  global.describeMoves = describeMoves;
  global.renderBoard = renderBoard;
  global.renderMove = renderMove;
})(typeof window !== 'undefined' ? window : globalThis);
