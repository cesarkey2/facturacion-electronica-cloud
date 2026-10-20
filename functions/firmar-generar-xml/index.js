const functions = require('@google-cloud/functions-framework');
const crypto = require('crypto');

/**
 * Construye el XML UBL 2.1 simplificado del comprobante (RF02/RF03).
 * @param {object} comprobante
 * @returns {string} XML del comprobante
 */
function generarXml(comprobante) {
  const itemsXml = (comprobante.items || [])
    .map(
      (it, i) => `
    <cac:InvoiceLine>
      <cbc:ID>${i + 1}</cbc:ID>
      <cbc:InvoicedQuantity>${it.cantidad}</cbc:InvoicedQuantity>
      <cbc:Description>${it.descripcion}</cbc:Description>
      <cbc:PriceAmount>${it.precioUnitario}</cbc:PriceAmount>
    </cac:InvoiceLine>`
    )
    .join('');

  return `<?xml version="1.0" encoding="UTF-8"?>
<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2">
  <cbc:ID>${comprobante.serie}-${comprobante.numero}</cbc:ID>
  <cbc:InvoiceTypeCode>${comprobante.tipoComprobante}</cbc:InvoiceTypeCode>
  <cbc:DocumentCurrencyCode>${comprobante.moneda}</cbc:DocumentCurrencyCode>
  <cac:AccountingSupplierParty>
    <cbc:RUC>${comprobante.ruc}</cbc:RUC>
    <cbc:RazonSocial>${comprobante.razonSocialEmisor}</cbc:RazonSocial>
  </cac:AccountingSupplierParty>
  <cac:AccountingCustomerParty>
    <cbc:Cliente>${comprobante.cliente}</cbc:Cliente>
  </cac:AccountingCustomerParty>${itemsXml}
  <cbc:LegalMonetaryTotal>${comprobante.total}</cbc:LegalMonetaryTotal>
</Invoice>`;
}

/**
 * Firma local de respaldo (pruebas sin credenciales): hash SHA-256 del XML.
 * @param {string} xml
 * @returns {string} huella SHA-256 en hexadecimal
 */
function firmarXml(xml) {
  return crypto.createHash('sha256').update(xml).digest('hex');
}

/**
 * Firma el XML con la llave asimétrica de Cloud KMS (RSA-2048 / SHA-256).
 * Se inyecta el cliente para poder probar sin llamar a GCP.
 * @returns {Promise<string>} firma en base64
 */
async function firmarConKms(xml, keyVersion, cliente) {
  const digest = crypto.createHash('sha256').update(xml).digest();
  const [resp] = await cliente.asymmetricSign({ name: keyVersion, digest: { sha256: digest } });
  return Buffer.from(resp.signature).toString('base64');
}

/** Guarda el XML en Cloud Storage cuando BUCKET_XML está definido (RF03). */
async function guardarXml(comprobante, xml) {
  const bucket = process.env.BUCKET_XML;
  if (!bucket) return null;
  const { Storage } = require('@google-cloud/storage');
  const objeto = `${comprobante.ruc}/${comprobante.serie}-${comprobante.numero}.xml`;
  await new Storage().bucket(bucket).file(objeto).save(xml, { contentType: 'application/xml' });
  return { bucket, objeto };
}

functions.http('firmarYGenerarXml', async (req, res) => {
  const comprobante = req.body;
  if (!comprobante || !Array.isArray(comprobante.items)) {
    return res.status(400).json({ error: 'Se requiere el comprobante validado en el body' });
  }
  try {
    const xml = generarXml(comprobante);
    let firma; let metodoFirma;
    if (process.env.KMS_KEY_VERSION) {
      const { KeyManagementServiceClient } = require('@google-cloud/kms');
      firma = await firmarConKms(xml, process.env.KMS_KEY_VERSION, new KeyManagementServiceClient());
      metodoFirma = 'KMS-RSA2048-SHA256';
    } else {
      firma = firmarXml(xml);
      metodoFirma = 'SHA256-simulada';
    }
    const almacenado = await guardarXml(comprobante, xml);
    return res.status(200).json({ xml, firma, metodoFirma, almacenado });
  } catch (err) {
    console.error('Error al firmar el comprobante:', err.message);
    return res.status(500).json({ error: 'No se pudo firmar el comprobante' });
  }
});

module.exports = { generarXml, firmarXml, firmarConKms };
