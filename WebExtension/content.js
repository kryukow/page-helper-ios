(() => {
  if (globalThis.__plusTranslateInstalled) return;
  globalThis.__plusTranslateInstalled = true;
  const originals = new Map(), cache = new Map(), ports = new Map();
  let activeModel='', busy=false, translated=false, generation=0;
  let progress={done:0,total:0,errors:0};
  const excluded='script,style,noscript,pre,code,textarea,input,select,svg,math,iframe,[hidden],[inert],[contenteditable],[translate="no"],[aria-hidden="true"],[data-plus-translate-ui]';
  function candidates() {
    const visible=new WeakMap();
    function isVisible(element){
      if(!element)return true;if(visible.has(element))return visible.get(element);
      const style=getComputedStyle(element);
      const result=style.display!=='none'&&style.visibility!=='hidden'&&style.visibility!=='collapse'&&style.contentVisibility!=='hidden'&&Number(style.opacity)!==0&&isVisible(element.parentElement);
      visible.set(element,result);return result;
    }
    const nodes=[],walker=document.createTreeWalker(document.body||document.documentElement,NodeFilter.SHOW_TEXT);let node;
    while((node=walker.nextNode())){
      const parent=node.parentElement;
      if(!parent||parent.closest(excluded)||!parent.getClientRects().length||!isVisible(parent)||!/[\p{L}]/u.test(node.data)||new TextEncoder().encode(node.data).length>20000)continue;
      nodes.push({node,original:node.data});
    }
    return nodes;
  }
  function write(item,text,complete=false) {
    const saved=originals.get(item.node);
    if(!item.node.isConnected||item.node.data!==(saved?saved.translation:item.original))return false;
    const prefix=item.original.match(/^\s*/)[0],suffix=item.original.match(/\s*$/)[0];
    const translation=prefix+(complete?text.trim():text.trimStart())+(complete?suffix:'');
    originals.set(item.node,{original:item.original,translation});item.node.data=translation;return true;
  }
  function rollback(items) {
    for(const item of items){const saved=originals.get(item.node);if(saved){if(item.node.isConnected&&item.node.data===saved.translation)item.node.data=saved.original;originals.delete(item.node);}}
  }
  function restore() {
    generation++;
    for(const [port,cancel] of [...ports]){try{port.postMessage({type:'cancel'});}catch{}cancel();}
    ports.clear();
    for(const [node,saved] of originals){if(node.isConnected&&node.data===saved.translation)node.data=saved.original;}
    originals.clear();busy=false;translated=false;progress={done:0,total:0,errors:0};renderButton();
  }
  function streamBatch(items,current) {
    return new Promise((resolve,reject)=>{
      const port=browser.runtime.connect({name:'page-helper-stream'});let finished=false,timer;
      const deadline=setTimeout(()=>fail(Error('Safari не завершил перевод вовремя. Попробуй ещё раз.')),65000);
      const arm=()=>{clearTimeout(timer);timer=setTimeout(()=>fail(Error('Перевод перестал отвечать. Попробуй ещё раз.')),30000);};
      const cleanup=()=>{clearTimeout(timer);clearTimeout(deadline);};
      const fail=error=>{if(finished)return;finished=true;cleanup();rollback(items);ports.delete(port);port.disconnect();reject(error);};
      ports.set(port,()=>fail(Error('Перевод отменён.')));
      port.onDisconnect.addListener(()=>{if(!finished)fail(Error(current===generation?'Перевод прервался. Попробуй ещё раз.':'Перевод отменён.'));});
      port.onMessage.addListener(event=>{
        if(finished)return;arm();
        if(current!==generation){fail(Error('Перевод отменён.'));return;}
        if(event.type==='error'){fail(Error(event.error||'Не удалось перевести.'));return;}
        if(event.type==='update'){
          if(!Number.isInteger(event.index)||event.index<0||event.index>=items.length||typeof event.text!=='string'){fail(Error('Некорректный поток перевода.'));return;}
          // Reveal completed text fragments together, without character-by-character typing.
          if(event.complete){write(items[event.index],event.text,true);translated=originals.size>0;renderButton();}
        }
        if(event.type==='done'){
          if(!Array.isArray(event.translations)||event.translations.length!==items.length||!event.translations.every(s=>typeof s==='string')){fail(Error('Перевод не завершён.'));return;}
          event.translations.forEach((text,i)=>{cache.set(items[i].original,text);if(write(items[i],text,true))progress.done++;else progress.errors++;});
          finished=true;cleanup();ports.delete(port);port.disconnect();translated=originals.size>0;renderButton();resolve();
        }
      });
      arm();port.postMessage({type:'translate',segments:items.map(item=>item.original)});
    });
  }
  async function translate() {
    if(busy)return {busy,progress};if(translated)return {translated,progress};
    busy=true;progress={done:0,total:0,errors:0};renderButton();const current=++generation;
    try{
      let statusTimer;let status;
      try{status=await Promise.race([browser.runtime.sendMessage({action:'status'}),new Promise((_,reject)=>{statusTimer=setTimeout(()=>reject(Error('Safari не отвечает. Обнови вкладку и попробуй снова.')),10000);})]);}finally{clearTimeout(statusTimer);}
      if(status?.error)throw Error(status.error);if(!status?.connected)throw Error('Открой Page Helper и войди через ChatGPT.');
      if(current!==generation)return;
      if(activeModel!==status.model){cache.clear();activeModel=status.model;}
      const items=candidates(),batches=[];let group=[],size=0;progress.total=items.length;
      for(const item of items){const bytes=new TextEncoder().encode(item.original).length;if(group.length>=16||size+bytes>4500){if(group.length)batches.push(group);group=[];size=0;}group.push(item);size+=bytes;}
      if(group.length)batches.push(group);let next=0;renderButton();
      async function worker(){
        while(next<batches.length&&current===generation){
          const batch=batches[next++],missing=[];
          for(const item of batch){if(cache.has(item.original)){if(write(item,cache.get(item.original),true))progress.done++;else progress.errors++;}else missing.push(item);}
          if(missing.length)await streamBatch(missing,current);translated=originals.size>0;renderButton();
        }
      }
      const jobs=await Promise.allSettled([worker(),worker()]);
      const failed=jobs.find(job=>job.status==='rejected');if(failed&&current===generation)throw failed.reason;
      return {translated,progress};
    }catch(error){if(current!==generation)return {translated,progress};throw error;}finally{if(current===generation){busy=false;translated=originals.size>0;if(cache.size>500)cache.clear();renderButton();}}
  }
  // Isolated styles keep the page layout and the button independent.
  const host = document.createElement('div');
  host.setAttribute('data-plus-translate-ui', '');
  host.style.cssText = 'all:initial!important;position:fixed!important;right:-8.5px!important;top:55%!important;z-index:2147483647!important;display:block!important;';
  const shadow = host.attachShadow({mode:'closed'});
  shadow.innerHTML = `<style>
    button{box-sizing:border-box;display:flex;align-items:center;justify-content:center;width:54.4px;height:42.5px;padding:0 8.5px 0 0;border:0;border-radius:22.1px 0 0 22.1px;background:rgba(33,75,64,.90);opacity:.55;color:#e0fff0;box-shadow:0 3px 12px #0002;font:600 14px system-ui;cursor:pointer;touch-action:none}
    button:disabled{opacity:.85;cursor:progress}canvas{display:block;width:34px;height:34px;margin:0;pointer-events:none}button.translated{background:rgba(18,107,82,.90)}button.translated canvas{opacity:1}button:focus-visible{outline:3px solid #fff}
    .error{position:absolute;right:16px;top:50px;width:230px;padding:12px;border-radius:12px;background:#182522;color:white;font:14px system-ui;box-shadow:0 3px 14px #0005}
  </style><button type="button" aria-label="Перевести страницу"><canvas width="128" height="128" aria-hidden="true"></canvas></button><div class="error" role="alert" hidden></div>`;
  const button = shadow.querySelector('button'), error = shadow.querySelector('.error');
  const paper = new PageHelperPaper(shadow.querySelector('canvas'));
  function renderButton() {
    button.disabled=false;
    paper.setBusy(busy, translated && !busy);
    button.classList.toggle('translated',translated && !busy);
    const label=busy ? `Остановить перевод (${progress.done} из ${progress.total})` : translated ? 'Показать оригинал' : 'Перевести страницу';
    button.setAttribute('aria-label', label);button.title=label;
    error.textContent=progress.error || '';error.hidden=!progress.error;
  }
  let pointer=null, suppressClick=false, position=null, positionChanged=false;
  const positionRange=()=>Math.max(0,innerHeight-58.5);
  function applyPosition(){if(position!==null)host.style.setProperty('top', `${8+position*positionRange()}px`, 'important');}
  function savePosition(){
    positionChanged=true;
    position=Math.max(0,Math.min(1,(host.getBoundingClientRect().top-8)/Math.max(1,positionRange())));
    browser.runtime.sendMessage({action:'setButtonPosition',position}).catch(()=>{});
  }
  window.addEventListener('resize',()=>{if(!pointer)applyPosition();});
  browser.runtime.sendMessage({action:'getButtonPosition'}).then(data=>{
    if(!positionChanged&&Number.isFinite(data?.position)&&data.position>=0&&data.position<=1){position=data.position;applyPosition();}
  }).catch(()=>{});
  button.addEventListener('pointerdown', e=>{
    pointer={id:e.pointerId,x:e.clientX,y:e.clientY,top:host.getBoundingClientRect().top,moved:false};
    button.setPointerCapture(e.pointerId);
  });
  button.addEventListener('pointermove', e=>{
    if(!pointer || pointer.id!==e.pointerId)return;
    if(Math.hypot(e.clientX-pointer.x,e.clientY-pointer.y)>8)pointer.moved=true;
    if(pointer.moved)host.style.setProperty('top', `${Math.max(8,Math.min(innerHeight-50.5,pointer.top+e.clientY-pointer.y))}px`, 'important');
  });
  button.addEventListener('pointerup',()=>{suppressClick=Boolean(pointer?.moved);if(pointer?.moved)savePosition();pointer=null;});
  button.addEventListener('pointercancel',()=>{if(pointer?.moved)savePosition();pointer=null;suppressClick=true;});
  button.addEventListener('click',()=>{
    if(suppressClick){suppressClick=false;return;}
    if(busy){restore();return;}
    if(translated){restore();progress.error=null;renderButton();}
    else translate().catch(e=>{progress.error=e.message;renderButton();});
  });
  document.documentElement.append(host);
  renderButton();
  browser.runtime.onMessage.addListener(message=>{
    if(message.action==='pageStatus')return Promise.resolve({busy,translated,progress});
    if(message.action==='restore'){restore();return Promise.resolve({translated:false,progress});}
    if(message.action==='translatePage'){translate().catch(e=>{progress.error=e.message;renderButton();});return Promise.resolve({started:true});}
  });
})();
