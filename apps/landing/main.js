// App origin for every link into the Flutter app. Staging until the prod app
// is deployed and the domain is decided (docs Q-01); switch it here and in the
// index.html hrefs, which keep links working without JS.
const APP_ORIGIN = 'https://sat-staging.pages.dev';

for (const link of document.querySelectorAll('[data-app]')) {
  link.href = APP_ORIGIN + link.dataset.app;
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

// Motion is optional; the document always starts in its readable end state.
if (window.gsap && window.ScrollTrigger && window.SplitText && window.MotionPathPlugin) {
  const { gsap, ScrollTrigger, SplitText, MotionPathPlugin } = window;
  gsap.registerPlugin(ScrollTrigger, SplitText, MotionPathPlugin);
  const media = gsap.matchMedia();

  media.add('(prefers-reduced-motion: no-preference)', context => {
    const splits = [];
    let heroDone = false;
    let ledgerEntered = false;
    let ledgerStarted = false;

    function count(element, timeline, position = 0) {
      const value = { number: Number(element.dataset.from || 0) };
      const final = Number(element.dataset.count);
      element.setAttribute('aria-label', String(final));
      timeline.fromTo(value, { number: value.number }, {
        number: final, snap: { number: 1 }, duration: .85, ease: 'power4.out', immediateRender: false,
        onUpdate: () => { element.textContent = value.number; },
        onComplete: () => { element.textContent = final; },
      }, position);
    }

    context.add('startLedger', () => {
      if (!heroDone || !ledgerEntered || ledgerStarted) return;
      ledgerStarted = true;
      const timeline = gsap.timeline();
      document.querySelectorAll('.ledger [data-count]').forEach(element => count(element, timeline));
      timeline.from('.ledger__rule', { scaleX: 0, duration: .85, ease: 'power4.out' }, 0);
    });

    function revealLines(element, timeline, position = 0) {
      splits.push(SplitText.create(element, {
        type: 'lines', mask: 'lines', autoSplit: true,
        onSplit(self) {
          const tween = gsap.from(self.lines, {
            yPercent: 105, opacity: 0, duration: .75,
            stagger: { amount: .15 }, ease: 'expo.out',
          });
          timeline.add(tween, position);
          return tween;
        },
      }));
    }

    const hero = gsap.timeline({
      defaults: { ease: 'power4.out' },
      onComplete: () => { heroDone = true; context.startLedger(); },
    });
    hero.from('.hero__grid', { opacity: 0, duration: .6 }, 0);
    document.querySelectorAll('.hero__axes path:not(.hero__arrow)').forEach(axis => {
      const length = axis.getTotalLength();
      gsap.set(axis, { strokeDasharray: length });
      hero.from(axis, { strokeDashoffset: length, duration: .6 }, .1);
    });
    hero.from('.hero__arrow', { opacity: 0, duration: .3 }, .4)
      .from('.hero__curve', { strokeDashoffset: 1, duration: 1.45 }, .25);
    revealLines(document.querySelector('.hero__title'), hero, .4);
    hero.from('.hero__lede, .hero__copy .hero__actions, .hero__slogan', {
      y: 12, opacity: 0, duration: .65, stagger: .08,
    }, .8)
      .from('.hero__portrait', { y: 12, clipPath: 'inset(100% 0 0 0)', duration: .85 }, .9)
      .fromTo('.hero__dot', { opacity: 0 }, {
        opacity: 1, duration: 1.45,
        motionPath: { path: '.hero__curve', align: '.hero__curve', alignOrigin: [.5, .5] },
      }, .25);

    ScrollTrigger.create({
      trigger: '.ledger', start: 'top 90%', once: true,
      onEnter: () => { ledgerEntered = true; context.startLedger(); },
    });

    document.querySelectorAll('.course').forEach(course => {
      const timeline = gsap.timeline({
        scrollTrigger: { trigger: course, start: 'top 85%', once: true },
      });
      timeline.set(course.querySelector('.course__code'), { WebkitTextFillColor: 'transparent' })
        .fromTo(course.querySelector('.course__code'), {
          WebkitTextStrokeColor: 'transparent', backgroundPosition: '0% 0%',
        }, { WebkitTextStrokeColor: '#102A43', duration: .3, ease: 'power4.out' })
        .to(course.querySelector('.course__code'), {
          backgroundPosition: '0% 100%', duration: .6, ease: 'expo.out',
        });
      count(course.querySelector('[data-count]'), timeline);
    });

    const path = document.querySelector('[data-path]');
    const fill = path.querySelector('.path__fill');
    const steps = [...path.querySelectorAll('.path__step')];
    let thresholds = [];
    const measureSteps = () => {
      thresholds = steps.map(step => (step.offsetTop + 20 - fill.offsetTop) / fill.offsetHeight);
    };
    const updateSteps = progress => {
      steps.forEach((step, index) => step.classList.toggle('is-reached', progress >= thresholds[index]));
    };
    measureSteps();
    gsap.fromTo(fill, { scaleY: 0 }, {
      scaleY: 1, ease: 'none',
      scrollTrigger: {
        trigger: path, start: 'top 75%', end: 'bottom 75%', scrub: true,
        onUpdate: self => updateSteps(self.progress),
        onRefresh: self => { measureSteps(); updateSteps(self.progress); },
      },
    });

    document.querySelectorAll('[data-reveal="list"]').forEach(list => {
      gsap.from(list.children, {
        y: 12, opacity: 0, duration: .25, stagger: { amount: .15 }, ease: 'power4.out',
        scrollTrigger: { trigger: list, start: 'top 85%', once: true },
      });
    });
    const close = document.querySelector('[data-reveal="lines"]');
    const closing = gsap.timeline({
      scrollTrigger: { trigger: close, start: 'top 85%', once: true },
    });
    revealLines(close, closing);

    const question = document.querySelector('[data-question]');
    context.add('animateVerdict', node => {
      gsap.from(node, { scale: .96, opacity: 0, duration: .2, ease: 'power4.out' });
    });
    const verdicts = new MutationObserver(records => {
      for (const record of records) {
        for (const node of record.addedNodes) {
          if (node.nodeType === 1 && node.matches('.q__verdict')) {
            context.animateVerdict(node);
          }
        }
      }
    });
    verdicts.observe(question, { childList: true, subtree: true });

    return () => {
      verdicts.disconnect();
      splits.forEach(split => split.revert());
      steps.forEach(step => step.classList.remove('is-reached'));
      document.querySelectorAll('[data-count]').forEach(element => {
        element.textContent = element.dataset.count;
      });
    };
  });

  media.add('(prefers-reduced-motion: no-preference) and (pointer: fine)', () => {
    const dispose = [];
    document.querySelectorAll('.btn').forEach(button => {
      button.classList.add('is-magnetic');
      const move = event => {
        if (button.disabled) return;
        const rect = button.getBoundingClientRect();
        const x = (event.clientX - rect.left - rect.width / 2) / rect.width;
        const y = (event.clientY - rect.top - rect.height / 2) / rect.height;
        const distance = Math.hypot(x, y);
        const factor = distance ? Math.min(4, distance * 8) / distance : 0;
        gsap.to(button, { x: x * factor, y: y * factor, duration: .2, ease: 'power4.out', overwrite: true });
      };
      const leave = () => gsap.to(button, { x: 0, y: 0, duration: .2, ease: 'expo.out', overwrite: true });
      button.addEventListener('pointermove', move);
      button.addEventListener('pointerleave', leave);
      button.addEventListener('blur', leave);
      dispose.push(() => {
        button.classList.remove('is-magnetic');
        button.removeEventListener('pointermove', move);
        button.removeEventListener('pointerleave', leave);
        button.removeEventListener('blur', leave);
        gsap.killTweensOf(button);
        gsap.set(button, { clearProps: 'transform' });
      });
    });
    return () => dispose.forEach(remove => remove());
  });

  media.add('(prefers-reduced-motion: reduce)', () => {
    document.querySelectorAll('[data-count]').forEach(element => {
      element.textContent = element.dataset.count;
    });
    gsap.set('.path__fill', { scaleY: 1 });
    gsap.set('.hero__curve', { strokeDashoffset: 0 });
  });

  if (document.fonts) document.fonts.ready.then(() => ScrollTrigger.refresh());
}
