const functions = require('@google-cloud/functions-framework');

/**
 * Mock del servicio de recepción de SUNAT (RF04). Este prototipo académico no
 * se integra con el endpoint real (Beta/Producción SUNAT); se simula la
 * respuesta en forma de CDR (Constancia de Recepción) para poder verificar el
 * flujo end-to-end sin credenciales de una entidad tributaria real.
 * @param {{xml: string, firma?: string, firmaSha256?: string}} payload
 */
function procesarEnvioSunat(payload = {}) {
  const { xml, firma, firmaSha256 } = payload; // 'firma' (KMS) o 'firmaSha256' (compatibilidad)

  if (!xml || !(firma || firmaSha256)) {
    return {
      aceptado: false,
      codigo: '2000',
      descripcion: 'El comprobante no cuenta con firma digital, no puede remitirse a SUNAT',
    };
  }

  return {
    aceptado: true,
    codigo: '0',
    descripcion: 'La operación fue realizada satisfactoriamente',
    numeroCdr: `CDR-${Date.now()}`,
    fechaProceso: new Date().toISOString(),
  };
}

/**
 * Perilla de pruebas de resiliencia (PR02): con SUNAT_FAIL_RATE=0.5 aproximadamente la
 * mitad de las solicitudes responde 503 para verificar reintentos y DLQ.
 */
function debeFallar(tasa, aleatorio = Math.random) {
  return Number(tasa) > 0 && aleatorio() < Number(tasa);
}

functions.http('enviarSunat', (req, res) => {
  if (debeFallar(process.env.SUNAT_FAIL_RATE)) {
    return res.status(503).json({ aceptado: false, descripcion: 'Servicio de SUNAT no disponible (falla simulada)' });
  }
  const resultado = procesarEnvioSunat(req.body || {});
  if (resultado.aceptado) {
    // Métrica de negocio: Cloud Logging la convierte en una métrica basada en logs
    console.log(JSON.stringify({ evento: 'cdr_aceptado', numeroCdr: resultado.numeroCdr }));
  }
  const status = resultado.aceptado ? 200 : 422;
  return res.status(status).json(resultado);
});

module.exports = { procesarEnvioSunat, debeFallar };
