const functions = require('@google-cloud/functions-framework');
const { Pool } = require('pg');

let pool;
let esquemaListo = false;

function obtenerPool() {
  if (!pool) {
    pool = new Pool({
      host: process.env.DB_HOST,
      port: Number(process.env.DB_PORT || 5432),
      database: process.env.DB_NAME,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      max: 2, // pocas conexiones por instancia: la función puede escalar a varias instancias
      connectionTimeoutMillis: 5000,
    });
  }
  return pool;
}

const DDL = `
  CREATE TABLE IF NOT EXISTS comprobantes (
    id SERIAL PRIMARY KEY,
    serie VARCHAR(10) NOT NULL,
    numero VARCHAR(20) NOT NULL,
    ruc_emisor VARCHAR(11) NOT NULL,
    cliente VARCHAR(150),
    total NUMERIC(12,2) NOT NULL,
    moneda VARCHAR(3) DEFAULT 'PEN',
    estado VARCHAR(20) DEFAULT 'PENDIENTE',
    creado_en TIMESTAMP DEFAULT NOW()
  );
  CREATE UNIQUE INDEX IF NOT EXISTS ux_comprobante ON comprobantes (ruc_emisor, serie, numero);
`;

/** Decodifica el sobre de Pub/Sub (push): { message: { data: <base64> } } */
function decodificarMensaje(body) {
  const data = body && body.message && body.message.data;
  if (!data) {
    throw new Error('Mensaje de Pub/Sub inválido: falta message.data');
  }
  return JSON.parse(Buffer.from(data, 'base64').toString('utf8'));
}

/** Upsert idempotente: un reintento de Pub/Sub no duplica el comprobante. */
async function guardarComprobante(c, db) {
  const { rows } = await db.query(
    `INSERT INTO comprobantes (serie, numero, ruc_emisor, cliente, total, moneda, estado)
     VALUES ($1,$2,$3,$4,$5,$6,$7)
     ON CONFLICT (ruc_emisor, serie, numero) DO UPDATE SET estado = EXCLUDED.estado
     RETURNING id`,
    [c.serie, c.numero, c.ruc, c.cliente, c.total, c.moneda || 'PEN', c.estado || 'ACEPTADO']
  );
  return rows[0].id;
}

functions.http('sincronizarReportes', async (req, res) => {
  let comprobante;
  try {
    comprobante = decodificarMensaje(req.body);
  } catch (err) {
    // Mensaje malformado: 400 -> Pub/Sub reintenta y, tras agotar intentos, lo envía a la DLQ
    console.error(err.message);
    return res.status(400).json({ error: err.message });
  }
  try {
    const db = obtenerPool();
    if (!esquemaListo) {
      await db.query(DDL);
      esquemaListo = true;
    }
    const id = await guardarComprobante(comprobante, db);
    console.log(JSON.stringify({ evento: 'reporte_sincronizado', serie: comprobante.serie, numero: comprobante.numero, id }));
    return res.status(204).send(); // ack
  } catch (err) {
    // Fallo de BD: 500 -> Pub/Sub reintenta con backoff exponencial
    console.error('Error al guardar en Cloud SQL:', err.message);
    return res.status(500).json({ error: 'No se pudo guardar el comprobante' });
  }
});

module.exports = { decodificarMensaje, guardarComprobante };
