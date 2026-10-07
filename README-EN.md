# 16 — Cross-Chain Messaging & Interoperability

**Language:** English · [Español](./README-ES.md)

Multi-chain arbitrary message passing (AMP) protocol with **LayerZero Endpoint V2** and **Chainlink CCIP** adapters, trusted peers, anti-replay, and idempotency. Solidity `0.8.24` + Foundry.

**Status:** Phases **0–7** ✅ (module v1 closed).  
**Suite:** `forge test` → **81 PASS / 2 SKIP** (dual-fork without RPC).

## Docs

| File | Content |
|------|---------|
| [`doc/README-EN.md`](./doc/README-EN.md) | Index |
| [`doc/planificacion-EN.md`](./doc/planificacion-EN.md) | Phases, architecture, criteria |
| [`doc/diagrama-de-clases-EN.md`](./doc/diagrama-de-clases-EN.md) | UML |
| [`doc/diagrama-de-flujo-EN.md`](./doc/diagrama-de-flujo-EN.md) | Send/receive decisions |
| [`doc/flujograma-EN.md`](./doc/flujograma-EN.md) | E2E + dual-fork |
| [`doc/SWC-AUDIT-EN.md`](./doc/SWC-AUDIT-EN.md) | SWC-100–136 matrix |
| [`doc/GAS-EN.md`](./doc/GAS-EN.md) | ABI vs Yul + hot paths |
| [`doc/DECISIONES-Y-LOGICA-EN.md`](./doc/DECISIONES-Y-LOGICA-EN.md) | Decisions, logic, and gas improvements |

## Stack

| Layer | Technology |
|-------|------------|
| Contracts | Solidity `0.8.24` (fixed pragma) |
| Tooling | Foundry (`forge` / `cast` / `anvil`) |
| Libraries | OpenZeppelin Contracts v5.2, forge-std |
| Transport | Mock + LayerZero V2 + Chainlink CCIP (mocks in tests) |
| Security | `InvalidSourceSender`, `processedMessages`, quote + Yul refund |

## Setup

```bash
export PATH="$HOME/.foundry/bin:$PATH"

forge build
forge test
forge snapshot --match-contract CodecGasTest
```

Dependencies (already in `lib/`; reinstall if needed):

```bash
forge install foundry-rs/forge-std@v1.16.2 --no-git --shallow
forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-git --shallow
```

Dual-fork (optional):

```bash
# In `.env` (copy from `.env.example`)
SRC_RPC_URL=https://...
DST_RPC_URL=https://...
forge test --match-path 'test/fork/*'
```

Relay simulation (local):

```bash
forge script script/SimulateRelay.s.sol:SimulateRelay -vvv
```

## Local deploy

```bash
anvil   # another terminal
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: see `.env.example` (`PRIVATE_KEY`, `SRC_RPC_URL`, `DST_RPC_URL`, `FEE_WEI`, `CHAIN_A`, `CHAIN_B`).
