# Optimización de gas — Cross-Chain Messaging & Interoperability

Regenerar:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract CodecGasTest --gas-report
forge snapshot --match-contract CodecGasTest
```

**Fecha baseline:** 2026-09-13 (Fase 7)  
**Snapshot:** `.gas-snapshot` (`test/gas/Codec.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = true`, solc `0.8.24`

---

## Baseline operaciones

Medición = gas del **test Foundry** (incluye mocks de transport/relayer donde aplica).

| Path | Gas (snapshot) | Notas |
|------|----------------|-------|
| `testGas_codec_decodeAbi` | **31 869** | `abi.decode` portable |
| `testGas_codec_decodeYul` | **30 829** | Packed + Yul (wire adapters) |
| `testGas_codec_messageHashMemory` | **24 476** | Hash desde memory |
| `testGas_codec_messageHashCalldata` | **24 933** | Hash vía external calldata (ver nota) |
| `testGas_refund_call` | **24 083** | `FeeRefundLib.refundExcess` |
| `testGas_refund_assembly` | **24 019** | `refundExcessAssembly` (send) |
| `testGas_messenger_sendExactFee` | **294 919** | Send sin exceso |
| `testGas_messenger_sendWithRefund` | **301 518** | Send + refund |
| `testGas_messenger_receive` | **362 756** | Send origen + relay destino + mock app |

### Lectura

- **`decodeYul` vs ABI:** ~**1 040 gas** a favor de packed/Yul (mismo payload de muestra).
- **`refundExcessAssembly` vs `.call`:** ~**64 gas** a favor de Yul en refund aislado.
- **`messageHashCalldata` en el harness** puede medir *más* que memory porque el test re-ABI-encodea el struct al llamar al harness. En producción, `receivePacket(Packet calldata)` ya tiene calldata: `messageHashCalldata` evita la copia memory del struct completo.
- LZ/CCIP e2e bajaron tras wire packed (p. ej. LZ e2e ~754k → ~686k en suite).

---

## Optimizaciones aplicadas (Fase 7)

| Técnica | Dónde | Efecto |
|---------|-------|--------|
| `encodePacked` / `decodeYul` | Adapters LZ + CCIP | Menos overhead que ABI en wire |
| `messageHashCalldata` | `receivePacket` | Sin copia memory del `Packet` |
| `_selfPeer` immutable | Messenger | Evita `addressToBytes32(this)` por tx |
| `refundExcessAssembly` | `send` | Yul `call` sin returndata |
| `encodePacked` en Yul | `PacketCodec` | Sin `bytes.concat` multi-alloc |
| Custom errors | `MessagingErrors` | Más barato que `require` strings |
| Cache `adapter_` / `receiver_` | Messenger | Menos SLOAD |
| `optimizer_runs = 10_000` + `via_ir` | `foundry.toml` | Inlining |

### Tradeoff: ABI vs packed

- **ABI** (`encode`/`decode`): portable, debuggable, tests de codec.
- **Packed Yul**: wire de adapters v1; debe coincidir exactamente el layout 120 B + payload.

---

## Deploy

```bash
anvil   # otra terminal
export PATH="$HOME/.foundry/bin:$PATH"
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: `PRIVATE_KEY`, `FEE_WEI`, `CHAIN_A`, `CHAIN_B`. Ver `script/Deploy.s.sol` y `.env.example`.

Sim relay: `forge script script/SimulateRelay.s.sol:SimulateRelay -vvv`

README: [`../README.md`](../README.md) · Índice docs: [`README.md`](./README.md) · SWC: [`SWC-AUDIT.md`](./SWC-AUDIT.md)
