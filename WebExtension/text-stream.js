// Decode only complete JSON characters; quotes, newlines and escapes never leak into the page.
globalThis.TextArrayStream = class TextArrayStream {
  constructor(count) { this.count=count;this.buffer='';this.at=0;this.state='start';this.index=-1;this.text='';this.values=[]; }
  append(delta) {
    this.buffer+=delta;
    if(new TextEncoder().encode(this.buffer).length>200000)throw Error('Ответ перевода слишком большой.');
    const updates=[];let changed=false;
    const flush=complete=>{if(changed||complete){updates.push({index:this.index,text:this.text,complete});changed=false;}};
    while(this.at<this.buffer.length){
      const c=this.buffer[this.at];
      if(this.state==='string'){
        if(c==='"'){this.at++;flush(true);this.values.push(this.text);this.state='separator';continue;}
        if(c==='\\'){
          if(this.at+1>=this.buffer.length)break;
          const escape=this.buffer[this.at+1];
          if(escape==='u'){
            if(this.at+6>this.buffer.length)break;
            const hex=this.buffer.slice(this.at+2,this.at+6);if(!/^[a-f0-9]{4}$/i.test(hex))throw Error('Некорректный ответ перевода.');
            const unit=parseInt(hex,16);
            if(unit>=0xd800&&unit<=0xdbff){
              if(this.at+12>this.buffer.length)break;
              const next=this.buffer.slice(this.at+6,this.at+12);
              if(!/^\\u[dD][c-fC-F][a-fA-F0-9]{2}$/.test(next))throw Error('Некорректный символ перевода.');
              this.text+=String.fromCharCode(unit,parseInt(next.slice(2),16));this.at+=12;
            }else{this.text+=String.fromCharCode(unit);this.at+=6;}
          }else{
            const escapes={'"':'"','\\':'\\','/':'/','b':'\b','f':'\f','n':'\n','r':'\r','t':'\t'};
            if(!(escape in escapes))throw Error('Некорректный ответ перевода.');this.text+=escapes[escape];this.at+=2;
          }
          changed=true;continue;
        }
        if(c.charCodeAt(0)<32)throw Error('Некорректный ответ перевода.');
        // A UTF-16 surrogate pair can be split between two SSE deltas.
        const code=c.charCodeAt(0);
        if(code>=0xd800&&code<=0xdbff){if(this.at+1>=this.buffer.length)break;this.text+=this.buffer.slice(this.at,this.at+2);this.at+=2;}
        else{this.text+=c;this.at++;}
        changed=true;continue;
      }
      if(/\s/.test(c)){this.at++;continue;}
      if(this.state==='start'&&c==='['){this.at++;this.state='value';continue;}
      if(this.state==='value'&&c==='"'){
        if(++this.index>=this.count)throw Error('Модель изменила число строк.');
        this.at++;this.text='';this.state='string';continue;
      }
      if(this.state==='separator'&&c===','){this.at++;this.state='value';continue;}
      if((this.state==='separator'||(this.state==='value'&&this.index===-1))&&c===']'){this.at++;this.state='done';continue;}
      throw Error('Модель не сохранила структуру перевода. Попробуй ещё раз.');
    }
    flush(false);return updates;
  }
  finish() {
    if(this.state!=='done'||this.values.length!==this.count)throw Error('Перевод прервался. Попробуй ещё раз.');
    const parsed=JSON.parse(this.buffer);
    if(!Array.isArray(parsed)||parsed.length!==this.count||!parsed.every((s,i)=>typeof s==='string'&&s===this.values[i]))throw Error('Некорректный ответ перевода.');
    return parsed;
  }
}
