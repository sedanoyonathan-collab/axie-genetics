// ── Motor de Probabilidades Genéticas ─────────────────────────

const GENE_PROBS = {
  d:  0.375,    // Dominante: 37.5%
  r1: 0.09375,  // Recesivo 1: 9.375%
  r2: 0.03125   // Recesivo 2: 3.125%
};

const CLASS_CSS = {
  Plant:   "c-plant",
  Beast:   "c-beast",
  Bird:    "c-bird",
  Bug:     "c-bug",
  Aquatic: "c-aquatic",
  Reptile: "c-reptile",
  Mech:    "c-mech",
  Dawn:    "c-dawn",
  Dusk:    "c-dusk",
};

function getClassCss(cls) {
  return CLASS_CSS[cls] || "c-normal";
}

// Parsear genes de la respuesta de la API al formato interno
function parseAxieGenes(axieData) {
  const parsed = {};
  const parts  = axieData.genes || {};
  for (const part of BODY_PARTS) {
    const p = parts[part];
    if (!p) { parsed[part] = { d: null, r1: null, r2: null }; continue; }
    parsed[part] = {
      d:  { name: p.d?.name  || "?", className: p.d?.class  || "Normal" },
      r1: { name: p.r1?.name || "?", className: p.r1?.class || "Normal" },
      r2: { name: p.r2?.name || "?", className: p.r2?.class || "Normal" },
    };
  }
  return parsed;
}

// Calcular probabilidad de que la cría herede una carta específica
// dado los genes de ambos padres
function calcPartProb(desiredCard, part, genesA, genesB) {
  let prob = 0;
  const sources = [];
  const gA = genesA?.[part] || {};
  const gB = genesB?.[part] || {};

  for (const [type, p] of Object.entries(GENE_PROBS)) {
    if (gA[type]?.name === desiredCard) {
      prob += 0.5 * p;
      sources.push({ axie:"A", type, name: gA[type].name, cls: gA[type].className, contrib: 0.5*p });
    }
    if (gB[type]?.name === desiredCard) {
      prob += 0.5 * p;
      sources.push({ axie:"B", type, name: gB[type].name, cls: gB[type].className, contrib: 0.5*p });
    }
  }
  return { prob, sources };
}

// Calcular probabilidad combinada de todas las cartas deseadas (AND)
function calcCombinedProb(selections, genesA, genesB) {
  let combined = 1;
  const details = [];
  for (const { part, cardName } of selections) {
    const { prob, sources } = calcPartProb(cardName, part, genesA, genesB);
    combined *= prob;
    details.push({ part, cardName, prob, sources });
  }
  return { combined, details };
}

// Obtener cartas únicas disponibles en ambos padres para una parte
function getAvailableCards(part, genesA, genesB) {
  const seen = new Set();
  const cards = [];
  const add = (g, axie, type) => {
    if (!g?.name || g.name === "?") return;
    if (!seen.has(g.name)) {
      seen.add(g.name);
      cards.push({ name: g.name, className: g.className, axie, type });
    }
  };
  const gA = genesA?.[part] || {};
  const gB = genesB?.[part] || {};
  for (const t of ["d","r1","r2"]) {
    add(gA[t], "A", t);
    add(gB[t], "B", t);
  }
  return cards;
}

// Analizar todos los pares posibles de una lista de axies
// Devuelve pares ordenados por probabilidad combinada descendente
function analyzePairs(axieList, selections) {
  if (selections.length === 0 || axieList.length < 2) return [];

  const pairs = [];
  for (let i = 0; i < axieList.length; i++) {
    for (let j = i + 1; j < axieList.length; j++) {
      const a = axieList[i];
      const b = axieList[j];
      const { combined, details } = calcCombinedProb(selections, a.genes, b.genes);
      pairs.push({
        axieA: a,
        axieB: b,
        combined,
        details
      });
    }
  }

  // Ordenar de mayor a menor probabilidad
  pairs.sort((a, b) => b.combined - a.combined);
  return pairs;
}
