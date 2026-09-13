# 16 — Cross-Chain Messaging & Interoperability

Protocolo de arbitrary message passing (AMP) multi-cadena con adapters **LayerZero Endpoint V2** y **Chainlink CCIP**, peers trusted, anti-replay e idempotencia. Solidity `0.8.24` + Foundry.

**Estado:** Fases **0–7** ✅ (módulo v1 cerrado).  
**Suite:** `forge test` → **81 PASS / 2 SKIP** (dual-fork sin RPC).

## Docs

| Archivo | Contenido |
|---------|-----------|
| [`doc/README.md`](./doc/README.md) | Índice |
| [`doc/planificacion.md`](./doc/planificacion.md) | Fases, arquitectura, criterios |
| [`doc/diagrama-de-clases.md`](./doc/diagrama-de-clases.md) | UML |
| [`doc/diagrama-de-flujo.md`](./doc/diagrama-de-flujo.md) | Decisiones send/receive |
| [`doc/flujograma.md`](./doc/flujograma.md) | E2E + dual-fork |
| [`doc/SWC-AUDIT.md`](./doc/SWC-AUDIT.md) | Matriz SWC-100–136 |
| [`doc/GAS.md`](./doc/GAS.md) | ABI vs Yul + hot paths |

## Stack

| Capa | Tecnología |
|------|------------|
| Contratos | Solidity `0.8.24` (pragma fijo) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Librerías | OpenZeppelin Contracts v5.2, forge-std |
| Transporte | Mock + LayerZero V2 + Chainlink CCIP (mocks en tests) |
| Seguridad | `InvalidSourceSender`, `processedMessages`, quote + refund Yul |

## Setup

```bash
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
forge snapshot --match-contract CodecGasTest
```

Dependencias (ya en `lib/`; reinstalar si hace falta):

```bash
forge install foundry-rs/forge-std@v1.16.2 --no-git --shallow
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git --shallow
```

Dual-fork (opcional):

```bash
# En `.env` (copiar desde `.env.example`)
SRC_RPC_URL=https://...
DST_RPC_URL=https://...
forge test --match-path 'test/fork/*'
```

Simulación de relay (local):

```bash
forge script script/SimulateRelay.s.sol:SimulateRelay -vvv
```

## Deploy local

```bash
anvil   # otra terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: ver `.env.example` (`PRIVATE_KEY`, `SRC_RPC_URL`, `DST_RPC_URL`, `FEE_WEI`, `CHAIN_A`, `CHAIN_B`).
