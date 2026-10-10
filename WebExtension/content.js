(() => {
  if (globalThis.__plusTranslateInstalled) return;
  globalThis.__plusTranslateInstalled = true;
  const originals = new Map(), cache = new Map();
  let busy = false, translated = false, progress = {done: 0, total: 0, errors: 0}, generation = 0;
  const excluded = 'script,style,noscript,pre,code,textarea,input,select,[contenteditable],[translate="no"],[data-plus-translate-ui]';
  const slots = element => {
    const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT);
    const list = []; let node;
    while ((node = walker.nextNode())) if (node.data.trim()) list.push(node);
    return list;
  };
  const shape = element => [...element.querySelectorAll('*')].map(node => [node.tagName,[...node.attributes].map(a => [a.name,a.value]).sort()]);
  function candidates() {
    const list = [], seen = new Set();
    const eligible = e => !e.closest(excluded) && !e.querySelector(excluded) && e.getClientRects().length && e.textContent.trim().length >= 2 && e.innerHTML.length <= 7000;
    const add = e => { if (eligible(e) && ![...seen].some(p => p.contains(e) || e.contains(p))) { list.push(e); seen.add(e); } };
    document.querySelectorAll('p,h1,h2,h3,h4,h5,h6,li,td,th,button,label,figcaption').forEach(e => {
      if (!e.querySelector('p,h1,h2,h3,h4,h5,h6,li,td,th,button,label,figcaption')) add(e);
    });
    document.querySelectorAll('a,span,div').forEach(e => { if (!e.children.length || [...e.children].every(c => ['B','STRONG','I','EM','SMALL','BR'].includes(c.tagName))) add(e); });
    return list;
  }
  function apply(element, html, originalHTML) {
    if (!element.isConnected || element.innerHTML !== originalHTML) return false;
    const template = document.createElement('template'); template.innerHTML = html;
    const holder = document.createElement('div'); holder.append(template.content);
    if (JSON.stringify(shape(element)) !== JSON.stringify(shape(holder))) return false;
    const before = slots(element), after = slots(holder);
    if (before.length !== after.length) return false;
    const snapshot = before.map(n => ({node:n, original:n.data, translation:after[before.indexOf(n)].data}));
    originals.set(element, snapshot);
    for (const item of snapshot) item.node.data = item.translation;
    return true;
  }
  function restore() {
    generation++;
    for (const snapshot of originals.values()) for (const item of snapshot) {
      if (item.node.isConnected && item.node.data === item.translation) item.node.data = item.original;
    }
    originals.clear(); translated = false; renderButton();
  }
  async function translate() {
    if (busy) return {busy, progress};
    if (translated) return {translated, progress};
    const elements = candidates(), batches = [];let group=[], size=0;
    for (const element of elements) {
      const html = element.innerHTML;
      if (group.length >= 12 || size + html.length > 3500) { if(group.length)batches.push(group);group=[];size=0; }
      group.push({element,html});size += html.length;
    }
    if(group.length)batches.push(group);
    busy=true;progress={done:0,total:elements.length,errors:0};renderButton();const current=++generation;
    try {
      let next=0;
      async function worker() {
        while(next<batches.length && current===generation) {
          const batch=batches[next++];
          const missing=batch.filter(item=>!cache.has(item.html));
          if(missing.length) {
            let response;
            for(let attempt=0;attempt<2;attempt++) {
              response=await browser.runtime.sendMessage({action:'translate',segments:missing.map(b=>b.html)});
              response=response?.message ?? response;
              if(response?.error)throw Error(response.error);
              if(Array.isArray(response?.translations)&&response.translations.length===missing.length&&response.translations.every(v=>typeof v==='string'))break;
              response=null;
            }
            if(!response)throw Error('Расширение не вернуло перевод. Попробуй снова.');
            if(current!==generation)return;
            missing.forEach((item,i)=>cache.set(item.html,response.translations[i]));

            batch.forEach(item=>{const html=cache.get(item.html) ?? response.translations[missing.indexOf(item)];if(typeof html==='string'&&apply(item.element,html,item.html))progress.done++;else progress.errors++;});
          } else {
            batch.forEach(item=>{if(apply(item.element,cache.get(item.html),item.html))progress.done++;else progress.errors++;});
          }
          translated=originals.size>0;renderButton();
        }
      }
      // Two requests overlap; cancellation prevents late writes after restore/errors.
      const jobs=await Promise.allSettled([worker(),worker()]);
      const failed=jobs.find(job=>job.status==='rejected');
      if(failed)throw failed.reason;
      return {translated,progress};
    } finally {busy=false;if(cache.size>500)cache.clear();renderButton();}
  }
  // Isolated styles keep the page layout and the button independent.
  const host = document.createElement('div');
  host.setAttribute('data-plus-translate-ui', '');
  host.style.cssText = 'all:initial!important;position:fixed!important;right:-10px!important;top:55%!important;z-index:2147483647!important;display:block!important;';
  const shadow = host.attachShadow({mode:'closed'});
  shadow.innerHTML = `<style>
    button{box-sizing:border-box;width:54px;height:44px;padding:6px 12px 6px 6px;border:0;border-radius:24px 0 0 24px;background:rgba(30,67,60,.62);color:#e0fff0;box-shadow:0 2px 8px #0002;font:600 14px system-ui;cursor:pointer;touch-action:none}
    button:disabled{opacity:.85;cursor:progress}button:focus-visible{outline:3px solid #fff}
    .error{position:absolute;right:16px;top:50px;width:230px;padding:12px;border-radius:12px;background:#182522;color:white;font:14px system-ui;box-shadow:0 3px 14px #0005}
  </style><button type="button" aria-label="Перевести страницу">A↔Я</button><div class="error" role="alert" hidden></div>`;
  const button = shadow.querySelector('button'), error = shadow.querySelector('.error');
  function renderButton() {
    button.disabled=busy;
    button.textContent=busy ? `${progress.total?Math.round(progress.done/progress.total*100):0}%` : translated ? '↶' : 'A↔Я';
    const label=busy ? `Перевожу: ${progress.done} из ${progress.total}` : translated ? 'Показать оригинал' : 'Перевести страницу';
    button.setAttribute('aria-label', label);button.title=label;
    error.textContent=progress.error || '';error.hidden=!progress.error;
  }
  let pointer=null, suppressClick=false;
  button.addEventListener('pointerdown', e=>{
    pointer={id:e.pointerId,x:e.clientX,y:e.clientY,top:host.getBoundingClientRect().top,moved:false};
    button.setPointerCapture(e.pointerId);
  });
  button.addEventListener('pointermove', e=>{
    if(!pointer || pointer.id!==e.pointerId)return;
    if(Math.hypot(e.clientX-pointer.x,e.clientY-pointer.y)>8)pointer.moved=true;
    if(pointer.moved)host.style.setProperty('top', `${Math.max(8,Math.min(innerHeight-64,pointer.top+e.clientY-pointer.y))}px`, 'important');
  });
  button.addEventListener('pointerup',()=>{suppressClick=Boolean(pointer?.moved);pointer=null;});
  button.addEventListener('pointercancel',()=>{pointer=null;suppressClick=true;});
  button.addEventListener('click',()=>{
    if(suppressClick){suppressClick=false;return;}
    if(busy)return;
    if(translated){restore();progress.error=null;renderButton();}
    else translate().catch(e=>{progress.error=e.message;renderButton();});
  });
  document.documentElement.append(host);
  renderButton();
  browser.runtime.onMessage.addListener(message => {
    if(message.action==='pageStatus')return Promise.resolve({busy,translated,progress});
    if(message.action==='restore'){restore();return Promise.resolve({translated:false,progress});}
    if(message.action==='translatePage'){
      // Reply immediately; closing the popup must not stop translation.
      translate().catch(e=>{progress.error=e.message;renderButton();});return Promise.resolve({started:true});
    }
  });
})();
