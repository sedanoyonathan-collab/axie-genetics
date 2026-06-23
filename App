// ── Estado global ─────────────────────────────────────────────
const state = {
  filter: {},          // { part: { name, id } }
  loadedAxies: [],     // pool de axies para análisis
  pairA: null,
  pairB: null,
};

document.addEventListener("DOMContentLoaded", () => {
  buildFilterUI();
  setupTabs();
  setupWalletLoader();
  setupIDLoader();
  setupMarketSearch();
  setupPairLoaders();
});

// ══════════════════════════════════════════════════════════════
// TABS
// ══════════════════════════════════════════════════════════════
function setupTabs() {
  document.querySelectorAll(".tab-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      document.querySelectorAll(".tab-btn").forEach(b => b.classList.remove("active"));
      document.querySelectorAll(".tab-pane").forEach(p => p.classList.add("hidden"));
      btn.classList.add("active");
      document.getElementById("tab-" + btn.dataset.tab)?.classList.remove("hidden");
    });
  });
}

// ══════════════════════════════════════════════════════════════
// FILTRO DE CARTAS (Paso 1)
// ══════════════════════════════════════════════════════════════
function buildFilterUI() {
  const container = document.getElementById("filter-builder");
  container.innerHTML = "";

  for (const part of BODY_PARTS) {
    const block = document.createElement("div");
    block.className = "filter-part-block";
    block.innerHTML = `
      <div class="filter-part-header">
        <span class="filter-part-label">${PART_LABELS[part]}</span>
        <div class="filter-part-controls">
          <select class="cls-filter-select" data-part="${part}">
            <option value="">Todas las clases</option>
            ${ALL_CLASSES.map(c => `<option value="${c}">${c}</option>`).join("")}
          </select>
          <input type="text" class="card-search-input" data-part="${part}" placeholder="Buscar..." />
          <button class="btn-clear-part" data-part="${part}" title="Limpiar">✕</button>
        </div>
      </div>
      <div class="filter-cards-list" id="cards-${part}"></div>
      <div class="filter-selected-display" id="selected-${part}">
        <span class="no-selection">Sin selección</span>
      </div>
    `;
    container.appendChild(block);
    renderCardOptions(part, getAllCardsForPart(part));

    block.querySelector(".cls-filter-select").addEventListener("change", e => {
      const cls = e.target.value;
      const q   = block.querySelector(".card-search-input").value;
      const cards = cls
        ? getCardsForPartAndClass(part, cls).filter(c => !q || c.name.toLowerCase().includes(q.toLowerCase()))
        : searchCardsForPart(part, q);
      renderCardOptions(part, cards);
    });

    block.querySelector(".card-search-input").addEventListener("input", e => {
      const q   = e.target.value;
      const cls = block.querySelector(".cls-filter-select").value;
      const cards = cls
        ? getCardsForPartAndClass(part, cls).filter(c => !q || c.name.toLowerCase().includes(q.toLowerCase()))
        : searchCardsForPart(part, q);
      renderCardOptions(part, cards);
    });

    block.querySelector(".btn-clear-part").addEventListener("click", () => {
      delete state.filter[part];
      updateSelectedDisplay(part);
      block.querySelectorAll(".card-chip.selected").forEach(c => c.classList.remove("selected"));
      onFilterChange();
    });
  }
}

function renderCardOptions(part, cards) {
  const list = document.getElementById(`cards-${part}`);
  list.innerHTML = "";
  for (const card of cards) {
    const chip = document.createElement("button");
    chip.className = "card-chip " + getClassCss(card.class);
    chip.dataset.card = card.name;
    chip.dataset.part = part;
    if (state.filter[part]?.name === card.name) chip.classList.add("selected");
    chip.innerHTML = `<span class="chip-name">${card.name}</span><span class="chip-cls">${card.class}</span>`;
    chip.addEventListener("click", () => toggleCard(part, card, chip));
    list.appendChild(chip);
  }
}

function toggleCard(part, card, chipEl) {
  if (state.filter[part]?.name === card.name) {
    delete state.filter[part];
    chipEl.classList.remove("selected");
  } else {
    document.querySelectorAll(`.card-chip[data-part="${part}"].selected`).forEach(c => c.classList.remove("selected"));
    state.filter[part] = { name: card.name, id: card.id };
    chipEl.classList.add("selected");
  }
  updateSelectedDisplay(part);
  onFilterChange();
}

function updateSelectedDisplay(part) {
  const el  = document.getElementById(`selected-${part}`);
  const sel = state.filter[part];
  if (sel) {
    const allCards = getAllCardsForPart(part);
    const card     = allCards.find(c => c.name === sel.name);
    const css      = card ? getClassCss(card.class) : "c-normal";
    el.innerHTML   = `<span class="selected-chip ${css}">${sel.name}</span>`;
  } else {
    el.innerHTML = `<span class="no-selection">Sin selección</span>`;
  }
}

function clearAllFilters() {
  state.filter = {};
  document.querySelectorAll(".card-chip.selected").forEach(c => c.classList.remove("selected"));
  for (const part of BODY_PARTS) updateSelectedDisplay(part);
  hideEl("results-section");
  hideEl("market-results-section");
}

function getSelectionsArray() {
  return Object.entries(state.filter).map(([part, card]) => ({ part, cardName: card.name, cardId: card.id }));
}

function getFilterPartIds() {
  return Object.values(state.filter).map(c => c.id).filter(Boolean);
}

// ══════════════════════════════════════════════════════════════
// BÚSQUEDA EN MARKETPLACE (Paso 2 → Tab "Marketplace")
// ══════════════════════════════════════════════════════════════
function setupMarketSearch() {
  document.getElementById("btn-search-market").addEventListener("click", searchMarket);
}

async function searchMarket() {
  const partIds = getFilterPartIds();
  if (!partIds.length) {
    showToast("Selecciona al menos una carta en el Paso 1 primero", "error");
    return;
  }

  const maxPriceVal = document.getElementById("market-max-price").value.trim();
  const maxPrice    = maxPriceVal ? parseFloat(maxPriceVal) : null;

  const breedVals = [...document.querySelectorAll(".breed-check:checked")].map(el => parseInt(el.value));
  const breedCounts = breedVals.length ? breedVals : null;

  const statusEl = document.getElementById("market-status");
  setStatus(statusEl, "loading", `<span class="spin">⟳</span> Buscando en marketplace con ${partIds.length} filtro(s)...`);

  try {
    const { axies, total } = await searchMarketplace({ partIds, maxPrice, breedCounts, size: 50 });

    if (!axies.length) {
      setStatus(statusEl, "error", "No se encontraron axies con esas cartas en venta.");
      return;
    }

    setStatus(statusEl, "success", `✓ ${total} axies encontrados · mostrando ${axies.length}`);
    renderMarketResults(axies);

    // Agregar al pool automáticamente para análisis de pares
    axies.forEach(a => addToPool(a));
    renderPool();

  } catch(e) {
    setStatus(statusEl, "error", `✗ ${e.message}`);
  }
}

function renderMarketResults(axies) {
  const section = document.getElementById("market-results-section");
  showEl("market-results-section");

  const container = document.getElementById("market-results-grid");
  container.innerHTML = axies.map(a => {
    const css = getClassCss(a.class);
    const price = a.price ? `$${a.price}` : "No listado";
    return `
      <div class="market-card">
        <div class="market-card-top">
          ${a.image ? `<img src="${a.image}" class="market-img" onerror="this.style.display='none'">` : `<div class="market-img-ph">🐣</div>`}
          <div class="market-card-info">
            <div class="market-name">${a.name}</div>
            <div class="market-meta">
              <span class="gene-tag ${css}">${a.class}</span>
              <span class="market-id">#${a.id}</span>
            </div>
            <div class="market-price ${a.price ? "" : "no-price"}">${price}</div>
            <div class="market-breeds">${a.breedCount} crías</div>
          </div>
        </div>
        <div class="market-genes">
          ${BODY_PARTS.map(p => {
            const g   = a.genes?.[p];
            if (!g?.d) return "";
            const sel = state.filter[p];
            const dCss = getClassCss(g.d.className);
            const isTarget = sel && g.d.name === sel.name;
            return `<div class="market-gene-row">
              <span class="market-gene-part">${PART_LABELS[p]}</span>
              <span class="gene-tag ${dCss}${isTarget ? " gene-target" : ""}">${g.d.name}</span>
              <span class="gene-tag ${getClassCss(g.r1?.className)} r-gene">${g.r1?.name || "?"}</span>
              <span class="gene-tag ${getClassCss(g.r2?.className)} r-gene">${g.r2?.name || "?"}</span>
            </div>`;
          }).join("")}
        </div>
        <a href="https://app.axieinfinity.com/marketplace/axies/${a.id}" target="_blank" class="btn-view-market">
          Ver en marketplace →
        </a>
      </div>
    `;
  }).join("");
}

// ══════════════════════════════════════════════════════════════
// CARGAR POR IDs
// ══════════════════════════════════════════════════════════════
function setupIDLoader() {
  document.getElementById("btn-load-ids").addEventListener("click", loadByIDs);
  document.getElementById("input-ids").addEventListener("keydown", e => { if(e.key === "Enter") loadByIDs(); });
}

async function loadByIDs() {
  const raw  = document.getElementById("input-ids").value.trim();
  const ids  = raw.split(/[\s,;]+/).map(s => s.replace(/\D/g,"")).filter(Boolean);
  if (!ids.length) return showToast("Ingresa al menos un ID", "error");

  const statusEl = document.getElementById("ids-status");
  setStatus(statusEl, "loading", `<span class="spin">⟳</span> Cargando ${ids.length} axie(s)...`);

  let ok = 0, fail = 0;
  for (const id of ids) {
    try   { addToPool(await fetchAxieById(id)); ok++;   }
    catch (e) { fail++; console.warn(`ID ${id}: ${e.message}`); }
  }

  setStatus(statusEl, "success", `✓ ${ok} cargado(s)${fail ? ` · ${fail} error(es)` : ""}`);
  renderPool();
}

// ══════════════════════════════════════════════════════════════
// CARGAR WALLET
// ══════════════════════════════════════════════════════════════
function setupWalletLoader() {
  document.getElementById("btn-load-wallet").addEventListener("click", loadWallet);
}

async function loadWallet() {
  const addr     = document.getElementById("input-wallet").value.trim();
  const statusEl = document.getElementById("wallet-status");
  if (!addr) return showToast("Ingresa una dirección", "error");

  setStatus(statusEl, "loading", `<span class="spin">⟳</span> Conectando con Axie...`);
  try {
    const { axies, total } = await fetchAxiesByWallet(addr);
    if (!axies.length) { setStatus(statusEl, "error", "Esta wallet no tiene axies."); return; }
    axies.forEach(a => addToPool(a));
    setStatus(statusEl, "success", `✓ ${axies.length} axies cargados${total > 100 ? ` (de ${total})` : ""}`);
    renderPool();
  } catch(e) {
    setStatus(statusEl, "error", `✗ ${e.message}`);
  }
}

// ══════════════════════════════════════════════════════════════
// PAR DIRECTO
// ══════════════════════════════════════════════════════════════
function setupPairLoaders() {
  document.getElementById("btn-load-pair-a").addEventListener("click", () => loadPair("A"));
  document.getElementById("btn-load-pair-b").addEventListener("click", () => loadPair("B"));
  document.getElementById("input-pair-a").addEventListener("keydown", e => { if(e.key==="Enter") loadPair("A"); });
  document.getElementById("input-pair-b").addEventListener("keydown", e => { if(e.key==="Enter") loadPair("B"); });
}

async function loadPair(slot) {
  const input  = document.getElementById(`input-pair-${slot.toLowerCase()}`);
  const status = document.getElementById(`status-pair-${slot.toLowerCase()}`);
  const id     = input.value.trim().replace(/\D/g,"");
  if (!id) return;

  setStatus(status, "loading", `<span class="spin">⟳</span> Cargando...`);
  try {
    const axie = await fetchAxieById(id);
    if (slot === "A") state.pairA = axie; else state.pairB = axie;
    setStatus(status, "success", `✓ ${axie.name} · ${axie.class} · ${axie.breedCount} crías`);
    renderPairPreview(slot, axie);
    if (state.pairA && state.pairB) renderDirectPairResult();
  } catch(e) {
    setStatus(status, "error", `✗ ${e.message}`);
  }
}

function renderPairPreview(slot, axie) {
  const el  = document.getElementById(`preview-pair-${slot.toLowerCase()}`);
  const css = getClassCss(axie.class);
  el.innerHTML = `
    <div class="pair-preview-card">
      ${axie.image ? `<img src="${axie.image}" class="pair-img" onerror="this.style.display='none'">` : `<div class="pair-img pair-img-ph">🐣</div>`}
      <div class="pair-info">
        <div class="pair-name">${axie.name}</div>
        <div class="pair-meta">
          <span class="gene-tag ${css}">${axie.class}</span>
          <span class="pair-id">#${axie.id}</span>
          <span class="pair-breeds">${axie.breedCount} crías</span>
        </div>
        <div class="pair-gene-mini">
          ${BODY_PARTS.map(p => {
            const g = axie.genes?.[p];
            if (!g?.d) return "";
            return `<span class="mini-gene ${getClassCss(g.d.className)}">${g.d.name}</span>`;
          }).join("")}
        </div>
      </div>
    </div>
  `;
}

function renderDirectPairResult() {
  const sel = getSelectionsArray();
  if (!sel.length) {
    document.getElementById("pair-result-area").innerHTML =
      `<p class="hint-text">Selecciona las cartas que quieres en el Paso 1 para ver el resultado.</p>`;
    return;
  }
  const { combined, details } = calcCombinedProb(sel, state.pairA.genes, state.pairB.genes);
  const pct  = combined * 100;
  const tier = pct >= 20 ? "high" : pct >= 5 ? "medium" : "low";
  document.getElementById("pair-result-area").innerHTML = `
    <div class="prob-hero">
      <div class="prob-big ${tier}">${pct.toFixed(3)}%</div>
      <div class="prob-label">probabilidad combinada de obtener todas las cartas seleccionadas</div>
    </div>
    ${buildDetailsTable(details)}
    ${buildGenesTable(state.pairA, state.pairB)}
  `;
}

// ══════════════════════════════════════════════════════════════
// POOL + ANÁLISIS DE PARES
// ══════════════════════════════════════════════════════════════
function addToPool(axie) {
  if (!state.loadedAxies.find(a => a.id === axie.id)) state.loadedAxies.push(axie);
}
function removeFromPool(id) {
  state.loadedAxies = state.loadedAxies.filter(a => a.id !== id);
  renderPool();
}
function clearPool() {
  state.loadedAxies = [];
  renderPool();
  hideEl("results-section");
}

function renderPool() {
  const container = document.getElementById("loaded-pool");
  document.getElementById("pool-count").textContent = `${state.loadedAxies.length} axie(s)`;

  if (!state.loadedAxies.length) {
    container.innerHTML = `<p class="hint-text">Importa axies desde marketplace, wallet o IDs.</p>`;
    return;
  }
  container.innerHTML = state.loadedAxies.map(a => {
    const css = getClassCss(a.class);
    return `
      <div class="pool-chip">
        ${a.image ? `<img src="${a.image}" class="pool-img" onerror="this.style.display='none'">` : ""}
        <div class="pool-chip-info">
          <span class="pool-chip-name">${a.name}</span>
          <span class="gene-tag ${css}" style="font-size:10px">${a.class}</span>
          ${a.price ? `<span class="pool-price">$${a.price}</span>` : ""}
        </div>
        <button class="pool-remove" onclick="removeFromPool('${a.id}')" title="Quitar">✕</button>
      </div>
    `;
  }).join("");
}

function analyzeAllPairs() {
  const sel = getSelectionsArray();
  if (!sel.length)                   return showToast("Selecciona cartas en el Paso 1 primero", "error");
  if (state.loadedAxies.length < 2)  return showToast("Necesitas al menos 2 axies en el pool", "error");

  const pairs = analyzePairs(state.loadedAxies, sel);
  renderPairResults(pairs);
}

function renderPairResults(pairs) {
  showEl("results-section");
  document.getElementById("results-section").scrollIntoView({ behavior:"smooth", block:"start" });

  const container = document.getElementById("analysis-results");
  if (!pairs.length) { container.innerHTML = `<p class="hint-text">Sin combinaciones.</p>`; return; }

  const top = pairs.slice(0, 30);
  container.innerHTML = `
    <div class="pairs-summary">
      <span>${pairs.length} combinaciones analizadas</span>
      <span class="pairs-best">Mejor: ${(top[0].combined*100).toFixed(3)}%</span>
    </div>
    ${top.map((pair, i) => buildPairCard(pair, i)).join("")}
  `;
}

function buildPairCard(pair, index) {
  const pct  = pair.combined * 100;
  const tier = pct >= 20 ? "high" : pct >= 5 ? "medium" : "low";
  const cssA = getClassCss(pair.axieA.class);
  const cssB = getClassCss(pair.axieB.class);
  const priceA = pair.axieA.price ? ` · $${pair.axieA.price}` : "";
  const priceB = pair.axieB.price ? ` · $${pair.axieB.price}` : "";

  return `
    <div class="pair-card ${index===0 ? "pair-card-best" : ""}">
      <div class="pair-card-header">
        <div class="pair-rank">#${index+1}</div>
        <div class="pair-axies">
          <div class="pair-axie-mini">
            ${pair.axieA.image ? `<img src="${pair.axieA.image}" class="pair-mini-img" onerror="this.style.display='none'">` : ""}
            <div>
              <div class="pair-mini-name">${pair.axieA.name}<span class="pair-mini-id">#${pair.axieA.id}${priceA}</span></div>
              <span class="gene-tag ${cssA}" style="font-size:10px">${pair.axieA.class}</span>
            </div>
          </div>
          <div class="pair-x">×</div>
          <div class="pair-axie-mini">
            ${pair.axieB.image ? `<img src="${pair.axieB.image}" class="pair-mini-img" onerror="this.style.display='none'">` : ""}
            <div>
              <div class="pair-mini-name">${pair.axieB.name}<span class="pair-mini-id">#${pair.axieB.id}${priceB}</span></div>
              <span class="gene-tag ${cssB}" style="font-size:10px">${pair.axieB.class}</span>
            </div>
          </div>
        </div>
        <div class="pair-prob-badge ${tier}">${pct.toFixed(3)}%</div>
      </div>
      <div class="pair-card-details">
        ${buildDetailsTable(pair.details)}
      </div>
    </div>
  `;
}

// ══════════════════════════════════════════════════════════════
// RENDERIZADO COMPARTIDO
// ══════════════════════════════════════════════════════════════
function buildDetailsTable(details) {
  return `
    <table class="details-table">
      <thead><tr><th>Parte</th><th>Carta deseada</th><th>Origen del gen</th><th>Probabilidad</th></tr></thead>
      <tbody>
        ${details.map(d => {
          const pct  = d.prob * 100;
          const tier = pct >= 30 ? "high" : pct >= 10 ? "medium" : "low";
          const css  = d.sources[0] ? getClassCss(d.sources[0].cls) : "c-normal";
          const src  = d.sources.map(s =>
            `<span class="gene-pill ${s.type}-pill">${s.type.toUpperCase()}</span> Axie ${s.axie} <span style="color:var(--text-3)">${(s.contrib*100).toFixed(2)}%</span>`
          ).join(" &nbsp;");
          return `<tr>
            <td><span class="part-label">${PART_LABELS[d.part]}</span></td>
            <td><span class="gene-tag ${css}">${d.cardName}</span></td>
            <td class="src-cell">${src || "—"}</td>
            <td>
              <div class="prob-bar-wrap">
                <div class="prob-bar-track"><div class="prob-bar-fill ${tier}" style="width:${Math.min(pct*2,100)}%"></div></div>
                <span class="prob-pct ${tier}">${pct.toFixed(2)}%</span>
              </div>
            </td>
          </tr>`;
        }).join("")}
      </tbody>
    </table>
  `;
}

function buildGenesTable(axieA, axieB) {
  return `
    <div style="overflow-x:auto; margin-top:12px;">
      <table class="gene-table">
        <thead>
          <tr>
            <th>Parte</th>
            <th colspan="3" style="text-align:center;color:var(--accent)">Axie A — ${axieA.name}</th>
            <th colspan="3" style="text-align:center;color:var(--purple)">Axie B — ${axieB.name}</th>
          </tr>
          <tr>
            <th></th>
            <th class="d-head">D 37.5%</th><th class="r1-head">R1 9.4%</th><th class="r2-head">R2 3.1%</th>
            <th class="d-head">D 37.5%</th><th class="r1-head">R1 9.4%</th><th class="r2-head">R2 3.1%</th>
          </tr>
        </thead>
        <tbody>
          ${BODY_PARTS.map(p => {
            const gA = axieA.genes?.[p] || {};
            const gB = axieB.genes?.[p] || {};
            const hl = !!state.filter[p];
            return `<tr ${hl ? 'class="row-hl"' : ''}>
              <td><span class="part-label">${PART_LABELS[p]}</span></td>
              ${["d","r1","r2"].map(t => gCell(gA[t], p)).join("")}
              ${["d","r1","r2"].map(t => gCell(gB[t], p)).join("")}
            </tr>`;
          }).join("")}
        </tbody>
      </table>
    </div>
  `;
}

function gCell(gene, part) {
  if (!gene?.name) return `<td><span style="color:var(--text-3)">—</span></td>`;
  const css      = getClassCss(gene.className);
  const isTarget = state.filter[part]?.name === gene.name;
  return `<td><span class="gene-tag ${css}${isTarget ? " gene-target" : ""}">${gene.name}</span></td>`;
}

// ══════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════
function onFilterChange() {
  if (state.pairA && state.pairB) renderDirectPairResult();
}
function showEl(id)  { document.getElementById(id)?.classList.remove("hidden"); }
function hideEl(id)  { document.getElementById(id)?.classList.add("hidden"); }
function setStatus(el, type, html) { el.className = `status-msg ${type}`; el.innerHTML = html; }
function showToast(msg, type = "info") {
  let t = document.getElementById("toast");
  if (!t) { t = document.createElement("div"); t.id = "toast"; document.body.appendChild(t); }
  t.textContent = msg;
  t.className = `toast toast-${type} show`;
  setTimeout(() => t.classList.remove("show"), 3000);
}
