// ── api.js — Conector con la API de Axie via proxy ────────────
// Todas las llamadas pasan por /api/proxy (nuestro servidor Vercel)
// para evitar el bloqueo CORS del navegador.

const PROXY = "/api/proxy";

const GENE_FRAGMENT = `
  eyes  { d{name class} r1{name class} r2{name class} }
  ears  { d{name class} r1{name class} r2{name class} }
  mouth { d{name class} r1{name class} r2{name class} }
  horn  { d{name class} r1{name class} r2{name class} }
  back  { d{name class} r1{name class} r2{name class} }
  tail  { d{name class} r1{name class} r2{name class} }
`;

// Función base para llamar al proxy
async function gql(body) {
  const res = await fetch(PROXY, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`Error del servidor: ${res.status}`);
  const data = await res.json();
  if (data.errors?.length) throw new Error(data.errors[0].message);
  return data.data;
}

// ── 1. Traer un axie por ID ───────────────────────────────────
async function fetchAxieById(id) {
  const data = await gql({
    operationName: "GetAxieDetail",
    variables: { axieId: String(id) },
    query: `
      query GetAxieDetail($axieId: ID!) {
        axie(axieId: $axieId) {
          id name class image breedCount
          genes { ${GENE_FRAGMENT} }
          stats { hp speed skill morale }
          auction { currentPriceUSD }
        }
      }
    `,
  });
  return normalizeAxie(data.axie);
}

// ── 2. Traer axies de una wallet Ronin ───────────────────────
async function fetchAxiesByWallet(rawAddress) {
  const address = rawAddress.trim().replace(/^ronin:/i, "0x").toLowerCase();
  if (!/^0x[0-9a-f]{40}$/i.test(address)) {
    throw new Error("Dirección inválida. Usa ronin:0x... o 0x...");
  }

  const data = await gql({
    operationName: "GetAxiesByOwner",
    variables: { owner: address, from: 0, size: 100 },
    query: `
      query GetAxiesByOwner($owner: String!, $from: Int!, $size: Int!) {
        axies(owner: $owner, from: $from, size: $size, auctionType: All) {
          total
          results {
            id name class image breedCount
            genes { ${GENE_FRAGMENT} }
            stats { hp speed skill morale }
          }
        }
      }
    `,
  });

  const results = data?.axies?.results || [];
  const total   = data?.axies?.total   || 0;
  return { axies: results.map(normalizeAxie), total };
}

// ── 3. Buscar en el Marketplace por partes ───────────────────
// partIds: array de IDs como ["mouth-goda", "back-scarab", "tail-rice"]
// maxPrice: precio máximo en USD (null = sin límite)
// breedCounts: array de números permitidos como [0,1,2] (null = todos)
async function searchMarketplace({ partIds = [], maxPrice = null, breedCounts = null, size = 50 }) {
  const criteria = {};
  if (partIds.length)    criteria.parts      = partIds;
  if (breedCounts)       criteria.breedCount = breedCounts;

  const variables = {
    from: 0,
    size,
    sort: "PriceAsc",
    auctionType: "Sale",
    criteria,
  };

  const data = await gql({
    operationName: "SearchAxies",
    variables,
    query: `
      query SearchAxies(
        $auctionType: AuctionType
        $criteria: AxieSearchCriteria
        $from: Int
        $sort: SortBy
        $size: Int
      ) {
        axies(
          auctionType: $auctionType
          criteria: $criteria
          from: $from
          sort: $sort
          size: $size
        ) {
          total
          results {
            id name class image breedCount
            genes { ${GENE_FRAGMENT} }
            stats { hp speed skill morale }
            auction { currentPriceUSD }
          }
        }
      }
    `,
  });

  const results = data?.axies?.results || [];
  const total   = data?.axies?.total   || 0;

  // Filtrar por precio máximo si se especificó
  const filtered = maxPrice
    ? results.filter(a => {
        const price = parseFloat(a.auction?.currentPriceUSD || "0");
        return price <= maxPrice;
      })
    : results;

  return { axies: filtered.map(normalizeAxie), total };
}

// ── Normalizar datos de la API al formato interno ─────────────
function normalizeAxie(raw) {
  if (!raw) throw new Error("Axie no encontrado");
  return {
    id:         raw.id,
    name:       raw.name || `Axie #${raw.id}`,
    class:      raw.class || "Normal",
    image:      raw.image || null,
    breedCount: raw.breedCount ?? 0,
    genes:      parseAxieGenes(raw),
    stats:      raw.stats || {},
    price:      raw.auction?.currentPriceUSD
                  ? parseFloat(raw.auction.currentPriceUSD).toFixed(2)
                  : null,
  };
}
