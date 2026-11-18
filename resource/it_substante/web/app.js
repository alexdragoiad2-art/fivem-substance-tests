// it_substante / web/app.js - afisajul etilotestului si al drugtestului (fara focus: nu blocheaza jocul).
const $ = (id) => document.getElementById(id);
let hideTimer = null, tick = null;

const PANEL = [
  { code: 'THC', label: 'Cannabis' }, { code: 'MET', label: 'Metamfet.' }, { code: 'AMP', label: 'Amfetamine' },
  { code: 'COC', label: 'Cocaină' }, { code: 'OPI', label: 'Opiacee' }, { code: 'BZO', label: 'Benzodiaz.' },
];

function hideAll() {
  clearTimeout(hideTimer); clearInterval(tick);
  $('breath').classList.add('hidden'); $('drug').classList.add('hidden');
  $('brSlip').classList.add('hidden'); $('drSlip').classList.add('hidden');
}
function autoHide(ms) { clearTimeout(hideTimer); hideTimer = setTimeout(hideAll, ms); }
const fmt = (n) => Number(n).toFixed(2).replace('.', ',');

function startBreath(d) {
  hideAll();
  $('breath').classList.remove('hidden');
  $('brValue').textContent = '-.--';
  $('brUnit').textContent = 'mg/L';
  $('brStatus').textContent = 'PREGĂTIRE';
  $('brStatus').classList.remove('lcd-blink');
  $('brFoot').textContent = d.role === 'officer' && d.name ? d.name.toUpperCase() : ' ';
  $('brBar').style.width = '0%';
  const total = (d.seconds || 6) * 1000; const t0 = Date.now() + 900;
  setTimeout(() => { $('brStatus').textContent = 'SUFLAȚI'; $('brStatus').classList.add('lcd-blink'); }, 900);
  tick = setInterval(() => {
    const p = Math.max(0, Math.min(1, (Date.now() - t0) / (total - 900)));
    $('brBar').style.width = (p * 100).toFixed(0) + '%';
    if (p >= 1) { clearInterval(tick); $('brStatus').classList.remove('lcd-blink'); $('brStatus').textContent = 'ANALIZĂ...'; }
  }, 60);
  autoHide(total + 20000);
}

function startDrug(d) {
  hideAll();
  $('drug').classList.remove('hidden');
  $('drStrips').innerHTML = PANEL.map((p) => `
    <div class="strip" data-code="${p.code}">
      <div class="win"><i class="ln c"></i><i class="ln t"></i></div>
      <div class="code">${p.code}</div><div class="lbl">${p.label}</div>
    </div>`).join('');
  $('drFoot').textContent = 'Se colectează proba de salivă...';
  setTimeout(() => {
    document.querySelectorAll('.strip').forEach((s) => s.classList.add('wet'));
    $('drFoot').textContent = 'Proba migrează pe benzi...';
  }, 1600);
  setTimeout(() => {
    document.querySelectorAll('.strip .ln.c').forEach((l) => (l.style.opacity = 1)); // linia de control apare mereu
    $('drFoot').textContent = 'Se citește rezultatul...';
  }, 3500);
  autoHide((d.seconds || 9) * 1000 + 20000);
}

function slipHTML(res) {
  const off = res.official ? 'POLIȚIA ROMÂNĂ' : 'TEST PERSONAL';
  if (res.kind === 'alcool') {
    const cls = res.verdict === 'negativ' ? 'neg' : 'pos';
    return `<h4>${off}<br>ETILOTEST IT-7510</h4>
      ${res.time}<br>Subiect: ${res.subject || '-'}
      <div class="v ${cls}">${fmt(res.mg)} mg/L</div>
      ≈ ${fmt(res.gl)} g/L sânge
      ${res.official ? `<div class="legal">${res.legal}</div>` : ''}`;
  }
  const rows = res.panel.map((p) => `${p.code} ${p.label.padEnd(15, '.')} <b class="${p.pos ? 'pos' : 'neg'}">${p.pos ? 'POZITIV' : 'negativ'}</b>`).join('<br>');
  return `<h4>${off}<br>TEST SALIVAR</h4>${res.time}<br>Subiect: ${res.subject || '-'}<br><br>${rows}
    ${res.official ? `<div class="legal">${res.legal}</div>` : ''}`;
}

function showResult(res) {
  if (res.kind === 'alcool') {
    clearInterval(tick);
    $('brStatus').classList.remove('lcd-blink');
    $('brStatus').textContent = res.verdict === 'negativ' ? 'REZULTAT' : 'ATENȚIE';
    $('brValue').textContent = fmt(res.mg);
    $('brBar').style.width = '100%';
    $('brSlip').innerHTML = slipHTML(res);
    $('brSlip').classList.remove('hidden');
  } else {
    // linia T dispare la pozitiv (testele imunocromatografice reale: fara linie T = pozitiv)
    res.panel.forEach((p) => {
      const s = document.querySelector(`.strip[data-code="${p.code}"] .ln.t`);
      if (s) s.style.opacity = p.pos ? 0 : 1;
    });
    $('drFoot').textContent = res.verdict === 'pozitiv' ? 'REZULTAT: POZITIV' : 'REZULTAT: NEGATIV';
    $('drFoot').style.color = res.verdict === 'pozitiv' ? '#b8000b' : '#0f7a35';
    $('drSlip').innerHTML = slipHTML(res);
    $('drSlip').classList.remove('hidden');
  }
  autoHide(16000);
}

window.addEventListener('message', (e) => {
  const d = e.data || {};
  if (d.action === 'start') {
    $('drFoot').style.color = '';
    if (d.kind === 'alcool') startBreath(d); else startDrug(d);
  } else if (d.action === 'result') {
    showResult(d.res);
  } else if (d.action === 'abort') {
    hideAll();
  }
});
