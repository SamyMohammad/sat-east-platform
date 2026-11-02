// App origin for every link into the Flutter app. Change it here when the
// production domain is decided (docs Q-01); links keep working without JS.
const APP_ORIGIN = 'https://sat-prod.pages.dev';

for (const link of document.querySelectorAll('[data-app]')) {
  link.href = APP_ORIGIN + link.dataset.app;
}

// The method path's rail fills as the list scrolls through the viewport.
const path = document.querySelector('[data-path]');
const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
if (path && !reduceMotion.matches) {
  let frame = 0;
  const update = () => {
    frame = 0;
    const rect = path.getBoundingClientRect();
    const start = window.innerHeight * 0.75;
    const progress = (start - rect.top) / rect.height;
    path.style.setProperty('--progress', Math.min(1, Math.max(0, progress)).toFixed(3));
  };
  const onScroll = () => { if (!frame) frame = requestAnimationFrame(update); };
  update();
  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', onScroll);
}

// Sample question. Original item; feedback in the teacher's voice.
const form = document.querySelector('[data-question]');
if (form) {
  const CORRECT = 'D';
  const feedback = {
    A: 'Close. 6 is <i>x</i>, but the question asks for 6<i>x</i>. Multiply once more.',
    B: 'Right so far: 3<i>x</i> = 18. But the question asks for 6<i>x</i>, so double it.',
    C: 'Careful: you doubled only part of the equation. Double every term, including the 7, then read off 6<i>x</i>.',
  };
  const button = form.querySelector('button');
  const status = form.querySelector('.q__feedback');
  const start = form.querySelector('.q__foot [data-app]');
  let checked = false;

  form.addEventListener('change', () => {
    if (checked) reset();
    button.disabled = false;
  });

  form.addEventListener('submit', (event) => {
    event.preventDefault();
    const picked = form.querySelector('input:checked');
    if (!picked) return;
    if (checked) { resetAll(); return; }
    checked = true;
    const choice = picked.closest('.q__choice');
    const right = picked.value === CORRECT;
    choice.classList.add(right ? 'is-correct' : 'is-incorrect');
    choice.insertAdjacentHTML('beforeend', `<span class="q__verdict"><svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path d="${right ? 'M5 12.5l4.5 4.5L19 7.5' : 'M7 7l10 10M17 7L7 17'}" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>${right ? 'Correct' : 'Not quite'}</span>`);
    status.innerHTML = right
      ? '<b>Correct.</b> 3<i>x</i> = 18, and 6<i>x</i> is twice that: 36. Spotting that you never need <i>x</i> itself saves time on test day.'
      : `<b>Not quite.</b> ${feedback[picked.value]}`;
    button.textContent = 'Try again';
    start.hidden = !right;
    button.classList.toggle('btn--dark', !right);
    button.classList.toggle('btn--quiet', right);
  });

  function reset() {
    checked = false;
    for (const el of form.querySelectorAll('.q__choice')) el.classList.remove('is-correct', 'is-incorrect');
    for (const el of form.querySelectorAll('.q__verdict')) el.remove();
    status.textContent = '';
    button.textContent = 'Check';
    start.hidden = true;
    button.classList.add('btn--dark');
    button.classList.remove('btn--quiet');
  }

  function resetAll() {
    reset();
    for (const input of form.querySelectorAll('input')) input.checked = false;
    button.disabled = true;
    form.querySelector('input').focus();
  }
}
