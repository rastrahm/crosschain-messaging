# 16 — Cross-Chain Messaging & Interoperability

Multi-chain arbitrary message passing (AMP) with **LayerZero V2** and **Chainlink CCIP** adapters, trusted peers, anti-replay, and Yul fee refunds. Solidity `0.8.24` + Foundry.

Protocolo de mensajería arbitraria (AMP) multi-cadena con adapters **LayerZero V2** y **Chainlink CCIP**, peers trusted, anti-replay y refund de fees en Yul. Solidity `0.8.24` + Foundry.

## Documentation / Documentación

| | English | Español |
|---|---------|---------|
| Module README | [README-EN.md](./README-EN.md) | [README-ES.md](./README-ES.md) |
| Docs index | [doc/README-EN.md](./doc/README-EN.md) | [doc/README-ES.md](./doc/README-ES.md) |
| Planning | [planificacion-EN.md](./doc/planificacion-EN.md) | [planificacion-ES.md](./doc/planificacion-ES.md) |
| Decisions & logic | [DECISIONES-Y-LOGICA-EN.md](./doc/DECISIONES-Y-LOGICA-EN.md) | [DECISIONES-Y-LOGICA-ES.md](./doc/DECISIONES-Y-LOGICA-ES.md) |
| Class diagram | [diagrama-de-clases-EN.md](./doc/diagrama-de-clases-EN.md) | [diagrama-de-clases-ES.md](./doc/diagrama-de-clases-ES.md) |
| Flow diagram | [diagrama-de-flujo-EN.md](./doc/diagrama-de-flujo-EN.md) | [diagrama-de-flujo-ES.md](./doc/diagrama-de-flujo-ES.md) |
| Flowchart | [flujograma-EN.md](./doc/flujograma-EN.md) | [flujograma-ES.md](./doc/flujograma-ES.md) |
| SWC audit | [SWC-AUDIT-EN.md](./doc/SWC-AUDIT-EN.md) | [SWC-AUDIT-ES.md](./doc/SWC-AUDIT-ES.md) |
| Gas | [GAS-EN.md](./doc/GAS-EN.md) | [GAS-ES.md](./doc/GAS-ES.md) |

## Quick start

```bash
forge build
forge test   # 81 PASS / 2 SKIP (dual-fork without RPC)
```
