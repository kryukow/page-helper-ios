/* Mint Flow (02): the Page Helper glass-page identity used by Safari's floating capsule.
   The legacy PageHelperPaper export is preserved for the existing button protocol. */
globalThis.PageHelperPaper = class {
  constructor(canvas) {
    this.canvas = canvas;
    this.busy = false;
    this.complete = false;
    this.frame = 0;
    this.started = performance.now();
    this.lastFrame = -Infinity;
    this.disposed = false;
    this.motion = matchMedia('(prefers-reduced-motion: reduce)');
    this.tick = time => {
      this.frame = 0;
      if (this.disposed || document.hidden) return;
      const interval = this.busy ? 1000 / 60 : 1000 / 20;
      if (time - this.lastFrame >= interval - 1) {
        this.draw(time);
        this.lastFrame = time;
      }
      if (!this.motion.matches) this.frame = requestAnimationFrame(this.tick);
    };
    this.visibility = () => this.refresh();
    document.addEventListener('visibilitychange', this.visibility);
    this.motion.addEventListener('change', this.visibility);
    this.refresh();
  }
  setBusy(value, complete = false) {
    if (this.disposed) return;
    this.busy = Boolean(value);
    this.complete = Boolean(complete);
    // State updates must not reset the animation timeline.
    this.refresh();
  }
  refresh() {
    if (this.frame) cancelAnimationFrame(this.frame);
    this.frame = 0;
    if (this.disposed) return;
    this.draw(performance.now());
    if (!this.motion.matches && !document.hidden)
      this.frame = requestAnimationFrame(this.tick);
  }
  draw(time) {
    const ctx = this.canvas.getContext('2d');
    if (!ctx) return;
    const reduced = this.motion.matches;
    const t = reduced ? 0 : (time - this.started) / 1000;
    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    ctx.save();
    ctx.scale(this.canvas.width / 64, this.canvas.height / 64);
    // Page motif deliberately has no robotic eyes, wheels or arms.
    const y = reduced ? 0 : Math.sin(t * 1.35) * .85;
    ctx.translate(0, y);
    const path = () => {
      ctx.beginPath();
      ctx.moveTo(21, 7);
      ctx.lineTo(37, 7);
      ctx.lineTo(45, 15);
      ctx.lineTo(45, 51);
      ctx.quadraticCurveTo(45, 56, 40, 56);
      ctx.lineTo(21, 56);
      ctx.quadraticCurveTo(17, 56, 17, 52);
      ctx.lineTo(17, 11);
      ctx.quadraticCurveTo(17, 7, 21, 7);
      ctx.closePath();
    };
    const glass = ctx.createLinearGradient(17, 7, 45, 56);
    glass.addColorStop(0, 'rgba(186,255,226,.48)');
    glass.addColorStop(.5, 'rgba(23,191,145,.18)');
    glass.addColorStop(1, 'rgba(43,229,173,.53)');
    path();
    ctx.fillStyle = glass;
    ctx.strokeStyle = '#a1f9d4';
    ctx.lineWidth = 1.1;
    ctx.fill();
    ctx.stroke();

    // Folded corner.
    ctx.beginPath();
    ctx.moveTo(37, 7);
    ctx.lineTo(37, 11.5);
    ctx.quadraticCurveTo(37, 15, 40.5, 15);
    ctx.lineTo(45, 15);
    ctx.closePath();
    ctx.fillStyle = 'rgba(210,255,235,.82)';
    ctx.strokeStyle = '#e2fff1';
    ctx.lineWidth = .8;
    ctx.fill();
    ctx.stroke();

    ctx.save();
    path();
    ctx.clip();
    const lift = reduced ? 0 : Math.sin(t * (this.busy ? 4.5 : 2.1)) * 3.2;
    const shift = reduced ? 0 : Math.sin(t * (this.busy ? 3.6 : 1.6) + 1.1) * 2.5;
    const ribbon = (offset = 0) => {
      ctx.beginPath();
      ctx.moveTo(12, 40 + lift + offset);
      ctx.bezierCurveTo(26, 15 + shift + offset, 33, 55 - lift + offset, 51, 29 - lift + offset);
    };
    ribbon();
    ctx.lineCap = 'round';
    ctx.lineWidth = 9;
    ctx.strokeStyle = 'rgba(82,255,194,.15)';
    ctx.stroke();
    const stream = ctx.createLinearGradient(16, 25, 50, 47);
    stream.addColorStop(0, 'rgba(37,196,154,.15)');
    stream.addColorStop(.4, '#76ffd5');
    stream.addColorStop(.7, '#e9fff3');
    stream.addColorStop(1, 'rgba(37,196,154,.15)');
    ctx.lineWidth = 3;
    ctx.strokeStyle = stream;
    ctx.stroke();
    ribbon(6 - shift * .6);
    ctx.lineWidth = .95;
    ctx.strokeStyle = 'rgba(206,255,233,.85)';
    ctx.stroke();
    ctx.restore();

    ctx.beginPath();
    ctx.moveTo(22, 19);
    ctx.lineTo(30, 19);
    ctx.moveTo(22, 49);
    ctx.lineTo(34, 49);
    ctx.strokeStyle = 'rgba(188,255,222,.50)';
    ctx.lineWidth = 1;
    ctx.stroke();

    if (this.complete) {
      ctx.beginPath();
      ctx.arc(47, 48, 10, 0, Math.PI * 2);
      ctx.fillStyle = '#0c926d';
      ctx.strokeStyle = '#adffe0';
      ctx.lineWidth = 1.2;
      ctx.fill();
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(42, 48);
      ctx.lineTo(46, 52);
      ctx.lineTo(53, 44);
      ctx.strokeStyle = '#ffffff';
      ctx.lineWidth = 2.3;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      ctx.stroke();
    }
    ctx.restore();
  }
  dispose() {
    this.disposed = true;
    if (this.frame) cancelAnimationFrame(this.frame);
    this.frame = 0;
    document.removeEventListener('visibilitychange', this.visibility);
    this.motion.removeEventListener('change', this.visibility);
  }
};
