import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';

// Integer-coordinate drawing primitives keep the exported pixels sharp at 2×.
class Canvas {
  constructor(width, height, left = 0, top = 0) {
    this.width = width;
    this.height = height;
    this.left = left;
    this.top = top;
    this.data = Buffer.alloc(width * height * 4);
  }

  pixel(x, y, color) {
    x -= this.left;
    y -= this.top;
    if (x < 0 || y < 0 || x >= this.width || y >= this.height) return;
    const channels = typeof color === 'string' ? hex(color) : color;
    this.data.set(channels, (y * this.width + x) * 4);
  }

  rect(x, y, width, height, color) {
    const channels = typeof color === 'string' ? hex(color) : color;
    for (let row = y; row < y + height; row++) {
      for (let col = x; col < x + width; col++) this.pixel(col, row, channels);
    }
  }

  line(x, y, endX, endY, color) {
    const stepX = Math.sign(endX - x);
    const stepY = Math.sign(endY - y);
    const deltaX = Math.abs(endX - x);
    const deltaY = -Math.abs(endY - y);
    let error = deltaX + deltaY;
    while (true) {
      this.pixel(x, y, color);
      if (x === endX && y === endY) return;
      const doubled = error * 2;
      if (doubled >= deltaY) {
        error += deltaY;
        x += stepX;
      }
      if (doubled <= deltaX) {
        error += deltaX;
        y += stepY;
      }
    }
  }

  polygon(points, color) {
    const rows = points.map(([, y]) => y);
    for (let y = Math.min(...rows); y <= Math.max(...rows); y++) {
      const cuts = [];
      for (let index = 0; index < points.length; index++) {
        const [x1, y1] = points[index];
        const [x2, y2] = points[(index + 1) % points.length];
        if ((y1 <= y && y2 > y) || (y2 <= y && y1 > y)) {
          cuts.push(x1 + ((y - y1) * (x2 - x1)) / (y2 - y1));
        }
      }
      cuts.sort((a, b) => a - b);
      for (let index = 0; index + 1 < cuts.length; index += 2) {
        const start = Math.ceil(cuts[index]);
        const end = Math.floor(cuts[index + 1]);
        this.rect(start, y, end - start + 1, 1, color);
      }
    }
    for (let index = 0; index < points.length; index++) {
      this.line(...points[index], ...points[(index + 1) % points.length], color);
    }
  }

  oval(x, y, radiusX, radiusY, color) {
    x = Math.round(x);
    y = Math.round(y);
    for (let dy = -radiusY; dy <= radiusY; dy++) {
      const span = Math.floor(radiusX * Math.sqrt(1 - (dy / radiusY) ** 2));
      this.rect(x - span, y + dy, span * 2 + 1, 1, color);
    }
  }

  save(filename) {
    const header = Buffer.alloc(13);
    header.writeUInt32BE(this.width, 0);
    header.writeUInt32BE(this.height, 4);
    header[8] = 8;
    header[9] = 6;
    const stride = this.width * 4;
    const pixels = Buffer.alloc(this.height * (stride + 1));
    for (let row = 0; row < this.height; row++) {
      this.data.copy(pixels, row * (stride + 1) + 1, row * stride, (row + 1) * stride);
    }
    writeFileSync(fileURLToPath(new URL(filename, import.meta.url)), Buffer.concat([
      Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
      pngChunk('IHDR', header), pngChunk('IDAT', deflateSync(pixels)), pngChunk('IEND', Buffer.alloc(0)),
    ]));
  }
}

const cachedColors = new Map();
function hex(color) {
  if (!cachedColors.has(color)) {
    cachedColors.set(color, [...Buffer.from(color.replace('#', ''), 'hex'), 255]);
  }
  return cachedColors.get(color);
}

function pngChunk(type, data) {
  const bytes = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const chunk = Buffer.alloc(data.length + 12);
  chunk.writeUInt32BE(data.length);
  bytes.copy(chunk, 4);
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  chunk.writeUInt32BE((crc ^ 0xffffffff) >>> 0, chunk.length - 4);
  return chunk;
}

let randomState = 31282;
function randomInt(maximum) {
  randomState = (Math.imul(randomState, 1664525) + 1013904223) >>> 0;
  return Math.floor((randomState / 4294967296) * maximum);
}

const ink = '#4d3844';
const linen = '#fff4d2';
const gold = '#e5a856';
const earth = '#e8bf91';
const green = '#487d58';
const darkGreen = '#365e53';
const leaf = '#679f5b';
const newLeaf = '#8fb867';

const world = {left: -160, top: -120, width: 960, height: 600};
const shorelineAnchors = [
  [-120, 386], [-98, 403], [-70, 425], [-36, 451], [0, 471], [43, 490],
  [80, 508], [114, 513], [146, 510], [180, 502], [215, 497], [248, 484],
  [282, 468], [315, 449], [349, 429], [391, 407], [432, 391], [479, 382],
];

function shorelineX(y) {
  const right = shorelineAnchors.findIndex(([row]) => row > y);
  if (right < 0) return shorelineAnchors.at(-1)[1];
  const [y1, x1] = shorelineAnchors[right - 1];
  const [y2, x2] = shorelineAnchors[right];
  const [y0, x0] = shorelineAnchors[Math.max(0, right - 2)];
  const [y3, x3] = shorelineAnchors[Math.min(shorelineAnchors.length - 1, right + 1)];
  const span = y2 - y1;
  const t = (y - y1) / span;
  const t2 = t * t;
  const t3 = t2 * t;
  const startSlope = span * (x2 - x0) / (y2 - y0);
  const endSlope = span * (x3 - x1) / (y3 - y1);
  return Math.round((2 * t3 - 3 * t2 + 1) * x1 + (t3 - 2 * t2 + t) * startSlope
    + (-2 * t3 + 3 * t2) * x2 + (t3 - t2) * endSlope);
}

const coast = Array.from({length: world.height}, (_, row) => shorelineX(world.top + row));

function walk(canvas, x, y, w, h) {
  canvas.rect(x + 1, y + 2, w, h, '#c69a73');
  canvas.rect(x, y, w, h, '#f5d9aa');
  for (let row = 2; row < h; row += 6) {
    canvas.rect(x + 1, y + row, w - 2, 1, '#e8c99a');
    for (let col = 4 + (row % 4) * 2; col < w - 2; col += 15) {
      canvas.rect(x + col, y + row, 1, Math.min(6, h - row), '#eacb9c');
    }
  }
  canvas.rect(x, y, w, 1, '#ffe7b7');
}

function ground(canvas) {
  for (const [row, shore] of coast.entries()) {
    const y = world.top + row;
    const swell = Math.round(Math.sin(row * 0.025) * 8 + Math.sin(row * 0.057) * 3);
    const dune = Math.round(Math.cos(row * 0.018) * 8 + Math.sin(row * 0.06) * 4);
    const yard = shore - 34 + dune;
    const wash = shore + 8;
    const shoal = shore + 25 + swell;
    const reef = shore + 60 + swell * 2;
    const bay = shore + 116 + swell * 2;
    const deep = shore + 193 + swell * 3;
    canvas.rect(world.left, y, yard - world.left, 1, earth);
    canvas.rect(yard, y, shore - yard - 4, 1, '#f5d8a2');
    canvas.rect(shore - 4, y, 4, 1, '#e7c99a');
    canvas.rect(shore, y, wash - shore, 1, '#a5cdb6');
    canvas.rect(wash, y, shoal - wash, 1, '#83c2b1');
    canvas.rect(shoal, y, reef - shoal, 1, '#63b1aa');
    canvas.rect(reef, y, bay - reef, 1, '#529fa5');
    canvas.rect(bay, y, deep - bay, 1, '#478b9b');
    canvas.rect(deep, y, world.left + world.width - deep, 1, '#427f94');
  }
  canvas.polygon([[-160, -120], [313, -120], [339, -95], [346, -62], [380, -40], [392, -13], [380, 24], [370, 47], [326, 51], [271, 29], [177, 26], [114, 31], [66, 25], [25, 51], [0, 81], [-31, 94], [-53, 126], [-56, 166], [-98, 211], [-105, 255], [-81, 296], [-105, 329], [-141, 339], [-160, 339]], '#b8bb75');
  canvas.polygon([[-160, -120], [218, -120], [267, -102], [289, -72], [283, -30], [285, 0], [261, 12], [145, 11], [101, 24], [57, 18], [0, 53], [-41, 65], [-68, 105], [-67, 147], [-102, 180], [-118, 220], [-120, 259], [-160, 294]], '#94aa68');
  canvas.polygon([[-160, -92], [-124, -97], [-92, -82], [-39, -87], [5, -110], [81, -120], [134, -120], [149, -108], [108, -91], [49, -78], [17, -62], [-17, -37], [-69, -24], [-100, 17], [-119, 42], [-160, 50]], '#829c63');
  canvas.polygon([[-160, 350], [-103, 320], [-80, 306], [-53, 308], [-19, 275], [0, 191], [25, 202], [24, 248], [31, 271], [21, 287], [11, 331], [30, 373], [11, 408], [-9, 436], [-37, 479], [-160, 479]], '#a8b36e');
  canvas.polygon([[84, 253], [141, 254], [170, 271], [163, 287], [178, 323], [220, 346], [288, 352], [337, 371], [348, 396], [315, 420], [304, 451], [274, 479], [50, 479], [62, 421], [95, 372], [87, 341], [97, 311], [82, 287]], '#b6b777');
  canvas.polygon([[151, 314], [177, 322], [204, 347], [258, 364], [291, 395], [274, 425], [248, 439], [224, 479], [83, 479], [91, 445], [127, 400], [117, 355]], '#a6ae6d');
  canvas.polygon([[178, 269], [213, 255], [316, 252], [347, 274], [373, 277], [394, 293], [405, 310], [381, 321], [349, 311], [307, 314], [284, 298], [248, 299], [219, 284], [194, 287]], '#d1bb79');
  terrainTexture(canvas);
  walk(canvas, 40, 240, 389, 12);
  walk(canvas, 49, 251, 17, 71);
  canvas.polygon([[48, 318], [66, 318], [67, 352], [59, 374], [40, 395], [27, 419], [25, 452], [15, 479], [0, 479], [10, 449], [13, 417], [25, 392], [45, 369], [50, 352]], '#eed1a0');
  canvas.line(50, 345, 51, 361, '#ffe0a8');
  canvas.polygon([[416, 240], [432, 240], [442, 234], [451, 218], [459, 216], [455, 232], [439, 251], [415, 252]], '#efd4a4');
}

function terrainTexture(canvas) {
  const textures = new Map([
    [earth, ['#ecc69a', '#d7a97e']],
    ['#f5d8a2', ['#f9dfad', '#edc98e']],
    ['#b8bb75', ['#c3c382', '#aab272']],
    ['#94aa68', ['#a3b372', '#87a26a']],
    ['#829c63', ['#91a86a', '#78925b']],
    ['#a8b36e', ['#b9be7e', '#9ba766']],
    ['#b6b777', ['#c3be80', '#a9ab6c']],
    ['#a6ae6d', ['#b3b67a', '#9ba568']],
  ].map(([base, colors]) => [Buffer.from(hex(base)).readUInt32BE(), colors]));
  for (let index = 0; index < 6900; index++) {
    const row = randomInt(world.height);
    const col = randomInt(coast[row] - world.left - 7);
    const offset = (row * world.width + col) * 4;
    const colors = textures.get(canvas.data.readUInt32BE(offset));
    if (colors) canvas.rect(world.left + col, world.top + row, 1 + randomInt(4), 1, colors[Number(index % 4 === 0)]);
  }
  for (let index = 0; index < 1600; index++) {
    const row = randomInt(world.height);
    const x = coast[row] + 9 + randomInt(world.left + world.width - coast[row] - 9);
    const y = world.top + row;
    const tint = x - coast[row] < 45 ? [195, 224, 190, 82] : [160, 210, 204, 52];
    const length = 1 + randomInt(8);
    for (let offset = 0; offset < length && x + offset < world.left + world.width; offset++) {
      const pixel = (row * world.width + x + offset - world.left) * 4;
      const alpha = tint[3] / 255;
      const base = canvas.data;
      canvas.pixel(x + offset, y, [0, 1, 2].map(channel => Math.round(base[pixel + channel] * (1 - alpha) + tint[channel] * alpha)).concat(255));
    }
  }
}

function palm(canvas, x, y, size = 1, lean = 1) {
  function points(pairs) {
    return pairs.map(([dx, dy]) => [x + Math.round(dx * size * lean), y + Math.round(dy * size)]);
  }
  canvas.polygon(points([[0, -1], [19, -5], [33, -5], [23, -2], [12, 2], [0, 3], [-6, 1]]), '#b79970');
  canvas.polygon(points([[-2, 0], [2, 0], [2, -11], [5, -21], [9, -29], [6, -30], [2, -22], [-1, -12]]), '#925f4c');
  canvas.polygon(points([[-2, -2], [-1, -2], [0, -13], [4, -24], [6, -27], [5, -28], [1, -22]]), '#d5a275');
  for (const [a, b] of [[[0, -8], [2, -8]], [[1, -14], [3, -14]], [[3, -20], [5, -19]], [[5, -25], [7, -24]]]) {
    canvas.line(...points([a, b])[0], ...points([a, b])[1], '#a77958');
  }
  canvas.polygon(points([[6, -28], [2, -34], [-4, -38], [-10, -39], [-17, -36], [-20, -30], [-14, -33], [-9, -33], [-5, -31], [1, -29]]), green);
  canvas.polygon(points([[6, -29], [9, -38], [14, -44], [20, -46], [24, -43], [20, -43], [16, -40], [12, -33], [9, -28]]), leaf);
  canvas.polygon(points([[7, -30], [16, -34], [24, -34], [31, -30], [34, -25], [28, -28], [23, -29], [18, -28], [10, -26]]), green);
  canvas.polygon(points([[8, -28], [14, -28], [21, -23], [26, -16], [26, -12], [23, -16], [18, -19], [17, -21], [10, -24]]), darkGreen);
  canvas.polygon(points([[5, -29], [-4, -29], [-12, -26], [-16, -20], [-17, -15], [-12, -19], [-8, -20], [-3, -24], [5, -26]]), leaf);
  canvas.polygon(points([[6, -31], [1, -40], [1, -47], [6, -52], [9, -51], [5, -46], [5, -41], [8, -34], [8, -28]]), newLeaf);
  canvas.line(...points([[-15, -34], [1, -30]])[0], ...points([[-15, -34], [1, -30]])[1], '#80a865');
  canvas.line(...points([[12, -31], [28, -30]])[0], ...points([[12, -31], [28, -30]])[1], '#82ad67');
  const [coconutX, coconutY] = points([[8, -27]])[0];
  canvas.rect(coconutX - 2, coconutY, 4, 3, '#6c5645');
}

function duneGrove(canvas, x, y, lean, size) {
  palm(canvas, x, y, size, lean);
  canvas.oval(x - 7, y + 7, 18, 5, '#9da570');
  canvas.oval(x - 15, y + 4, 10, 5, '#729358');
  canvas.oval(x - 5, y + 2, 9, 6, '#658854');
  canvas.oval(x + 6, y + 6, 8, 4, '#809b58');
  canvas.oval(x - 13, y + 1, 7, 3, '#9eb16a');
  canvas.oval(x - 5, y, 5, 3, '#91a963');
  for (const [dx, dy] of [[-17, 2], [-13, 1], [-8, 4], [2, 5], [8, 5]]) {
    canvas.pixel(x + dx, y + dy, '#c8c681');
  }
}

function shoreDetails(canvas) {
  for (const [x, y, lean, size] of [
    [-128, -35, 1, 0.92], [-78, -4, -1, 1.18], [14, -32, 1, 1.03], [94, -48, -1, 0.91],
    [179, -55, -1, 1.14], [224, -20, 1, 0.78], [329, -51, 1, 1.05], [389, -3, -1, 0.86],
    [-122, 62, 1, 1.03], [-53, 133, 1, 1.25], [-111, 188, -1, 0.93], [-85, 260, 1, 1.08],
    [-123, 342, -1, 1.2], [-51, 355, 1, 0.95], [-71, 430, -1, 1.13], [77, 411, -1, 1.06],
    [118, 370, 1, 1.0], [165, 332, -1, 0.96], [179, 418, -1, 1.16], [233, 379, 1, 0.87],
    [276, 451, 1, 0.99], [317, 393, -1, 1.10], [368, 343, -1, 0.87], [415, 305, 1, 0.75],
  ]) duneGrove(canvas, x, y, lean, size);

  for (let index = 0; index < 100; index++) {
    const y = world.top + 6 + randomInt(world.height - 12);
    const x = coast[y - world.top] - 10 - randomInt(15);
    if (y >= 112 && y <= 158) continue;
    canvas.rect(x, y, 2 + randomInt(3), 1, '#e5c38f');
    canvas.pixel(x + 1, y - 1, index % 5 === 0 ? '#d6a981' : '#f9e2b1');
  }
}

function terrain() {
  const canvas = new Canvas(world.width, world.height, world.left, world.top);
  ground(canvas);
  shoreDetails(canvas);
  for (const [x, y, size, lean] of [[20, 40, 0.82, 1], [96, 20, 0.65, -1], [183, 28, 0.64, 1], [269, 31, 0.68, -1], [340, 56, 1.08, 1], [391, 56, 0.94, 1], [440, 106, 0.75, -1], [460, 142, 0.55, 1], [-8, 190, 0.83, 1], [467, 194, 0.52, -1], [2, 281, 0.83, 1], [128, 288, 0.77, -1], [196, 294, 0.8, 1], [292, 279, 0.76, 1]]) {
    palm(canvas, x, y, size, lean);
  }
  return canvas;
}

// The model owns placement. Atlas cells are 32 × 32, with art at the top left
// occupying exactly the corresponding model footprint (pixels, rotated as needed).
const furniture = [
  [16, 24, (c) => {
    c.rect(1, 1, 15, 23, [75, 53, 61, 56]);
    c.rect(0, 0, 14, 22, '#785249');
    c.rect(1, 0, 12, 3, '#bf815e');
    c.rect(1, 0, 12, 1, '#e7ad78');
    c.rect(1, 3, 12, 17, linen);
    for (const x of [2, 8]) {
      c.rect(x, 4, 4, 3, '#fffae1');
      c.rect(x, 7, 4, 1, '#debc9c');
    }
    c.rect(1, 9, 12, 11, '#5e9c92');
    c.rect(1, 9, 12, 1, '#9ec6ab');
    c.rect(1, 17, 12, 1, '#a6cbb2');
    c.rect(1, 20, 12, 1, '#426f6e');
    for (const x of [3, 6, 9]) c.pixel(x, 18, linen);
    c.pixel(1, 22, '#624b45');
    c.pixel(12, 22, '#624b45');
  }],
  [24, 16, (c) => {
    c.rect(2, 3, 22, 13, [75, 53, 61, 56]);
    c.rect(0, 5, 22, 9, '#8f5146');
    c.rect(1, 8, 20, 4, '#b57554');
    c.rect(0, 3, 22, 6, '#dba76c');
    c.rect(0, 3, 22, 1, '#f6cf8b');
    c.rect(2, 6, 6, 2, linen);
    c.rect(12, 1, 7, 5, ink);
    c.rect(13, 2, 5, 3, '#79afaa');
    c.rect(14, 6, 3, 1, '#86614c');
    for (const x of [3, 10, 17]) c.rect(x, 10, 3, 1, '#ecb779');
    c.rect(1, 13, 2, 2, '#654848');
    c.rect(19, 13, 2, 2, '#654848');
  }],
  [32, 16, (c) => {
    c.rect(2, 4, 30, 12, [75, 53, 61, 56]);
    c.rect(0, 6, 30, 8, '#945445');
    c.rect(0, 2, 30, 8, '#d7a477');
    c.rect(0, 2, 30, 1, '#ffe0a8');
    c.rect(0, 9, 30, 1, '#82564a');
    for (const [index, filling] of ['#b66252', '#80a35e', '#e6a154'].entries()) {
      const x = 2 + index * 9;
      c.rect(x, 4, 8, 4, '#8b7f6d');
      c.rect(x, 4, 8, 3, linen);
      c.rect(x + 1, 5, 6, 2, filling);
      c.pixel(x + 2, 5, '#f2d08b');
      c.pixel(x + 5, 6, '#f2d08b');
      c.rect(x + 1, 11, 6, 1, '#c88863');
    }
    c.rect(1, 13, 2, 2, '#704d46');
    c.rect(27, 13, 2, 2, '#704d46');
  }],
  [16, 16, (c) => {
    c.oval(8, 10, 7, 4, [75, 53, 61, 56]);
    for (const x of [0, 11]) {
      c.rect(x, 9, 5, 5, '#814f4b');
      c.rect(x + 1, 9, 3, 3, '#bf795f');
      c.rect(x, 13, 5, 1, '#e0a16d');
    }
    c.oval(7, 7, 6, 4, '#b27754');
    c.oval(7, 6, 6, 4, '#f0c996');
    c.rect(6, 3, 3, 6, '#b36b62');
    c.rect(3, 6, 2, 1, linen);
    c.rect(10, 6, 2, 1, linen);
    c.pixel(7, 4, leaf);
  }],
  [8, 24, (c) => {
    c.rect(1, 3, 7, 21, [75, 53, 61, 56]);
    c.rect(0, 1, 7, 20, '#955b45');
    c.rect(0, 0, 7, 19, linen);
    c.rect(1, 1, 5, 17, '#c17962');
    c.rect(1, 1, 5, 4, '#dd9d75');
    for (const row of [6, 10, 14]) c.rect(1, row, 5, 1, '#f4d9a8');
    c.rect(1, 21, 1, 2, '#77534b');
    c.rect(5, 21, 1, 2, '#77534b');
  }],
  [16, 16, (c, rotation) => {
    const stripe = ['#c07860', '#769e78', '#c99055', '#8190a5'][rotation];
    c.oval(9, 12, 6, 2, [75, 53, 61, 56]);
    c.rect(7, 6, 2, 8, '#a47657');
    c.rect(7, 6, 1, 7, '#f3c889');
    c.polygon([[0, 8], [2, 4], [7, 1], [10, 2], [13, 4], [15, 8]], stripe);
    c.polygon([[3, 8], [7, 1], [6, 8]], '#f6d5a0');
    c.polygon([[9, 8], [7, 1], [12, 8]], '#f6d5a0');
    c.rect(0, 8, 16, 1, '#af7756');
    c.rect(1, 7, 14, 1, '#eed6a1');
    c.pixel(7, 0, linen);
  }, true],
  [8, 8, (c, rotation) => {
    c.rect(2, 7, 5, 1, [75, 53, 61, 56]);
    c.polygon([[1, 4], [6, 4], [5, 7], [2, 7]], '#b86d51');
    c.rect(1, 4, 6, 1, '#e9a174');
    const leafTip = [3, 4, 2, 5][rotation];
    c.polygon([[3, 4], [0, 3], [0, 1], [2, 2], [leafTip, 0], [5, 1], [5, 3], [7, 1], [7, 3]], green);
    c.pixel(leafTip, 1, newLeaf);
    c.pixel(1, 2, leaf);
  }, true],
  [24, 8, (c) => {
    c.rect(2, 2, 22, 6, [75, 53, 61, 56]);
    c.rect(1, 0, 21, 3, '#92644f');
    c.rect(1, 0, 21, 1, '#d39f71');
    c.rect(0, 3, 23, 3, '#c08a5c');
    c.rect(0, 3, 23, 1, '#e7bb7b');
    c.rect(0, 5, 23, 1, '#9e6b56');
    c.rect(2, 6, 2, 2, '#6d5250');
    c.rect(19, 6, 2, 2, '#6d5250');
  }],
];

function furnitureAtlas() {
  const size = 32;
  const atlas = new Canvas(size * 4, size * furniture.length);
  for (const [row, [width, height, paint, upright]] of furniture.entries()) {
    for (let rotation = 0; rotation < 4; rotation++) {
      const piece = new Canvas(width, height);
      paint(piece, rotation);
      for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
          const offset = (y * width + x) * 4;
          if (piece.data[offset + 3] === 0) continue;
          const [dx, dy] = upright ? [x, y] : [[x, y], [height - 1 - y, x], [width - 1 - x, height - 1 - y], [y, width - 1 - x]][rotation];
          atlas.pixel(rotation * size + dx, row * size + dy, piece.data.subarray(offset, offset + 4));
        }
      }
    }
  }
  return atlas;
}

const guests = [
  {skin: '#d5936c', litSkin: '#edb28a', hair: '#4c3642', shirt: '#d3715e', lightShirt: '#ed9774', pants: '#656880', accessory: '#f1cb87'},
  {skin: '#a86d53', litSkin: '#c38765', hair: '#3c323f', shirt: '#64a297', lightShirt: '#93c1a3', pants: '#76515e', accessory: '#e8ab64'},
  {skin: '#ebaa7c', litSkin: '#f8c28c', hair: '#8d5d49', shirt: '#e0aa56', lightShirt: '#f4cd77', pants: '#587984', accessory: '#b8665a'},
  {skin: '#bb7d5e', litSkin: '#e0a27b', hair: '#543e46', shirt: '#f0e3bc', lightShirt: '#fff1cb', pants: '#576673', accessory: '#6ba29b'},
  {skin: '#c38363', litSkin: '#e5aa7d', hair: '#534050', shirt: '#d38c64', lightShirt: '#efb079', pants: '#737a9b', accessory: '#efbd68'},
];

function character(canvas, x, y, frame, palette, variant) {
  const child = variant === 4;
  const staff = variant === 3;
  const bob = [0, 1, 0, 1][frame];
  const offset = child ? 6 : 0;
  const head = y + 3 + offset + bob;
  const torso = y + 11 + offset + bob;
  const hem = y + (child ? 19 : 18) + bob;
  const [leftStride, rightStride] = [[0, 0], [-1, 1], [0, 0], [1, -1]][frame];
  canvas.oval(x + 10, y + 22, child ? 4 : 6, 1, [73, 51, 62, 80]);
  canvas.rect(x + 7 + leftStride, hem - 1, 3, 22 - (hem - y), palette.pants);
  canvas.rect(x + 11 + rightStride, hem - 1, 3, 22 - (hem - y), palette.pants);
  canvas.rect(x + 6 + leftStride, y + 21, 4, 1, ink);
  canvas.rect(x + 11 + rightStride, y + 21, 4, 1, ink);
  canvas.rect(x + 7, torso, 7, hem - torso, ink);
  canvas.rect(x + 8, torso, 5, hem - torso - 1, palette.shirt);
  canvas.rect(x + 8, torso, 2, hem - torso - 1, palette.lightShirt);
  canvas.rect(x + 5, torso + 1 + (frame === 3 ? 1 : 0), 2, child ? 3 : 5, palette.shirt);
  canvas.rect(x + 14, torso + 1 + (frame === 1 ? 1 : 0), 2, child ? 3 : 5, palette.shirt);
  canvas.pixel(x + 5, torso + (child ? 4 : 6), palette.skin);
  canvas.pixel(x + 15, torso + (child ? 4 : 6), palette.skin);
  canvas.rect(x + 8, head - 1, 6, 2, palette.hair);
  canvas.rect(x + 7, head, 8, 6, palette.hair);
  canvas.rect(x + 8, head + 2, 7, 5, palette.skin);
  canvas.rect(x + 8, head + 2, 5, 3, palette.litSkin);
  canvas.rect(x + 8, head + 7, 6, 1, palette.hair);
  canvas.pixel(x + 10, head + 4, ink);
  canvas.pixel(x + 13, head + 4, ink);
  if (variant === 0 || child) {
    canvas.rect(x + 6, head + 1, 10, 2, palette.accessory);
    canvas.rect(x + 8, head - 2, 6, 3, palette.accessory);
    canvas.rect(x + 8, head, 6, 1, palette.shirt);
  }
  if (variant === 1) {
    canvas.rect(x + 8, torso + 2, 1, 4, palette.accessory);
    canvas.rect(x + 5, torso + 4, 3, 3, '#ac714e');
  }
  if (variant === 2) {
    canvas.rect(x + 9, head + 3, 6, 2, '#5e4653');
    canvas.pixel(x + 11, head + 4, palette.litSkin);
  }
  if (staff) {
    canvas.rect(x + 7, head - 1, 8, 3, '#f8e4b8');
    canvas.rect(x + 8, head + 1, 8, 1, palette.accessory);
    canvas.rect(x + 10, torso, 2, 2, palette.accessory);
    canvas.pixel(x + 12, torso + 2, gold);
  }
}

function appIcon() {
  const canvas = new Canvas(64, 64);
  canvas.polygon([[9, 0], [54, 0], [63, 9], [63, 54], [54, 63], [9, 63], [0, 54], [0, 9]], ink);
  canvas.polygon([[10, 2], [53, 2], [61, 10], [61, 53], [53, 60], [10, 60], [2, 53], [2, 10]], '#77b8ad');
  canvas.polygon([[2, 34], [9, 29], [23, 30], [33, 35], [44, 36], [55, 31], [61, 29], [61, 53], [53, 60], [10, 60], [2, 53]], '#a2cdb8');
  canvas.polygon([[2, 40], [10, 34], [21, 34], [34, 40], [45, 40], [56, 36], [61, 35], [61, 53], [53, 60], [10, 60], [2, 53]], '#f3cf99');
  canvas.oval(47, 15, 7, 7, '#eaa75b');
  canvas.oval(46, 14, 6, 6, '#ffde8d');
  for (const [x, y, w] of [[6, 12, 7], [40, 26, 8], [51, 23, 6], [28, 16, 4], [38, 30, 4]]) {
    canvas.rect(x, y, w, 1, '#a4d1ba');
  }
  canvas.polygon([[31, 45], [51, 45], [55, 48], [55, 53], [52, 56], [30, 56], [26, 52], [26, 49]], '#b78365');
  canvas.polygon([[30, 44], [50, 44], [54, 47], [54, 52], [51, 55], [29, 55], [25, 51], [25, 48]], linen);
  canvas.polygon([[31, 46], [49, 46], [52, 48], [52, 51], [50, 53], [30, 53], [27, 50], [27, 49]], '#4faaa7');
  canvas.rect(31, 47, 18, 1, '#41888e');
  canvas.rect(32, 50, 6, 1, '#9ed3bb');
  canvas.rect(43, 51, 6, 1, '#9ed3bb');
  palm(canvas, 15, 55, 0.76, 1);
  return canvas;
}

const people = new Canvas(80, 120);
const shoreProfile = new Canvas(1, world.height);
terrain().save('resort.png');
furnitureAtlas().save('furniture.png');
// Red/green hold the low/high bytes of the first water pixel in each image row.
for (const [row, shore] of coast.entries()) {
  const col = shore - world.left;
  shoreProfile.pixel(0, row, [col & 255, col >> 8, 0, 255]);
}
shoreProfile.save('resort_shore.png');
for (const [row, palette] of guests.entries()) {
  for (let frame = 0; frame < 4; frame++) character(people, frame * 20, row * 24, frame, palette, row);
}
people.save('people.png');
appIcon().save('icon.png');
