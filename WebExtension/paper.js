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
    return {t:moving?(time-this.started)/1000:0,moving};
  }
  draw(time) {
    const ctx=this.canvas.getContext('2d');if(!ctx)return;
    const p=this.pose(time);
    ctx.clearRect(0,0,this.canvas.width,this.canvas.height);
    ctx.save();ctx.scale(this.canvas.width/64,this.canvas.height/64);
    // The robot itself is the button: no plate, paper or semicircle behind it.
    ctx.translate(32,32);
    const brush=(x,y,phase)=>{
      ctx.save();ctx.translate(x,y);ctx.rotate(phase);
      ctx.strokeStyle='#94f0c9';ctx.lineWidth=1.6;ctx.lineCap='round';ctx.beginPath();
      for(let arm=0;arm<3;arm++){
        const angle=arm*Math.PI*2/3;
        ctx.moveTo(0,0);ctx.lineTo(Math.cos(angle)*7,Math.sin(angle)*7);
      }
      ctx.stroke();ctx.restore();
    };
    if(p.moving){
      const letters=['A','ß','é','λ','ñ','β'];
      ctx.font='6px system-ui';ctx.textAlign='center';ctx.textBaseline='middle';
      for(let i=0;i<6;i++){
        const phase=((p.t*.55+i/6)%1),angle=2.3+i*.63;
        const radius=32-12*phase;
        ctx.fillStyle=`rgba(148,240,201,${.8*Math.sin(Math.PI*phase)})`;
        ctx.fillText(letters[i],Math.cos(angle)*radius,Math.sin(angle)*radius);
      }
    }
    brush(-17,17,p.t*6);brush(17,17,-p.t*6);
    const finish=ctx.createLinearGradient(-20,-23,20,24);
    finish.addColorStop(0,'#376e5b');finish.addColorStop(1,'#17392f');
    ctx.fillStyle=finish;ctx.strokeStyle='#94f0c9';ctx.lineWidth=1.4;
    ctx.beginPath();ctx.arc(0,0,23,0,Math.PI*2);ctx.fill();ctx.stroke();
    ctx.strokeStyle='rgba(148,240,201,.2)';ctx.lineWidth=1;
    ctx.beginPath();ctx.arc(0,0,19,0,Math.PI*2);ctx.stroke();
    ctx.fillStyle='#94f0c9';ctx.beginPath();ctx.arc(0,0,6,0,Math.PI*2);ctx.fill();
    ctx.strokeStyle='rgba(10,49,36,.4)';ctx.beginPath();ctx.arc(0,0,3.5,0,Math.PI*2);ctx.stroke();
    ctx.fillStyle='#94f0c9';ctx.beginPath();ctx.roundRect(-3,-16,6,2,1);ctx.fill();
    ctx.fillStyle='rgba(148,240,201,.5)';ctx.beginPath();ctx.arc(-12,-11,1.6,0,Math.PI*2);ctx.fill();
    ctx.restore();
  }
  dispose(){
    this.disposed=true;if(this.frame)cancelAnimationFrame(this.frame);this.frame=0;
    document.removeEventListener('visibilitychange',this.visibility);
    this.motion.removeEventListener('change',this.visibility);
  }
};