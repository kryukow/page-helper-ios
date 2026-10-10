/* Tokens remain in native code. Only translated text and a random request ID cross this boundary. */
const native = async message => {
  const response = await browser.runtime.sendNativeMessage('com.kryukov.plustranslate',message);
  const data=response?.message??response;
  if(data?.error)throw Error(data.error);
  return data;
};
const isPage=sender=>sender.id===browser.runtime.id&&sender.tab&&/^https?:/.test(sender.url||sender.tab.url||'');
browser.runtime.onMessage.addListener((message,sender)=>{
  if(sender.id!==browser.runtime.id)return Promise.reject(Error('Unknown sender'));
  if(message.action==='getButtonPosition')return browser.storage.local.get('buttonPosition').then(({buttonPosition})=>({position:Number.isFinite(buttonPosition)?buttonPosition:null}));
  if(message.action==='setButtonPosition'){
    if(!Number.isFinite(message.position)||message.position<0||message.position>1)return Promise.reject(Error('Invalid position'));
    return browser.storage.local.set({buttonPosition:message.position}).then(()=>({saved:true}));
  }
  if(message.action==='status')return native({action:'status'});
  if(message.action==='translate'&&isPage(sender))return native(message);
  return undefined;
});
browser.runtime.onConnect.addListener(port=>{
  if(port.name!=='page-helper-stream'||!isPage(port.sender)){port.disconnect();return;}
  const id=crypto.randomUUID();let started=false,closed=false,finished=false;
  const cancel=()=>{if(!finished)native({action:'streamCancel',id}).catch(()=>{});};
  port.onDisconnect.addListener(()=>{closed=true;cancel();});
  port.onMessage.addListener(message=>{
    if(message.type==='cancel'){closed=true;cancel();return;}
    if(started||message.type!=='translate')return;started=true;
    (async()=>{
      const segments=message.segments;
      if(!Array.isArray(segments)||!segments.length||segments.length>30||!segments.every(s=>typeof s==='string'&&s.length&&new TextEncoder().encode(s).length<=20000))throw Error('Некорректный блок страницы.');
      const parser=new TextArrayStream(segments.length);let previous='';
      const publish=output=>{
        if(typeof output!=='string'||!output.startsWith(previous))throw Error('Перевод прервался. Попробуй ещё раз.');
        const updates=parser.append(output.slice(previous.length));previous=output;
        for(const update of updates)if(!closed)port.postMessage({type:'update',...update});
      };
      let result=null,error=null,complete=false;
      const running=native({action:'streamStart',id,segments}).then(value=>{result=value;complete=true;},failure=>{error=failure;complete=true;});
      const deadline=Date.now()+120000;
      while(!closed&&!complete){
        const snapshot=await native({action:'streamPoll',id});
        if(typeof snapshot.output==='string')publish(snapshot.output);
        if(Date.now()>deadline)throw Error('Время ожидания перевода истекло.');
        if(!complete&&!closed)await new Promise(resolve=>setTimeout(resolve,100));
      }
      if(closed)return;
      await running;if(error)throw error;
      if(!Array.isArray(result?.translations)||result.translations.length!==segments.length||!result.translations.every(s=>typeof s==='string'))throw Error('Перевод не завершён.');
      // Native completion is authoritative, including when the last poll races with completion.
      result.translations.forEach((text,index)=>port.postMessage({type:'update',index,text,complete:true}));
      finished=true;port.postMessage({type:'done',translations:result.translations});
    })().catch(error=>{cancel();if(!closed)try{port.postMessage({type:'error',error:error.message});}catch{}});
  });
});
