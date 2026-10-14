/* Shared crystal renderer. Keep the legacy name for existing button callers. */
globalThis.PageHelperCrystal = class {
  constructor(canvas) {
    this.canvas=canvas;this.busy=false;this.frame=0;this.started=performance.now();this.disposed=false;this.lastFrame=-Infinity;
    this.motion=matchMedia('(prefers-reduced-motion: reduce)');
    this.tick=time=>{this.frame=0;if(this.disposed)return;if(time-this.lastFrame>=1000/60-1){this.draw(time);this.lastFrame=time;}if(this.busy&&!this.motion.matches&&!document.hidden)this.frame=requestAnimationFrame(this.tick);};
    this.visibility=()=>this.setBusy(this.busy);
    document.addEventListener('visibilitychange',this.visibility);this.motion.addEventListener('change',this.visibility);this.draw(this.started);
  }
  setBusy(value) {
    if(this.disposed)return;
    if(value&&!this.busy)this.started=performance.now();this.busy=value;
    if(value&&!this.motion.matches&&!document.hidden){if(!this.frame){this.lastFrame=-Infinity;this.frame=requestAnimationFrame(this.tick);}}
    else{if(this.frame)cancelAnimationFrame(this.frame);this.frame=0;this.draw(performance.now());}
  }
  draw(time) {
    const c=this.canvas.getContext('2d');if(!c)return;
    const moving=this.busy&&!this.motion.matches,t=moving?(time-this.started)/1000:1.8;
    c.clearRect(0,0,this.canvas.width,this.canvas.height);c.save();c.scale(this.canvas.width/200,this.canvas.height/200);c.translate(100,100);
    const rgb=this.canvas.dataset.tone==='dark'?'36,132,98':'148,240,201',mint=a=>`rgba(${rgb},${a})`;
    const vertices=[];
    for(let i=0;i<6;i++){const a=i*Math.PI/3+t*.4;vertices.push({x:53*Math.cos(a),y:20*Math.sin(a)+10*Math.sin(t*.8),depth:Math.sin(a)});}
    const top={x:0,y:-65+5*Math.sin(t*.8)},bottom={x:0,y:65+5*Math.sin(t*.8)},faces=[];
    for(let i=0;i<6;i++){faces.push({a:top,b:vertices[i],d:vertices[(i+1)%6],shade:vertices[i].depth});faces.push({a:bottom,b:vertices[i],d:vertices[(i+1)%6],shade:vertices[i].depth-.1});}
    faces.sort((a,b)=>a.shade-b.shade);
    for(const f of faces){c.beginPath();c.moveTo(f.a.x,f.a.y);c.lineTo(f.b.x,f.b.y);c.lineTo(f.d.x,f.d.y);c.closePath();c.fillStyle=mint(.12+(f.shade+1)*.16);c.fill();c.strokeStyle=mint(.55);c.lineWidth=.85;c.stroke();}
    if(moving){c.font='500 12px system-ui';c.textAlign='center';c.textBaseline='middle';for(let i=0;i<5;i++){const a=i*2.4+t*.3;c.fillStyle=mint(.38);c.fillText(['é','ß','A','λ','ñ'][i],76*Math.cos(a),57*Math.sin(a));}}
    c.restore();
  }
  dispose(){this.disposed=true;if(this.frame)cancelAnimationFrame(this.frame);this.frame=0;document.removeEventListener('visibilitychange',this.visibility);this.motion.removeEventListener('change',this.visibility);}
};
globalThis.PageHelperPaper=globalThis.PageHelperCrystal;
