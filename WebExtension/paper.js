/* Compact vacuum animation. The legacy export keeps the button protocol stable. */
globalThis.PageHelperPaper = class {
  constructor(canvas) {
    this.canvas=canvas;this.busy=false;this.frame=0;this.started=performance.now();
    this.motion=matchMedia('(prefers-reduced-motion: reduce)');
    this.lastFrame=-Infinity;this.disposed=false;
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
    this.busy=value;
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
    return {t,moving,x:32+(moving?8*Math.sin(t*.9):0),y:32+(moving?6*Math.sin(t*1.3):0)};
  }
  draw(time) {
    const ctx=this.canvas.getContext('2d');if(!ctx)return;
    const p=this.pose(time);
    ctx.clearRect(0,0,this.canvas.width,this.canvas.height);
    ctx.save();ctx.scale(this.canvas.width/64,this.canvas.height/64);
    // Full robot inside the selected mint capsule; glyphs disappear underneath it.
    if(p.moving){
      const letters=['A','ß','é','λ','ñ'];
      ctx.font='8px system-ui';ctx.textAlign='center';ctx.textBaseline='middle';
      for(let i=0;i<letters.length;i++){
        const phase=(p.t*.5+i/letters.length)%1,angle=i*1.22+1.7,radius=27-13*phase;
        ctx.fillStyle=`rgba(148,240,201,${.9*Math.sin(Math.PI*phase)})`;
        ctx.fillText(letters[i],p.x+Math.cos(angle)*radius,p.y+Math.sin(angle)*radius);
      }
    }
    ctx.translate(p.x,p.y);
    const radius=17;
    const brush=(x,y,spin)=>{
      ctx.save();ctx.translate(x,y);ctx.rotate(spin);
      ctx.strokeStyle='#94f0c9';ctx.lineWidth=1.4;ctx.lineCap='round';ctx.beginPath();
      for(let arm=0;arm<3;arm++){
        const angle=arm*Math.PI*2/3;
        ctx.moveTo(0,0);ctx.lineTo(Math.cos(angle)*5,Math.sin(angle)*5);
      }
      ctx.stroke();ctx.restore();
    };
    brush(-radius*.72,radius*.7,p.t*6);brush(radius*.72,radius*.7,-p.t*6);
    const finish=ctx.createLinearGradient(-radius,-radius,radius,radius);
    finish.addColorStop(0,'#42876e');finish.addColorStop(1,'#173d30');
    ctx.fillStyle=finish;ctx.strokeStyle='#94f0c9';ctx.lineWidth=1.5;
    ctx.beginPath();ctx.arc(0,0,radius,0,Math.PI*2);ctx.fill();ctx.stroke();
    ctx.strokeStyle='rgba(148,240,201,.22)';ctx.lineWidth=1;
    ctx.beginPath();ctx.arc(0,0,radius-3,0,Math.PI*2);ctx.stroke();
    ctx.fillStyle='#94f0c9';ctx.beginPath();ctx.arc(0,0,radius*.25,0,Math.PI*2);ctx.fill();
    ctx.beginPath();ctx.roundRect(-3,-radius*.7,6,2,1);ctx.fill();
    ctx.beginPath();ctx.arc(-radius*.5,-radius*.45,1.3,0,Math.PI*2);ctx.fill();
    ctx.restore();
  }
  dispose(){
    this.disposed=true;if(this.frame)cancelAnimationFrame(this.frame);this.frame=0;
    document.removeEventListener('visibilitychange',this.visibility);
    this.motion.removeEventListener('change',this.visibility);
  }
};