const functions = require('@google-cloud/functions-framework');

const REQUIRED_FIELDS = [
  'tipoComprobante', 'serie', 'numero', 'ruc',
  'razonSocialEmisor', 'cliente', 'items', 'moneda', 'total',
];
const TIPOS_VALIDOS = ['FACTURA', 'BOLETA', 'NOTA_CREDITO'];

/**
 * Valida la estructura y sintaxis mínima de un comprobante contra las reglas
 * exigidas por el estándar UBL 2.1 (RF01 del informe técnico).
 * @param {object} body
 * @returns {string[]} lista de errores (vacía si el comprobante es válido)
 */
function validarComprobante(body) {
  const errores = [];

  for (const field of REQUIRED_FIELDS) {
    if (body[field] === undefined || body[field] === null || body[field] === '') {
      errores.push(`Falta el campo obligatorio: ${field}`);
    }
  }

  if (body.tipoComprobante && !TIPOS_VALIDOS.includes(body.tipoComprobante)) {
    errores.push(`tipoComprobante inválido: ${body.tipoComprobante}`);
  }

  if (Array.isArray(body.items)) {
    if (body.items.length === 0) {
      errores.push('El comprobante debe tener al menos un item');
    }
    body.items.forEach((item, idx) => {
      if (!item.descripcion || typeof item.cantidad !== 'number' || typeof item.precioUnitario !== 'number') {
        errores.push(`Item ${idx} incompleto (requiere descripcion, cantidad, precioUnitario)`);
      }
    });
  } else if (body.items !== undefined) {
    errores.push('El campo items debe ser un arreglo');
  }

  if (body.total !== undefined && typeof body.total !== 'number') {
    errores.push('El campo total debe ser numérico');
  }

  return errores;
}

functions.http('validarComprobante', (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Método no permitido, use POST' });
  }
  const errores = validarComprobante(req.body || {});
  if (errores.length > 0) {
    return res.status(400).json({ valido: false, errores });
  }
  return res.status(200).json({ valido: true, mensaje: 'Comprobante válido según UBL 2.1 (validación estructural)' });
});

module.exports = { validarComprobante };
