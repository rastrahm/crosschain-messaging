# Documentación — Módulo 16: Cross-Chain Messaging & Interoperability

Índice de diseño del módulo (AMP LayerZero v2 / Chainlink CCIP, sincronización multi-cadena, ejecución remota).

| Archivo | Contenido | Estado |
|---------|-----------|--------|
| [planificacion.md](./planificacion.md) | Fases 0–7, arquitectura v1, criterios de aceptación | Fases 0–3 ✅ |
| [diagrama-de-clases.md](./diagrama-de-clases.md) | UML: messenger, adapters LZ/CCIP, codec, peers | 📝 Diseño |
| [diagrama-de-flujo.md](./diagrama-de-flujo.md) | Decisiones: quote → send → verify → execute | 📝 Diseño |
| [flujograma.md](./flujograma.md) | E2E origen → relayer → destino + anti-replay | 📝 Diseño |

**Estado del módulo:** Fases **0–3** ✅ · siguiente: Fase **4**.  
**Regla:** no se escribe código de una fase hasta *“autorizo Fase N”*.

README del módulo: [`../README.md`](../README.md).

**Suite actual:** `forge test` → **47 PASS**.
