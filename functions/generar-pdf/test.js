const assert = require('assert');
const fs = require('fs');
const { generarPdfBuffer } = require('./index');

const comprobante = {
  tipoComprobante: 'FACTURA',
  serie: 'F001',
  numero: '123',
  ruc: '20123456789',
  razonSocialEmisor: 'Mi Pyme SAC',
  cliente: 'Cliente Final',
  items: [{ descripcion: 'Servicio de consultoría', cantidad: 1, precioUnitario: 100 }],
  moneda: 'PEN',
  total: 100,
};

(async () => {
  const buffer = await generarPdfBuffer(comprobante);
  assert.ok(Buffer.isBuffer(buffer), 'Debe devolver un Buffer');
  assert.ok(buffer.length > 500, 'El PDF generado debe tener contenido');
  assert.strictEqual(buffer.subarray(0, 4).toString(), '%PDF', 'Debe ser un PDF válido');

  fs.writeFileSync('/tmp/comprobante-prueba.pdf', buffer);
  console.log('PDF generado correctamente:', buffer.length, 'bytes');
  console.log('Guardado de prueba en /tmp/comprobante-prueba.pdf');
  console.log('\nTodas las pruebas pasaron correctamente.');
})();
