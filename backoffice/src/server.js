require('dotenv').config();
const express = require('express');
const { initSchema } = require('./db');
const reportesRouter = require('./routes/reportes');

const app = express();
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok', servicio: 'backoffice' });
});

app.use('/api/reportes', reportesRouter);

const PORT = process.env.PORT || 8080;

// La app arranca y sirve /health aunque la BD aún no esté disponible;
// initSchema se ejecuta en paralelo y solo afecta a las rutas de /api/reportes.
initSchema()
  .then(() => console.log('Esquema de base de datos verificado'))
  .catch((err) => console.error('No se pudo conectar/inicializar la base de datos:', err.message));

app.listen(PORT, () => console.log(`Backoffice escuchando en el puerto ${PORT}`));

module.exports = app;
