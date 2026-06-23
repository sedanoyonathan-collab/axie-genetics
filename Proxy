// ── /api/proxy.js ─────────────────────────────────────────────
// Este archivo corre en el SERVIDOR de Vercel, no en el navegador.
// El navegador llama a /api/proxy, este archivo llama a Axie,
// y devuelve la respuesta — sin bloqueos CORS.

const AXIE_GQL = "https://graphql-gateway.axieinfinity.com/graphql";

export default async function handler(req, res) {
  // Permitir solicitudes desde cualquier origen (CORS)
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  // El navegador hace un "pre-check" OPTIONS antes del POST real
  if (req.method === "OPTIONS") {
    return res.status(200).end();
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Solo se acepta POST" });
  }

  try {
    const response = await fetch(AXIE_GQL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0",
        "Origin": "https://app.axieinfinity.com",
        "Referer": "https://app.axieinfinity.com/",
      },
      body: JSON.stringify(req.body),
    });

    const data = await response.json();
    return res.status(200).json(data);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
}
