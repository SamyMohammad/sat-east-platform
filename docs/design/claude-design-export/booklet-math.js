// Booklet math renderer: Markdown-lite + LaTeX \( \) inline, glued punctuation, RTL-safe isolates, operator-wrapping blocks.
(function () {
  const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const md = s => esc(s).replace(/\*\*(.+?)\*\*/g, '<b>$1</b>');
  const tex = (t, display) => { try { return window.katex.renderToString(t, { throwOnError: false, displayMode: !!display }); } catch (e) { return esc(t); } };
  function inline(src) {
    const parts = []; const re = /\\\((.+?)\\\)/g; let last = 0, m;
    while ((m = re.exec(src))) { parts.push({ t: src.slice(last, m.index) }); parts.push({ m: m[1] }); last = re.lastIndex; }
    parts.push({ t: src.slice(last) });
    parts.forEach((p, i) => {
      if (p.m === undefined) return;
      const prev = parts[i - 1], next = parts[i + 1]; p.pre = ''; p.post = '';
      if (prev) { const a = prev.t.match(/[(\[«"“−-]+$/); if (a) { p.pre = a[0]; prev.t = prev.t.slice(0, -a[0].length); } }
      if (next) { const b = next.t.match(/^\S+/); if (b) { p.post = b[0]; next.t = next.t.slice(b[0].length); } }
    });
    return parts.map(p => p.m === undefined ? md(p.t)
      : `<span style="white-space:nowrap">${md(p.pre)}<span dir="ltr" style="unicode-bidi:isolate">${tex(p.m)}</span>${md(p.post)}</span>`).join('');
  }
  function render(root) {
    root = root || document;
    root.querySelectorAll('[data-mix]').forEach(el => { const s = el.getAttribute('data-mix'); if (el.__mix === s) return; el.innerHTML = inline(s); el.__mix = s; });
    root.querySelectorAll('[data-tex]').forEach(el => { const s = el.getAttribute('data-tex'); if (el.__tex === s) return; el.innerHTML = tex(s, el.hasAttribute('data-block')); el.__tex = s; });
    root.querySelectorAll('[data-wrap]').forEach(el => {
      const s = el.getAttribute('data-wrap'); if (el.__w === s) return;
      el.innerHTML = s.split('||').map(p => `<span style="display:inline-block;white-space:nowrap">${tex('\\displaystyle ' + p.trim())}</span>`).join('');
      el.__w = s;
    });
  }
  window.BookletMath = { render, inline };
})();
