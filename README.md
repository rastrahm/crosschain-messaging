# 16 — Cross-Chain Messaging & Interoperability

Protocolo de arbitrary message passing (AMP) multi-cadena con adapters **LayerZero Endpoint V2** y **Chainlink CCIP**, peers trusted, anti-replay e idempotencia. Solidity `0.8.24` + Foundry.

**Estado:** Fases **0–7** ✅ (módulo v1 cerrado).

## Docs

Ver [`doc/`](./doc/README.md) — planificación, diagramas de clases/flujo y flujograma.

## Stack

| Capa | Tecnología |
|------|------------|
| Contratos | Solidity `0.8.24` (pragma fijo) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Librerías | OpenZeppelin Contracts v5.2, forge-std |
| Transporte | LayerZero V2 + Chainlink CCIP (mocks en tests) |
| Seguridad | `InvalidSourceSender`, `processedMessages`, quote + refund ETH |

## Setup

```bash
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
```

Dependencias (ya en `lib/`; reinstalar si hace falta):

```bash
forge install foundry-rs/forge-std@v1.16.2 --no-git --shallow
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git --shallow
```

Dual-fork (Fase 6):

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

Env: ver `.env.example` (`PRIVATE_KEY`, `SRC_RPC_URL`, `DST_RPC_URL`, `MAINNET_RPC_URL`).

## Autorización de fases

No se implementa una fase hasta *“autorizo Fase N”*. Detalle: [`doc/planificacion.md`](./doc/planificacion.md).
