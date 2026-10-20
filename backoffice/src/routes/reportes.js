const express = require('express');
const { pool } = require('../db');

const router = express.Router();

// GET /api/reportes/comprobantes?ruc=20123456789  (RF06: consulta de histórico)
router.get('/comprobantes', async (req, res) => {
  try {
    const { ruc } = req.query;
    const params = [];
    let query = 'SELECT * FROM comprobantes';
    if (ruc) {
      params.push(ruc);
      query += ' WHERE ruc_emisor = $1';
    }
    query += ' ORDER BY creado_en DESC LIMIT 100';
    const { rows } = await pool.query(query, params);
    res.json({ total: rows.length, comprobantes: rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/reportes/comprobantes  (usado por Cloud Workflows para registrar el estado final)
router.post('/comprobantes', async (req, res) => {
  try {
    const { serie, numero, rucEmisor, cliente, total, moneda, estado } = req.body;
    if (!serie || !numero || !rucEmisor || total === undefined) {
      return res.status(400).json({ error: 'serie, numero, rucEmisor y total son obligatorios' });
    }
    const { rows } = await pool.query(
      `INSERT INTO comprobantes (serie, numero, ruc_emisor, cliente, total, moneda, estado)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       ON CONFLICT (ruc_emisor, serie, numero) DO UPDATE SET estado = EXCLUDED.estado
       RETURNING *`,
      [serie, numero, rucEmisor, cliente, total, moneda || 'PEN', estado || 'PENDIENTE']
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
