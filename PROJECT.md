# Crypto Tracker — Contexto de Negocio

Este documento es la referencia funcional principal de Crypto Tracker. Resume el
propósito del negocio, el dolor operativo actual y los resultados esperados.

## Propósito

Darle a un inversor de criptomonedas una herramienta propia para registrar,
gestionar y analizar su portafolio de criptoactivos, sin depender de exchanges
centralizados, plataformas de terceros (tipo CoinStats o Delta) ni sus costos,
límites o condiciones de servicio.

## Dolor del Negocio

- Depender de múltiples exchanges (Binance, Coinbase, Kraken, wallets como
  MetaMask, Phantom, Ledger) para ver el estado del portafolio, sin una visión
  consolidada.
- Pérdida de trazabilidad de movimientos: compras, ventas, transferencias entre
  wallets, swaps, fees — todo disperso en diferentes plataformas.
- Cálculos manuales o en hojas de cálculo para determinar ganancias/pérdidas,
  costos promedio, y distribución del portafolio.
- Dificultad para reconciliar balances cuando hay movimientos entre wallets o
  exchanges, especialmente con comisiones.
- Nula capacidad de analizar el rendimiento histórico del portafolio en el
  tiempo, sin gráficos de evolución ni snapshots diarios.
- Riesgo de perder datos si un exchange cierra, cambia sus APIs, o si el usuario
  pierde acceso a su cuenta.

## Solución Propuesta

Una aplicación propia (macOS + iOS), de uso personal, donde el usuario pueda:

- Registrar criptomonedas, wallets (carteras), y monedas fiat con sus tasas de
  cambio.
- Registrar todos los tipos de movimientos: entrada (compra), salida (venta),
  transferencia entre wallets, y swaps de una crypto a otra.
- Ver el portafolio consolidado: valor total invertido, valor actual, ganancias
  realizadas y no realizadas, distribución por crypto y por wallet.
- Sincronizar precios actuales desde APIs públicas (CoinGecko) y mantener un
  histórico de precios para análisis de rendimiento.
- Importar datos iniciales desde archivos CSV (catálogos) y Excel (movimientos)
  para migración desde otras herramientas.
- Exportar backups completos del portafolio para seguridad y portabilidad.
- Analizar el rendimiento del portafolio en el tiempo con gráficos de evolución,
  distribución, y comparativas.

## Resultados Esperados

- Eliminar la dependencia de plataformas de terceros para el tracking del
  portafolio de criptoactivos.
- Tener una visión consolidada y actualizada de todo el portafolio en un solo
  lugar, sin importar en qué exchange o wallet estén los activos.
- Reducir el tiempo que toma calcular ganancias/pérdidas y reconciliar balances.
- Mejorar la toma de decisiones de inversión con análisis visual del rendimiento
  histórico y distribución del portafolio.
- Contar con una base de datos propia, respaldada y portable, que no dependa de
  la continuidad de ningún servicio externo.
- Tener una herramienta que pueda crecer hacia más módulos (alertas de precios,
  integración con exchanges vía APIs, reportes fiscales) conforme el usuario lo
  requiera.


## Público Objetivo

- Inversores de criptomonedas que operan en múltiples exchanges y wallets.
- Usuarios técnicos que prefieren herramientas propias sobre SaaS de terceros.
- Personas que necesitan trazabilidad completa de sus movimientos para análisis
  fiscal o de rendimiento.
- Early adopters del ecosistema crypto que valoran la soberanía de datos.
