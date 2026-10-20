const assert = require('assert');
const { decodificarMensaje, guardarComprobante } = require('./index');

const comprobante = { serie: 'F001', numero: '123', ruc: '20123456789', cliente: 'Cliente Final', total: 100, moneda: 'PEN', estado: 'ACEPTADO' };
const sobre = { message: { data: Buffer.from(JSON.stringify(comprobante)).toString('base64') } };

(async () => {
  assert.deepStrictEqual(decodificarMensaje(sobre), comprobante);
  assert.throws(() => decodificarMensaje({}), /inválido/);

  // Cliente de BD simulado: verifica que el INSERT sea un upsert idempotente
  let sqlRecibido; let paramsRecibidos;
  const dbFalsa = { query: async (sql, params) => { sqlRecibido = sql; paramsRecibidos = params; return { rows: [{ id: 7 }] }; } };
  const id = await guardarComprobante(comprobante, dbFalsa);
  assert.strictEqual(id, 7);
  assert.ok(/ON CONFLICT \(ruc_emisor, serie, numero\) DO UPDATE/.test(sqlRecibido), 'Debe ser un upsert idempotente');
  assert.strictEqual(paramsRecibidos[2], '20123456789');

  console.log('Mensaje decodificado y upsert verificado (id =', id + ')');
  console.log('\nTodas las pruebas pasaron correctamente.');
})();
