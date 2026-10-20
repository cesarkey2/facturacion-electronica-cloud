const functions = require('@google-cloud/functions-framework');
const PDFDocument = require('pdfkit');

/**
 * Genera la representación impresa (RIDE) del comprobante en PDF (RF03).
 * @param {object} comprobante
 * @returns {Promise<Buffer>}
 */
function generarPdfBuffer(comprobante) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A4', margin: 40 });
    const chunks = [];
    doc.on('data', (chunk) => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    doc.fontSize(16).text(`${comprobante.tipoComprobante} ${comprobante.serie}-${comprobante.numero}`, {
      align: 'center',
    });
    doc.moveDown();
    doc.fontSize(10).text(`Emisor: ${comprobante.razonSocialEmisor}  (RUC ${comprobante.ruc})`);
    doc.text(`Cliente: ${comprobante.cliente}`);
    doc.moveDown();

    (comprobante.items || []).forEach((it) => {
      doc.text(`${it.descripcion}   x${it.cantidad}   S/ ${it.precioUnitario}`);
    });

    doc.moveDown();
    doc.fontSize(12).text(`TOTAL: ${comprobante.moneda} ${comprobante.total}`, { align: 'right' });
    doc.end();
  });
}

/** Guarda el PDF en Cloud Storage cuando BUCKET_PDF está definido (RF03). */
async function guardarPdf(comprobante, buffer) {
  const bucket = process.env.BUCKET_PDF;
  if (!bucket) return null;
  const { Storage } = require('@google-cloud/storage');
  const objeto = `${comprobante.ruc}/${comprobante.serie}-${comprobante.numero}.pdf`;
  await new Storage().bucket(bucket).file(objeto).save(buffer, { contentType: 'application/pdf' });
  return { bucket, objeto };
}

functions.http('generarPdf', async (req, res) => {
  try {
    const comprobante = req.body || {};
    const pdfBuffer = await generarPdfBuffer(comprobante);
    const almacenado = await guardarPdf(comprobante, pdfBuffer);
    if (almacenado) {
      // En la nube: se guarda en Cloud Storage y se responde JSON (apto para Cloud Workflows)
      return res.status(200).json({ generado: true, bytes: pdfBuffer.length, almacenado });
    }
    // Local: se devuelve el PDF directamente
    res.setHeader('Content-Type', 'application/pdf');
    return res.status(200).send(pdfBuffer);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

module.exports = { generarPdfBuffer };
