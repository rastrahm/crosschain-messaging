# Documentación — Módulo 16: Cross-Chain Messaging & Interoperability

**Idioma:** Español · [English](./README-EN.md)

Índice de diseño, seguridad y gas del módulo (AMP LayerZero v2 / Chainlink CCIP, sincronización multi-cadena, ejecución remota).

| Archivo | Contenido | Estado |
|---------|-----------|--------|
| [planificacion-ES.md](./planificacion-ES.md) | Fases 0–7, arquitectura implementada, criterios | ✅ Cerrado |
| [diagrama-de-clases-ES.md](./diagrama-de-clases-ES.md) | UML: messenger, adapters LZ/CCIP, codec, peers | ✅ Actualizado |
| [diagrama-de-flujo-ES.md](./diagrama-de-flujo-ES.md) | Decisiones: quote → send → verify → execute | ✅ Actualizado |
| [flujograma-ES.md](./flujograma-ES.md) | E2E origen → relayer → destino + anti-replay | ✅ Actualizado |
| [SWC-AUDIT-ES.md](./SWC-AUDIT-ES.md) | Matriz SWC-100–136 (0 vulnerables) | ✅ |
| [GAS-ES.md](./GAS-ES.md) | Baseline ABI vs Yul + hot paths | ✅ |
| [DECISIONES-Y-LOGICA-ES.md](./DECISIONES-Y-LOGICA-ES.md) | Decisiones técnicas, flujo lógico y mejoras de gas | ✅ |

**Estado del módulo:** Fases **0–7** ✅ (v1 cerrado).  
**Suite verificada:** `forge test` → **81 PASS / 2 SKIP** (dual-fork sin `SRC_RPC_URL`/`DST_RPC_URL`).  
**Sync docs:** 2026-09-13 (alineado a `src/` post Fase 7).

README del módulo: [`../README-ES.md`](../README-ES.md).
