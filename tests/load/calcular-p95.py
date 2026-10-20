#!/usr/bin/env python3
"""Calcula el tiempo de procesamiento extremo a extremo (p50/p95/p99) a partir de las ejecuciones
de Cloud Workflows. Uso:
  gcloud workflows executions list proceso-facturacion --location=us-central1 --limit=1000 \
    --format="value(startTime,endTime,state)" | python3 tests/load/calcular-p95.py
"""
import sys
from datetime import datetime


def parse(ts):
    return datetime.fromisoformat(ts.replace('Z', '+00:00'))


def percentil(valores, p):
    valores = sorted(valores)
    if not valores:
        return float('nan')
    k = (len(valores) - 1) * p / 100
    f, c = int(k), min(int(k) + 1, len(valores) - 1)
    return valores[f] + (valores[c] - valores[f]) * (k - f)


def main(lineas):
    duraciones, estados = [], {}
    for linea in lineas:
        partes = linea.split()
        if len(partes) < 3:
            continue
        inicio, fin, estado = partes[0], partes[1], partes[2]
        estados[estado] = estados.get(estado, 0) + 1
        if estado == 'SUCCEEDED':
            duraciones.append((parse(fin) - parse(inicio)).total_seconds())
    total = sum(estados.values())
    print(f'Ejecuciones: {total}  Estados: {estados}')
    if duraciones:
        print(f'Duración (s)  p50={percentil(duraciones, 50):.2f}  p95={percentil(duraciones, 95):.2f}  p99={percentil(duraciones, 99):.2f}')
        print('Cumple RNF03 (p95 < 5 s):', 'SÍ' if percentil(duraciones, 95) < 5 else 'NO')
    if total:
        fallidas = total - estados.get('SUCCEEDED', 0)
        print(f'Tasa de error: {100 * fallidas / total:.2f}%  (meta < 1%)')


if __name__ == '__main__':
    main(sys.stdin.read().splitlines())
