const functions = require('@google-cloud/functions-framework');
const { ExecutionsClient } = require('@google-cloud/workflows');

const clienteWorkflows = new ExecutionsClient();

/**
 * Inicia la ejecución del workflow de facturación (Cloud Workflows) con el
 * comprobante recibido y devuelve el nombre de la ejecución.
 * Se inyectan el cliente y el workflow para poder probar sin llamar a GCP.
 */
async function iniciarEjecucion(comprobante, cliente = clienteWorkflows, parent = process.env.WORKFLOW_PARENT) {
  const [ejecucion] = await cliente.createExecution({
    parent,
    execution: { argument: JSON.stringify(comprobante) },
  });
  return ejecucion.name;
}

function validarCuerpo(body) {
  const faltantes = ['serie', 'numero', 'ruc', 'items'].filter((c) => body[c] === undefined || body[c] === null);
  return faltantes.map((c) => `Falta el campo: ${c}`);
}

// Punto de entrada detrás de API Gateway: POST /comprobantes y GET /health
functions.http('apiEmision', async (req, res) => {
  if (req.path === '/health') {
    return res.status(200).json({ status: 'ok', servicio: 'api-emision' });
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Método no permitido, use POST' });
  }
  const errores = validarCuerpo(req.body || {});
  if (errores.length > 0) {
    return res.status(400).json({ aceptado: false, errores });
  }
  try {
    const ejecucion = await iniciarEjecucion(req.body);
    return res.status(202).json({ aceptado: true, ejecucion });
  } catch (err) {
    console.error('No se pudo iniciar el workflow:', err.message);
    return res.status(502).json({ aceptado: false, error: 'No se pudo iniciar el procesamiento' });
  }
});

module.exports = { iniciarEjecucion, validarCuerpo };
