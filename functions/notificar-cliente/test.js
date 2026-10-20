const assert = require('assert');
const { construirNotificacion } = require('./index');

const comprobante = {
  serie: 'F001',
  numero: '123',
  cliente: 'Cliente Final',
  tipoComprobante: 'FACTURA',
  moneda: 'PEN',
  total: 100,
  emailCliente: 'cliente@empresa.com',
};

const notif = construirNotificacion(comprobante);
assert.strictEqual(notif.para, 'cliente@empresa.com');
assert.ok(notif.asunto.includes('F001-123'));
assert.ok(notif.cuerpo.includes('100'));

console.log('Notificación construida:', notif);
console.log('\nTodas las pruebas pasaron correctamente.');
