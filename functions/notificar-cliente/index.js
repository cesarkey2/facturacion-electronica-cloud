const functions = require('@google-cloud/functions-framework');

/**
 * Construye la notificación multicanal del comprobante (RF05). En producción
 * se integraría con SendGrid o Gmail API; en este prototipo se registra la
 * notificación (console.log) para verificar el flujo sin exponer credenciales
 * de correo reales.
 * @param {object} comprobante
 */
function construirNotificacion(comprobante) {
  return {
    para: comprobante.emailCliente || 'cliente@example.com',
    asunto: `Comprobante ${comprobante.serie}-${comprobante.numero}`,
    cuerpo:
      `Estimado(a) ${comprobante.cliente}, adjuntamos su comprobante ` +
      `${comprobante.tipoComprobante} ${comprobante.serie}-${comprobante.numero} ` +
      `por un total de ${comprobante.moneda} ${comprobante.total}.`,
  };
}

functions.http('notificarCliente', (req, res) => {
  const comprobante = req.body || {};
  if (!comprobante.serie || !comprobante.numero) {
    return res.status(400).json({ error: 'Se requiere serie y numero del comprobante' });
  }
  const notificacion = construirNotificacion(comprobante);
  console.log('Enviando notificación:', notificacion);
  return res.status(200).json({ enviado: true, ...notificacion });
});

module.exports = { construirNotificacion };
