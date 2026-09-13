# Documentación — Módulo 16: Cross-Chain Messaging & Interoperability

Índice de diseño, seguridad y gas del módulo (AMP LayerZero v2 / Chainlink CCIP, sincronización multi-cadena, ejecución remota).

| Archivo | Contenido | Estado |
|---------|-----------|--------|
| [planificacion.md](./planificacion.md) | Fases 0–7, arquitectura implementada, criterios | ✅ Cerrado |
| [diagrama-de-clases.md](./diagrama-de-clases.md) | UML: messenger, adapters LZ/CCIP, codec, peers | ✅ Actualizado |
| [diagrama-de-flujo.md](./diagrama-de-flujo.md) | Decisiones: quote → send → verify → execute | ✅ Actualizado |
| [flujograma.md](./flujograma.md) | E2E origen → relayer → destino + anti-replay | ✅ Actualizado |
| [SWC-AUDIT.md](./SWC-AUDIT.md) | Matriz SWC-100–136 (0 vulnerables) | ✅ |
| [GAS.md](./GAS.md) | Baseline ABI vs Yul + hot paths | ✅ |

**Estado del módulo:** Fases **0–7** ✅ (v1 cerrado).  
**Suite:** `forge test` → **81 PASS / 2 SKIP** (dual-fork sin RPC).

README del módulo: [`../README.md`](../README.md).
