const assert = require('assert');
const { iniciarEjecucion, validarCuerpo } = require('./index');

(async () => {
  // 1) validación mínima del cuerpo
  assert.deepStrictEqual(validarCuerpo({ serie: 'F001', numero: '1', ruc: '20123456789', items: [] }), []);
  assert.strictEqual(validarCuerpo({}).length, 4);

  // 2) inicio de ejecución con un cliente simulado (sin llamar a GCP)
  let recibido;
  const clienteFalso = {
    createExecution: async (req) => {
      recibido = req;
      return [{ name: 'projects/p/locations/us-central1/workflows/proceso-facturacion/executions/abc123' }];
    },
  };
  const nombre = await iniciarEjecucion({ serie: 'F001', numero: '1' }, clienteFalso, 'projects/p/locations/us-central1/workflows/proceso-facturacion');
  assert.ok(nombre.endsWith('/executions/abc123'));
  assert.strictEqual(JSON.parse(recibido.execution.argument).serie, 'F001');

  console.log('Ejecución iniciada:', nombre);
  console.log('\nTodas las pruebas pasaron correctamente.');
})();
