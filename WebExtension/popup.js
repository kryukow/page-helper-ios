let tab;
const status = document.querySelector('#status');
const flow = new PageHelperPaper(document.querySelector('#mint-mark'));

async function refresh() {
  try {
    const native = await browser.runtime.sendMessage({action:'status'});
    if(native?.error)throw Error(native.error);
    if(!native?.connected){flow.setBusy(false, false);status.textContent='Открой Page Helper и войди через ChatGPT.';return;}
    const page = await browser.tabs.sendMessage(tab.id,{action:'pageStatus'});
    flow.setBusy(Boolean(page.busy), Boolean(page.translated && !page.busy));
    status.textContent=page.progress.error || (page.busy?'Перевожу: ':page.translated?'Переведено: ':'Готово к переводу. ')+(page.progress.total?`${page.progress.done}/${page.progress.total}`:'');
    if(page.progress.errors)status.textContent+=`. Не изменено: ${page.progress.errors}`;
  } catch(e) {status.textContent=e.message;}
}
document.querySelector('#translate').onclick=async()=>{try{await browser.tabs.sendMessage(tab.id,{action:'translatePage'});await refresh();}catch(e){status.textContent=e.message;}};
document.querySelector('#restore').onclick=async()=>{try{await browser.tabs.sendMessage(tab.id,{action:'restore'});await refresh();}catch(e){status.textContent=e.message;}};
(async()=>{[tab]=await browser.tabs.query({active:true,currentWindow:true});await refresh();setInterval(refresh,1200);})();
