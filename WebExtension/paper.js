/* Compact vacuum animation. The legacy export keeps the button protocol stable. */
globalThis.PageHelperPaper = class {
  constructor(canvas) {
    this.canvas=canvas;this.busy=false;this.frame=0;this.started=performance.now();
    this.motion=matchMedia('(prefers-reduced-motion: reduce)');
    this.floor=document.createElement('canvas');this.floor.width=this.floor.height=64;
    this.floorAt=-Infinity;this.lastFrame=-Infinity;this.disposed=false;
    this.glyphs=[['A',12,17],['ß',45,13],['é',52,32],['λ',42,51],['ñ',17,50],['β',9,33]];
    this.tick=time=>{
      this.frame=0;if(this.disposed)return;
      if(time-this.lastFrame>=1000/60-1){this.draw(time);this.lastFrame=time;}
      if(this.busy&&!this.motion.matches&&!document.hidden)this.frame=requestAnimationFrame(this.tick);
    };
    this.visibility=()=>this.setBusy(this.busy);
    document.addEventListener('visibilitychange',this.visibility);
    this.motion.addEventListener('change',this.visibility);
    this.draw(this.started);
  }
  setBusy(value) {
    if(this.disposed)return;
    if(value&&!this.busy)this.started=performance.now();
    const changed=value!==this.busy;this.busy=value;
    if(changed)this.floorAt=-Infinity;
    // Frequent progress updates must not cancel/reset the animation clock.
    if(this.busy&&!this.motion.matches&&!document.hidden){
      if(!this.frame){this.lastFrame=-Infinity;this.frame=requestAnimationFrame(this.tick);}
    }else{
      if(this.frame)cancelAnimationFrame(this.frame);
      this.frame=0;this.draw(performance.now());
    }
  }
  pose(time) {
    const moving=this.busy&&!this.motion.matches;
    const t=moving?(time-this.started)/1000:0;
    return {x:moving?32+12*Math.sin(t*.9):32,y:moving?32+9*Math.sin(t*1.3):32,
      angle:moving?Math.atan2(11.7*Math.cos(t*1.3),10.8*Math.cos(t*.9)):0,t,moving};
  }
  draw(time) {
    const ctx=this.canvas.getContext('2d');if(!ctx)return;
    const p=this.pose(time);
    ctx.clearRect(0,0,this.canvas.width,this.canvas.height);
    ctx.save();ctx.scale(this.canvas.width/64,this.canvas.height/64);
    if(time-this.floorAt>=125){
      const floor=this.floor.getContext('2d');floor.clearRect(0,0,64,64);
      if(p.moving){
        floor.font='9px system-ui';floor.textAlign='center';floor.textBaseline='middle';
        for(const [glyph,x,y] of this.glyphs){
          const distance=Math.hypot(x-p.x,y-p.y);
          const pull=Math.max(0,1-distance/27);
          floor.fillStyle=`rgba(148,240,201,${.55*(1-pull)})`;
          floor.fillText(glyph,x+(p.x-x)*pull,y+(p.y-y)*pull);
        }
      }
      this.floorAt=time;
    }
    ctx.drawImage(this.floor,0,0);
    ctx.translate(p.x,p.y);ctx.rotate(p.angle);
    ctx.fillStyle='#214d40';ctx.strokeStyle='#94f0c9';ctx.lineWidth=2;
    ctx.beginPath();ctx.arc(0,0,14,0,Math.PI*2);ctx.fill();ctx.stroke();
    ctx.strokeStyle='rgba(148,240,201,.25)';ctx.lineWidth=1;
    ctx.beginPath();ctx.arc(0,0,10,0,Math.PI*2);ctx.stroke();
    ctx.fillStyle='#94f0c9';ctx.beginPath();ctx.arc(0,0,4.5,0,Math.PI*2);ctx.fill();
    ctx.beginPath();ctx.roundRect(8,-4,2,8,1);ctx.fill();
    ctx.fillStyle='rgba(148,240,201,.6)';ctx.beginPath();ctx.arc(-7,-7,1.5,0,Math.PI*2);ctx.fill();
    if(p.moving){
      ctx.strokeStyle='#94f0c9';ctx.lineWidth=1.1;ctx.beginPath();
      for(let arm=0;arm<3;arm++){
        const angle=arm*Math.PI*2/3+p.t*3;
        ctx.moveTo(9,11);ctx.lineTo(9+Math.cos(angle)*5,11+Math.sin(angle)*5);
      }
      ctx.stroke();
    }
    ctx.restore();
  }
  dispose(){
    this.disposed=true;if(this.frame)cancelAnimationFrame(this.frame);this.frame=0;
    document.removeEventListener('visibilitychange',this.visibility);
    this.motion.removeEventListener('change',this.visibility);
  }
};