const assert = require('assert');
const { generarXml, firmarXml, firmarConKms } = require('./index');

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

const xml = generarXml(comprobante);
assert.ok(xml.includes('F001-123'), 'El XML debe incluir serie-numero');
assert.ok(xml.includes('20123456789'), 'El XML debe incluir el RUC');

const firma1 = firmarXml(xml);
const firma2 = firmarXml(xml);
assert.strictEqual(firma1, firma2, 'La firma debe ser determinística para el mismo XML');
assert.strictEqual(firma1.length, 64, 'SHA-256 en hex debe tener 64 caracteres');

(async () => {
  // Firma con KMS usando un cliente simulado: verifica el digest SHA-256 enviado a KMS
  let pedido;
  const kmsFalso = { asymmetricSign: async (req) => { pedido = req; return [{ signature: Buffer.from('firma-demo') }]; } };
  const firmaKms = await firmarConKms(xml, 'projects/p/locations/l/keyRings/k/cryptoKeys/c/cryptoKeyVersions/1', kmsFalso);
  assert.strictEqual(firmaKms, Buffer.from('firma-demo').toString('base64'));
  assert.strictEqual(pedido.digest.sha256.length, 32, 'KMS recibe el digest SHA-256 (32 bytes)');
  console.log('Firma KMS (simulada) base64:', firmaKms);
})().then(() => {
console.log('XML generado:\n', xml);
console.log('\nFirma SHA-256:', firma1);
console.log('\nTodas las pruebas pasaron correctamente.');
});
