const I18N = {
  es: {
    'html.lang': 'es',
    'meta.title': 'Cross-Chain Messaging — Rolando Strahm',
    'meta.description':
      'Protocolo AMP multi-cadena: LayerZero V2 + CCIP, gas ABI vs Yul y auditoría SWC. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Proyecto',
    'nav.pillars': 'Pilares',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Proceso',
    'nav.attacks': 'Ataques',
    'nav.repos': 'Repos',
    'nav.close': '← Cerrar',

    'hero.tag': '// MÓDULO 16 · PORTFOLIO WEB3',
    'hero.title': 'CROSS-CHAIN<br>MESSAGING',
    'hero.role': 'Solidity 0.8.24 · Foundry · LayerZero V2 · CCIP · Gas · SWC',
    'hero.sub':
      'Arbitrary message passing multi-cadena: peers trusted, anti-replay, quote+refund Yul, adapters LayerZero V2 y Chainlink CCIP, y demo de stake remoto. Gas documentado + matriz SWC-100–136.',
    'hero.cta1': 'Ver en GitHub',
    'hero.cta2': 'Ver en GitLab',

    'ov.eyebrow': '// 01 — CONTEXTO',
    'ov.title': 'Por qué este proyecto',
    'ov.lead':
      'Tras el bridge de tokens, construí la capa de <strong>AMP</strong>: <strong>CrossChainMessenger</strong>, adapters <strong>LayerZero V2</strong> y <strong>CCIP</strong>, y <strong>RemoteStakeReceiver</strong>. El foco es <strong>anti-spoofing</strong> (<code>InvalidSourceSender</code>), <strong>anti-replay</strong> (<code>processedMessages</code>), <strong>fees con refund Yul</strong> y <strong>SWC</strong> con tests que demuestran que el misuse falla.',

    'pi.eyebrow': '// 02 — TRES PILARES',
    'pi.title': 'Qué entrega el módulo',
    'p1.num': '// PILAR_01',
    'p1.title': 'Mensajería AMP',
    'p1.desc':
      'Quote → send → relay → receive: peers, deliverer, PacketCodec y hook de app opcional.',
    'p1.l1': 'InvalidSourceSender + UnauthorizedCaller',
    'p1.l2': 'processedMessages → MessageAlreadyProcessed',
    'p1.l3': 'CEI + ReentrancyGuard + Ownable2Step',
    'p2.num': '// PILAR_02',
    'p2.title': 'Optimización de gas',
    'p2.desc':
      'Wire packed Yul en adapters, messageHashCalldata, _selfPeer immutable y refundExcessAssembly.',
    'p2.l1': 'decodeYul −1 040 gas vs ABI',
    'p2.l2': 'Refund Yul −64 gas vs .call',
    'p2.l3': '.gas-snapshot + optimizer 10k + via_ir',
    'p3.num': '// PILAR_03',
    'p3.title': 'Verificación SWC',
    'p3.desc':
      'Matriz SWC-100–136, UnauthorizedSender, ReplayProtection, fuzz ≥ 1000 y dual-fork opcional.',
    'p3.l1': '0 vulnerabilidades explotables',
    'p3.l2': '30 mitigados / N/A · 6 info',
    'p3.l3': '81 tests Foundry PASS · 2 SKIP fork',

    'gas.eyebrow': '// 03 — OPTIMIZACIÓN DE GAS',
    'gas.title': 'Hot path barato, tradeoffs claros',
    'gas.lead':
      'Fase 7: baseline en <code>doc/GAS.md</code> y <code>.gas-snapshot</code>. Paths: <strong>decodeYul 30 829</strong> vs <strong>ABI 31 869</strong>, <strong>refund Yul 24 019</strong> vs <strong>.call 24 083</strong>, send exact fee ~294 919. Cada técnica tiene tradeoff explícito.',
    'gas.th1': 'Optimización',
    'gas.th2': 'Tradeoff / efecto',
    'gas.r1a': 'encodePacked / decodeYul (adapters)',
    'gas.r1b': 'Wire 120 B + payload; −1 040 gas vs abi.decode',
    'gas.r2a': 'messageHashCalldata',
    'gas.r2b': 'Sin copiar Packet a memory en receivePacket',
    'gas.r3a': '_selfPeer immutable',
    'gas.r3b': 'Evita addressToBytes32(this) en cada tx',
    'gas.r4a': 'FeeRefundLib.refundExcessAssembly',
    'gas.r4b': 'Yul call sin returndata; −64 gas vs .call',
    'gas.r5a': 'encodePacked en Yul (mcopy)',
    'gas.r5b': 'Sin bytes.concat multi-alloc',
    'gas.r6a': 'Custom errors (MessagingErrors)',
    'gas.r6b': 'Reverts compactos vs require strings',
    'gas.r7a': 'optimizer_runs = 10_000 + via_ir',
    'gas.r7b': 'Inlining agresivo en hot path Foundry',

    'swc.eyebrow': '// 04 — VERIFICACIÓN SWC',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Matriz <strong>SWC-100 → SWC-136</strong> sobre messenger, adapters LZ/CCIP, PacketCodec y FeeRefundLib. Informe: <code>doc/SWC-AUDIT.md</code>. Conclusión: <strong>0 vulnerabilidades explotables</strong> en el alcance v1.',
    'swc.s1': 'Mitigados / N/A',
    'swc.s2': 'Informativos (diseño)',
    'swc.s3': 'Vulnerables',
    'swc.th1': 'SWC clave',
    'swc.th2': 'Mitigación en el contrato',
    'swc.r101': 'Overflow: Solidity 0.8.24; unchecked solo en nonce++ / fee delta / unstake',
    'swc.r103': 'Floating pragma: pragma solidity 0.8.24 fijo',
    'swc.r104': 'Unchecked return: refund chequea success → EthRefundFailed',
    'swc.r107': 'Reentrancy: nonReentrant en send/receivePacket/adapters',
    'swc.r115': 'Auth: msg.sender (deliverer / endpoint / router / messenger)',
    'swc.r121': 'Replay: processedMessages[messageHash] + tests Replay',
    'swc.r123': 'Requirements: custom errors + Unauthorized / Replay / app',
    'swc.info': 'INFORMATIVO',
    'swc.i1t': 'Deliverer / transporte',
    'swc.i1d':
      'v1 confía en deliverer y endpoint/router. Peers mitigan spoofing del srcAddress. Owner rota deliverer con Ownable2Step.',
    'swc.i2t': 'Receiver app OOG',
    'swc.i2d':
      'Un IMessageReceiver malicioso puede gastar gas del deliverer; si revierte, el hash no queda marcado (retry posible).',

    'pr.eyebrow': '// 05 — PROCESO',
    'pr.title': 'Fases 0–7 cerradas',
    'pr.lead':
      'TDD por gates: Foundry setup, libs (Codec/Peer/Fee), messenger + MockRelayer, LZ V2, CCIP, RemoteStake + Unauthorized/Replay, dual-fork + SimulateRelay, gas + Deploy + SWC.',
    'ph.01': 'Setup Foundry + libs (Codec · Peer · Fee)',
    'ph.23': 'Messenger + LZ V2 + CCIP adapters',
    'ph.45': 'RemoteStake + Unauthorized + Replay',
    'ph.6': 'Dual-fork · SimulateRelay',
    'ph.7': 'Gas Yul · Deploy · SWC-AUDIT',
    'st.1': 'Fases',
    'st.2': 'Tests PASS',
    'st.3': 'SWC vulnerables',
    'st.4': 'SKIP fork',
    'term.label': 'rolando@strahm:~/16-crosschain-messaging',
    'term.1': 'forge test',
    'term.2': '[PASS] suite · 81 passed · 2 skipped (dual-fork)',
    'term.3': 'cat doc/SWC-AUDIT.md | head',
    'term.4': 'Vulnerable: 0 · Informativos: 6 · Mitigados/N/A: 30',
    'term.5': 'echo status',
    'term.6': 'MODULE_16_CLOSED · GAS_SWC_CLOSED',

    'at.eyebrow': '// 06 — CAMPAÑAS DEFENSIVAS',
    'at.title': 'Defensivo, no ofensivo',
    'at.lead':
      'UnauthorizedSender, ReplayProtection, adapters spoof y RejectETH: el “éxito” del misuse es que revierte. Sin PoCs de exploit.',
    'cA.t': 'Unauthorized',
    'cA.d': 'srcAddress ≠ peer o caller ≠ deliverer → InvalidSourceSender / UnauthorizedCaller.',
    'cB.t': 'Replay',
    'cB.d': 'Mismo messageHash dos veces → MessageAlreadyProcessed.',
    'cC.t': 'Fee / refund',
    'cC.d': 'msg.value < fee → InsufficientFee; RejectETH → EthRefundFailed.',
    'cD.t': 'Adapter spoof',
    'cD.d': 'lzReceive/ccipReceive sin endpoint/router o peer LZ/CCIP inválido.',
    'cE.t': 'Fuzz libs',
    'cE.d': 'PacketCodec / PeerLib / FeeRefund ≥ 1000 runs c/u.',

    're.eyebrow': '// 07 — CÓDIGO ABIERTO',
    're.title': 'Repositorios',
    're.lead':
      'Mismo código en GitHub y GitLab: contratos, tests, GAS.md, SWC-AUDIT.md, diagramas, Deploy y SimulateRelay.',
    're.cta': 'Contactar',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — Cross-Chain Messaging · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · LZ V2 · CCIP · ALL_SYSTEMS_OPERATIONAL',
  },

  en: {
    'html.lang': 'en',
    'meta.title': 'Cross-Chain Messaging — Rolando Strahm',
    'meta.description':
      'Multi-chain AMP protocol: LayerZero V2 + CCIP, ABI vs Yul gas, and SWC audit. Foundry · Solidity 0.8.24.',

    'nav.overview': 'Project',
    'nav.pillars': 'Pillars',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Process',
    'nav.attacks': 'Attacks',
    'nav.repos': 'Repos',
    'nav.close': '← Close',

    'hero.tag': '// MODULE 16 · WEB3 PORTFOLIO',
    'hero.title': 'CROSS-CHAIN<br>MESSAGING',
    'hero.role': 'Solidity 0.8.24 · Foundry · LayerZero V2 · CCIP · Gas · SWC',
    'hero.sub':
      'Multi-chain arbitrary message passing: trusted peers, anti-replay, quote+Yul refund, LayerZero V2 and Chainlink CCIP adapters, plus remote stake demo. Documented gas + SWC-100–136 matrix.',
    'hero.cta1': 'View on GitHub',
    'hero.cta2': 'View on GitLab',

    'ov.eyebrow': '// 01 — CONTEXT',
    'ov.title': 'Why this project',
    'ov.lead':
      'After the token bridge, I built the <strong>AMP</strong> layer: <strong>CrossChainMessenger</strong>, <strong>LayerZero V2</strong> and <strong>CCIP</strong> adapters, and <strong>RemoteStakeReceiver</strong>. Focus: <strong>anti-spoofing</strong> (<code>InvalidSourceSender</code>), <strong>anti-replay</strong> (<code>processedMessages</code>), <strong>Yul fee refunds</strong>, and <strong>SWC</strong> with tests proving misuse reverts.',

    'pi.eyebrow': '// 02 — THREE PILLARS',
    'pi.title': 'What the module ships',
    'p1.num': '// PILLAR_01',
    'p1.title': 'AMP messaging',
    'p1.desc':
      'Quote → send → relay → receive: peers, deliverer, PacketCodec, and optional app hook.',
    'p1.l1': 'InvalidSourceSender + UnauthorizedCaller',
    'p1.l2': 'processedMessages → MessageAlreadyProcessed',
    'p1.l3': 'CEI + ReentrancyGuard + Ownable2Step',
    'p2.num': '// PILLAR_02',
    'p2.title': 'Gas optimization',
    'p2.desc':
      'Packed Yul wire in adapters, messageHashCalldata, immutable _selfPeer, and refundExcessAssembly.',
    'p2.l1': 'decodeYul −1,040 gas vs ABI',
    'p2.l2': 'Yul refund −64 gas vs .call',
    'p2.l3': '.gas-snapshot + optimizer 10k + via_ir',
    'p3.num': '// PILLAR_03',
    'p3.title': 'SWC verification',
    'p3.desc':
      'SWC-100–136 matrix, UnauthorizedSender, ReplayProtection, fuzz ≥ 1000, optional dual-fork.',
    'p3.l1': '0 exploitable vulnerabilities',
    'p3.l2': '30 mitigated / N/A · 6 info',
    'p3.l3': '81 Foundry tests PASS · 2 SKIP fork',

    'gas.eyebrow': '// 03 — GAS OPTIMIZATION',
    'gas.title': 'Cheap hot path, clear tradeoffs',
    'gas.lead':
      'Phase 7: baseline in <code>doc/GAS.md</code> and <code>.gas-snapshot</code>. Paths: <strong>decodeYul 30,829</strong> vs <strong>ABI 31,869</strong>, <strong>Yul refund 24,019</strong> vs <strong>.call 24,083</strong>, send exact fee ~294,919. Every technique has an explicit tradeoff.',
    'gas.th1': 'Optimization',
    'gas.th2': 'Tradeoff / effect',
    'gas.r1a': 'encodePacked / decodeYul (adapters)',
    'gas.r1b': 'Wire 120 B + payload; −1,040 gas vs abi.decode',
    'gas.r2a': 'messageHashCalldata',
    'gas.r2b': 'No Packet memory copy in receivePacket',
    'gas.r3a': '_selfPeer immutable',
    'gas.r3b': 'Avoids addressToBytes32(this) each tx',
    'gas.r4a': 'FeeRefundLib.refundExcessAssembly',
    'gas.r4b': 'Yul call without returndata; −64 gas vs .call',
    'gas.r5a': 'encodePacked in Yul (mcopy)',
    'gas.r5b': 'No multi-alloc bytes.concat',
    'gas.r6a': 'Custom errors (MessagingErrors)',
    'gas.r6b': 'Compact reverts vs require strings',
    'gas.r7a': 'optimizer_runs = 10_000 + via_ir',
    'gas.r7b': 'Aggressive inlining on Foundry hot path',

    'swc.eyebrow': '// 04 — SWC VERIFICATION',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      '<strong>SWC-100 → SWC-136</strong> matrix over messenger, LZ/CCIP adapters, PacketCodec, and FeeRefundLib. Report: <code>doc/SWC-AUDIT.md</code>. Conclusion: <strong>0 exploitable vulnerabilities</strong> in v1 scope.',
    'swc.s1': 'Mitigated / N/A',
    'swc.s2': 'Informational (design)',
    'swc.s3': 'Vulnerable',
    'swc.th1': 'Key SWC',
    'swc.th2': 'Mitigation in the contract',
    'swc.r101': 'Overflow: Solidity 0.8.24; unchecked only on nonce++ / fee delta / unstake',
    'swc.r103': 'Floating pragma: fixed pragma solidity 0.8.24',
    'swc.r104': 'Unchecked return: refund checks success → EthRefundFailed',
    'swc.r107': 'Reentrancy: nonReentrant on send/receivePacket/adapters',
    'swc.r115': 'Auth: msg.sender (deliverer / endpoint / router / messenger)',
    'swc.r121': 'Replay: processedMessages[messageHash] + Replay tests',
    'swc.r123': 'Requirements: custom errors + Unauthorized / Replay / app',
    'swc.info': 'INFORMATIONAL',
    'swc.i1t': 'Deliverer / transport',
    'swc.i1d':
      'v1 trusts deliverer and endpoint/router. Peers mitigate srcAddress spoofing. Owner rotates deliverer via Ownable2Step.',
    'swc.i2t': 'Receiver app OOG',
    'swc.i2d':
      'A malicious IMessageReceiver can spend deliverer gas; if it reverts, the hash is not marked (retry possible).',

    'pr.eyebrow': '// 05 — PROCESS',
    'pr.title': 'Phases 0–7 closed',
    'pr.lead':
      'TDD by gates: Foundry setup, libs (Codec/Peer/Fee), messenger + MockRelayer, LZ V2, CCIP, RemoteStake + Unauthorized/Replay, dual-fork + SimulateRelay, gas + Deploy + SWC.',
    'ph.01': 'Foundry setup + libs (Codec · Peer · Fee)',
    'ph.23': 'Messenger + LZ V2 + CCIP adapters',
    'ph.45': 'RemoteStake + Unauthorized + Replay',
    'ph.6': 'Dual-fork · SimulateRelay',
    'ph.7': 'Gas Yul · Deploy · SWC-AUDIT',
    'st.1': 'Phases',
    'st.2': 'Tests PASS',
    'st.3': 'SWC vulnerable',
    'st.4': 'SKIP fork',
    'term.label': 'rolando@strahm:~/16-crosschain-messaging',
    'term.1': 'forge test',
    'term.2': '[PASS] suite · 81 passed · 2 skipped (dual-fork)',
    'term.3': 'cat doc/SWC-AUDIT.md | head',
    'term.4': 'Vulnerable: 0 · Informational: 6 · Mitigated/N/A: 30',
    'term.5': 'echo status',
    'term.6': 'MODULE_16_CLOSED · GAS_SWC_CLOSED',

    'at.eyebrow': '// 06 — DEFENSIVE CAMPAIGNS',
    'at.title': 'Defensive, not offensive',
    'at.lead':
      'UnauthorizedSender, ReplayProtection, adapter spoof, and RejectETH: misuse “success” means revert. No exploit PoCs.',
    'cA.t': 'Unauthorized',
    'cA.d': 'srcAddress ≠ peer or caller ≠ deliverer → InvalidSourceSender / UnauthorizedCaller.',
    'cB.t': 'Replay',
    'cB.d': 'Same messageHash twice → MessageAlreadyProcessed.',
    'cC.t': 'Fee / refund',
    'cC.d': 'msg.value < fee → InsufficientFee; RejectETH → EthRefundFailed.',
    'cD.t': 'Adapter spoof',
    'cD.d': 'lzReceive/ccipReceive without endpoint/router or invalid LZ/CCIP peer.',
    'cE.t': 'Lib fuzz',
    'cE.d': 'PacketCodec / PeerLib / FeeRefund ≥ 1000 runs each.',

    're.eyebrow': '// 07 — OPEN SOURCE',
    're.title': 'Repositories',
    're.lead':
      'Same code on GitHub and GitLab: contracts, tests, GAS.md, SWC-AUDIT.md, diagrams, Deploy, and SimulateRelay.',
    're.cta': 'Contact',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — Cross-Chain Messaging · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · LZ V2 · CCIP · ALL_SYSTEMS_OPERATIONAL',
  },
};

(function () {
  const STORAGE_KEY = 'portfolio-lang';
  const params = new URLSearchParams(window.location.search);
  let lang = params.get('lang') || localStorage.getItem(STORAGE_KEY) || 'es';
  if (!I18N[lang]) lang = 'es';

  function apply(langCode) {
    const dict = I18N[langCode] || I18N.es;
    document.documentElement.lang = dict['html.lang'] || langCode;

    const title = document.querySelector('title');
    if (title && dict['meta.title']) title.textContent = dict['meta.title'];

    const metaDesc = document.querySelector('meta[name="description"]');
    if (metaDesc && dict['meta.description']) metaDesc.setAttribute('content', dict['meta.description']);

    document.querySelectorAll('[data-i18n]').forEach((el) => {
      const key = el.getAttribute('data-i18n');
      const val = dict[key];
      if (val == null) return;
      if (el.hasAttribute('data-i18n-html')) el.innerHTML = val;
      else el.textContent = val;
    });

    document.querySelectorAll('.lang-btn').forEach((btn) => {
      btn.classList.toggle('active', btn.getAttribute('data-lang') === langCode);
    });

    localStorage.setItem(STORAGE_KEY, langCode);
  }

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.addEventListener('click', () => apply(btn.getAttribute('data-lang')));
  });

  apply(lang);
})();
