/* The same mint paper, drawn with only 35 tiles for a small floating button. */
globalThis.PageHelperPaper = class {
  constructor(canvas) {
    this.canvas = canvas; this.busy = false; this.frame = 0; this.started = performance.now();
    this.motion = matchMedia('(prefers-reduced-motion: reduce)');
    this.tick = time => { this.frame = 0; this.draw(time); if (this.busy && !this.motion.matches && !document.hidden) this.frame = requestAnimationFrame(this.tick); };
    this.visibility = () => this.setBusy(this.busy);
    document.addEventListener('visibilitychange', this.visibility);
    this.motion.addEventListener('change', this.visibility);
    this.draw(this.started);
  }
  setBusy(value) {
    if (value && !this.busy) this.started = performance.now();
    this.busy = value;
    if (this.frame) cancelAnimationFrame(this.frame);
    this.frame = 0; this.tick(performance.now());
  }
  draw(time) {
    const canvas = this.canvas, ctx = canvas.getContext('2d');
    const width = canvas.width, height = canvas.height;
    ctx.clearRect(0, 0, width, height); ctx.save(); ctx.scale(width / 64, height / 64);
    const phase = this.busy && !this.motion.matches ? ((time - this.started) / 1000) % 3.1 : 2.2;
    const fade = phase > 2.5 ? Math.max(0, (3.1 - phase) / .6) : 1;
    for (let row = 0; row < 7; row++) for (let column = 0; column < 5; column++) {
      if (row === 0 && column === 4) continue;
      const order = (row * 7 + column * 11) % 13;
      const p = Math.min(1, Math.max(0, (phase - order * .055) / .65));
      const angle = (row * 5 + column) * 2.39996;
      const distance = (1 - (1 - Math.pow(1 - p, 3))) * 14;
      const x = 18 + column * 5.5 + Math.cos(angle) * distance;
      const y = 12 + row * 5.5 + Math.sin(angle) * distance;
      ctx.fillStyle = `rgba(102,224,178,${(.15 + .85 * p) * fade})`;
      ctx.beginPath(); ctx.roundRect(x, y, 5.1, 5.1, 1); ctx.fill();
    }
    ctx.fillStyle = `rgba(15,77,61,${Math.min(1, Math.max(0, (phase - 1.2) / .4)) * fade})`;
    for (let line = 0; line < 3; line++) {
      ctx.beginPath(); ctx.roundRect(23, 28 + line * 7, line === 2 ? 10 : 17, 2.4, 1.2); ctx.fill();
    }
    ctx.restore();
  }
  dispose() {
    if (this.frame) cancelAnimationFrame(this.frame);
    document.removeEventListener('visibilitychange', this.visibility);
    this.motion.removeEventListener('change', this.visibility);
  }
};
