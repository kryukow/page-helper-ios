/* Tokens never enter JavaScript or a webpage; only native code talks to OpenAI. */

browser.runtime.onMessage.addListener((message, sender) => {
  if (!sender.id || sender.id !== browser.runtime.id) return Promise.reject(Error('Unknown sender'));
  if (message.action === 'translate') {
    if (!sender.tab || !/^https?:/.test(sender.tab.url || '') || !Array.isArray(message.segments) || message.segments.length > 30) {
      return Promise.reject(Error('Invalid translation request'));
    }
  } else if (message.action !== 'status') return undefined;
  return browser.runtime.sendNativeMessage('com.kryukov.plustranslate', message).then(response => response?.message ?? response);
});
