(() => {
  const body = document.body;
  if (body.querySelector('img,svg,canvas,video,audio,object,embed,iframe')) {
    throw new Error('Ce contenu contient des médias. md2notes conserve votre original.');
  }
  body.querySelectorAll('input[type="checkbox"]').forEach(n => n.replaceWith(document.createTextNode(n.checked ? '☑ ' : '☐ ')));
  body.querySelectorAll('script,style,link,meta,base,form,input,button').forEach(n => n.remove());
  for (const el of body.querySelectorAll('*')) {
    for (const attr of [...el.attributes]) {
      if (/^on/i.test(attr.name) || ['src','srcset','background'].includes(attr.name)) el.removeAttribute(attr.name);
    }
    if (/url\s*\(|expression\s*\(|@import/i.test(el.getAttribute('style') || '')) el.removeAttribute('style');
    if (el.tagName === 'A' && !/^(https?:|mailto:|tel:|#)/i.test(el.getAttribute('href') || '')) el.removeAttribute('href');
  }
  const blockTags = new Set(['P','H1','H2','H3','H4','H5','H6','UL','OL','TABLE','PRE','HR']);
  const protectedTags = new Set(['UL','OL','TABLE','PRE']);
  // Turn bare text/inline runs in containers into paragraphs; do not split protected content.
  function normalize(parent) {
    let run = [];
    function flush() {
      if (!run.length) return;
      if (run.some(n => (n.textContent || '').trim())) {
        const p = document.createElement('p');
        parent.insertBefore(p, run[0]);
        run.forEach(n => p.appendChild(n));
      }
      run = [];
    }
    for (const node of [...parent.childNodes]) {
      if (node.nodeType === Node.ELEMENT_NODE && (blockTags.has(node.tagName) || ['DIV','SECTION','ARTICLE','BLOCKQUOTE','MAIN'].includes(node.tagName))) {
        flush();
        if (!blockTags.has(node.tagName)) normalize(node);
      } else run.push(node);
    }
    flush();
  }
  normalize(body);
  const blocks = [];
  function visit(parent) {
    for (const el of parent.children) {
      if (blockTags.has(el.tagName)) blocks.push(el);
      else visit(el);
    }
  }
  visit(body);
  const blank = el => !protectedTags.has(el.tagName) && el.tagName !== 'HR' && !(el.textContent || '').replace(/[\s\u00a0\u200b]/g, '');
  while (blocks.length && blank(blocks[0])) blocks.shift().remove();
  while (blocks.length && blank(blocks[blocks.length - 1])) blocks.pop().remove();
  let previous = null;
  let gap = false;
  let added = 0;
  for (const el of blocks) {
    el.style.marginTop = '0';
    el.style.marginBottom = '0';
    if (blank(el)) { gap = true; continue; }
    if (previous && !gap) {
      const p = document.createElement('p');
      p.setAttribute('data-md2notes-gap', '1');
      p.style.cssText = 'margin:0;font-size:16px;';
      p.textContent = '\u00a0';
      el.parentNode.insertBefore(p, el);
      added++;
    }
    previous = el;
    gap = false;
  }
  body.style.cssText = 'font-family:Helvetica,Arial,sans-serif;font-size:16px;';
  return { html: '<!doctype html><html><head><meta charset="utf-8"></head><body style="font-family:Helvetica,Arial,sans-serif;font-size:16px;">' + body.innerHTML + '</body></html>', added };
})();
