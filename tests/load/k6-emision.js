// Pruebas de carga del endpoint de emisión (API Gateway -> api-emision -> Workflows)
// Uso:  k6 run -e BASE_URL=https://<gateway> -e API_KEY=<clave> -e ESCENARIO=PC01 tests/load/k6-emision.js
//   PC01: carga sostenida de 500 comprobantes/min durante 10 min   (RNF02, RNF03)
//   PC02: estrés progresivo hasta 1 500 comprobantes/min            (RNF07: autoescalado)
//   PC03: pico súbito (spike) de 1 500 comprobantes/min             (RNF02, RNF01)
import http from 'k6/http';
import { check } from 'k6';

const BASE_URL = __ENV.BASE_URL;
const API_KEY = __ENV.API_KEY;
const ESCENARIO = __ENV.ESCENARIO || 'PC01';

const escenarios = {
  PC01: { executor: 'constant-arrival-rate', rate: 500, timeUnit: '1m', duration: '10m', preAllocatedVUs: 50, maxVUs: 200 },
  PC02: {
    executor: 'ramping-arrival-rate', startRate: 100, timeUnit: '1m', preAllocatedVUs: 100, maxVUs: 500,
    stages: [
      { target: 500, duration: '2m' }, { target: 1000, duration: '3m' },
      { target: 1500, duration: '3m' }, { target: 0, duration: '1m' },
    ],
  },
  PC03: {
    executor: 'ramping-arrival-rate', startRate: 50, timeUnit: '1m', preAllocatedVUs: 100, maxVUs: 500,
    stages: [
      { target: 50, duration: '1m' }, { target: 1500, duration: '30s' },
      { target: 1500, duration: '2m' }, { target: 50, duration: '30s' }, { target: 50, duration: '1m' },
    ],
  },
};

export const options = {
  scenarios: { [ESCENARIO]: escenarios[ESCENARIO] },
  thresholds: {
    http_req_failed: ['rate<0.01'],      // errores < 1 %
    http_req_duration: ['p(95)<2000'],   // respuesta síncrona de la API p95 < 2 s (RNF03)
  },
};

export default function () {
  const numero = `${__VU}${__ITER}${Date.now() % 100000}`;
  const comprobante = {
    tipoComprobante: 'FACTURA', serie: 'F001', numero,
    ruc: '20123456789', razonSocialEmisor: 'Mi Pyme SAC', cliente: 'Cliente de Prueba',
    items: [{ descripcion: 'Servicio de consultoría', cantidad: 1, precioUnitario: 100 }],
    moneda: 'PEN', total: 118,
  };
  const res = http.post(`${BASE_URL}/comprobantes`, JSON.stringify(comprobante), {
    headers: { 'Content-Type': 'application/json', 'x-api-key': API_KEY },
  });
  check(res, { 'respuesta 202': (r) => r.status === 202 });
}
