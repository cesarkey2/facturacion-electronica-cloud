const assert = require('assert');
const { validarComprobante } = require('./index');

const comprobanteValido = {
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

const comprobanteInvalido = {
  tipoComprobante: 'INVALIDO',
  items: [],
};

const erroresValido = validarComprobante(comprobanteValido);
const erroresInvalido = validarComprobante(comprobanteInvalido);

assert.strictEqual(erroresValido.length, 0, 'El comprobante válido no debería tener errores');
assert.ok(erroresInvalido.length > 0, 'El comprobante inválido debería reportar errores');

console.log('OK - comprobante válido:', erroresValido);
console.log('OK - comprobante inválido detecta', erroresInvalido.length, 'errores:');
erroresInvalido.forEach((e) => console.log('  -', e));
console.log('\nTodas las pruebas pasaron correctamente.');
