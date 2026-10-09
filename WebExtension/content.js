(() => {
  if (globalThis.__plusTranslateInstalled) return;
  globalThis.__plusTranslateInstalled = true;
  const originals = new Map();
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
    originals.clear(); translated = false;
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
    busy=true;progress={done:0,total:elements.length,errors:0};const current=++generation;
    try {
      for (const batch of batches) {
        if(current!==generation)break;
        const response = await browser.runtime.sendMessage({action:'translate',segments:batch.map(b=>b.html)});
        if(current!==generation)break;
        if(response?.error)throw Error(response.error);
        if(!Array.isArray(response?.translations)||response.translations.length!==batch.length)throw Error('Неверная структура ответа.');
        batch.forEach((item,index)=>{if(apply(item.element,response.translations[index],item.html))progress.done++;else progress.errors++;});
        translated=originals.size>0;
      }
      return {translated,progress};
    } finally {busy=false;}
  }
  browser.runtime.onMessage.addListener(message => {
    if(message.action==='pageStatus')return Promise.resolve({busy,translated,progress});
    if(message.action==='restore'){restore();return Promise.resolve({translated:false,progress});}
    if(message.action==='translatePage'){
      // Reply immediately; closing the popup must not stop translation.
      translate().catch(e=>{progress.error=e.message;});return Promise.resolve({started:true});
    }
  });
})();
