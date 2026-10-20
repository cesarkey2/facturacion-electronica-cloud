const assert = require('assert');
const { procesarEnvioSunat, debeFallar } = require('./index');

const aceptado = procesarEnvioSunat({ xml: '<Invoice/>', firmaSha256: 'abc123' });
const aceptadoKms = procesarEnvioSunat({ xml: '<Invoice/>', firma: 'base64firma' });
assert.strictEqual(aceptadoKms.aceptado, true, 'Debe aceptar la firma de KMS (campo firma)');
const rechazado = procesarEnvioSunat({});

assert.strictEqual(aceptado.aceptado, true, 'Debe aceptar un comprobante firmado');
assert.ok(aceptado.numeroCdr.startsWith('CDR-'), 'Debe generar un número de CDR');

assert.strictEqual(rechazado.aceptado, false, 'Debe rechazar un comprobante sin firma');
assert.strictEqual(rechazado.codigo, '2000');

assert.strictEqual(debeFallar('0'), false);
assert.strictEqual(debeFallar(undefined), false);
assert.strictEqual(debeFallar('1', () => 0.5), true);
assert.strictEqual(debeFallar('0.5', () => 0.9), false);

console.log('Caso aceptado ->', aceptado);
console.log('Caso rechazado ->', rechazado);
console.log('\nTodas las pruebas pasaron correctamente.');
