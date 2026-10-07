# Documentation — Module 16: Cross-Chain Messaging & Interoperability

**Language:** English · [Español](./README-ES.md)

Design, security, and gas index for the module (AMP over LayerZero v2 / Chainlink CCIP, multi-chain synchronization, remote execution).

| File | Content | Status |
|------|---------|--------|
| [planificacion-EN.md](./planificacion-EN.md) | Phases 0–7, implemented architecture, criteria | ✅ Closed |
| [diagrama-de-clases-EN.md](./diagrama-de-clases-EN.md) | UML: messenger, LZ/CCIP adapters, codec, peers | ✅ Updated |
| [diagrama-de-flujo-EN.md](./diagrama-de-flujo-EN.md) | Decisions: quote → send → verify → execute | ✅ Updated |
| [flujograma-EN.md](./flujograma-EN.md) | E2E source → relayer → destination + anti-replay | ✅ Updated |
| [SWC-AUDIT-EN.md](./SWC-AUDIT-EN.md) | SWC-100–136 matrix (0 vulnerable) | ✅ |
| [GAS-EN.md](./GAS-EN.md) | ABI vs Yul baseline + hot paths | ✅ |
| [DECISIONES-Y-LOGICA-EN.md](./DECISIONES-Y-LOGICA-EN.md) | Technical decisions, logical flow, and gas improvements | ✅ |

**Module status:** Phases **0–7** ✅ (v1 closed).  
**Verified suite:** `forge test` → **81 PASS / 2 SKIP** (dual-fork without `SRC_RPC_URL`/`DST_RPC_URL`).  
**Docs sync:** 2026-09-13 (aligned with `src/` after Phase 7).

Module README: [`../README-EN.md`](../README-EN.md).
