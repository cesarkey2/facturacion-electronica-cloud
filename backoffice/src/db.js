const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  max: 5,
  idleTimeoutMillis: 10000,
  connectionTimeoutMillis: 5000,
});

async function initSchema() {
  await pool.query(`
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
  `);
}

module.exports = { pool, initSchema };
