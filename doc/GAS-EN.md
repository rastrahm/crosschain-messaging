# Gas optimization — Cross-Chain Messaging & Interoperability

**Language:** English · [Español](./GAS-ES.md)

Regenerate:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --match-contract CodecGasTest --gas-report
forge snapshot --match-contract CodecGasTest
```

**Baseline date:** 2026-09-13 (Phase 7)  
**Snapshot:** `.gas-snapshot` (`test/gas/Codec.gas.t.sol`)  
**Optimizer:** `optimizer_runs = 10_000`, `via_ir = true`, solc `0.8.24`

---

## Operation baseline

Measurement = gas of the **Foundry test** (includes transport/relayer mocks where applicable).

| Path | Gas (snapshot) | Notes |
|------|----------------|-------|
| `testGas_codec_decodeAbi` | **31 869** | Portable `abi.decode` |
| `testGas_codec_decodeYul` | **30 829** | Packed + Yul (adapter wire) |
| `testGas_codec_messageHashMemory` | **24 476** | Hash from memory |
| `testGas_codec_messageHashCalldata` | **24 933** | Hash via external calldata (see note) |
| `testGas_refund_call` | **24 083** | `FeeRefundLib.refundExcess` |
| `testGas_refund_assembly` | **24 019** | `refundExcessAssembly` (send) |
| `testGas_messenger_sendExactFee` | **294 919** | Send without excess |
| `testGas_messenger_sendWithRefund` | **301 518** | Send + refund |
| `testGas_messenger_receive` | **362 756** | Source send + destination relay + mock app |

### Reading

- **`decodeYul` vs ABI:** ~**1 040 gas** in favor of packed/Yul (same sample payload).
- **`refundExcessAssembly` vs `.call`:** ~**64 gas** in favor of Yul for an isolated refund.
- **`messageHashCalldata` in the harness** may measure *more* than memory because the test re-ABI-encodes the struct when calling the harness. In production, `receivePacket(Packet calldata)` already has calldata: `messageHashCalldata` avoids copying the whole struct to memory.
- LZ/CCIP e2e dropped after the packed wire (e.g. LZ e2e ~754k → ~686k in the suite).

---

## Applied optimizations (Phase 7)

| Technique | Where | Effect |
|-----------|-------|--------|
| `encodePacked` / `decodeYul` | LZ + CCIP adapters | Less overhead than ABI on the wire |
| `messageHashCalldata` | `receivePacket` | No memory copy of the `Packet` |
| Immutable `_selfPeer` | Messenger | Avoids `addressToBytes32(this)` per tx |
| `refundExcessAssembly` | `send` | Yul `call` without returndata |
| `encodePacked` in Yul | `PacketCodec` | No multi-alloc `bytes.concat` |
| Custom errors | `MessagingErrors` | Cheaper than `require` strings |
| Cached `adapter_` / `receiver_` | Messenger | Fewer SLOADs |
| `optimizer_runs = 10_000` + `via_ir` | `foundry.toml` | Inlining |

### Tradeoff: ABI vs packed

- **ABI** (`encode`/`decode`): portable, debuggable, codec tests.
- **Packed Yul**: v1 adapter wire; the 120 B + payload layout must match exactly.

---

## Deploy

```bash
anvil   # another terminal
export PATH="$HOME/.foundry/bin:$PATH"
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

Env: `PRIVATE_KEY`, `FEE_WEI`, `CHAIN_A`, `CHAIN_B`. See `script/Deploy.s.sol` and `.env.example`.

Relay sim: `forge script script/SimulateRelay.s.sol:SimulateRelay -vvv`

README: [`../README-EN.md`](../README-EN.md) · Docs index: [`README-EN.md`](./README-EN.md) · SWC: [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md)
