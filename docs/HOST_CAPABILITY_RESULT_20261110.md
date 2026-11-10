# Marco A — registro do teste de capacidade do host

Data do relatório: 2026-11-10T22:29:38Z UTC. Registro proveniente de execução manual do CartoRig Host Probe 0.1 no ambiente do editor.

- DaVinci Resolve reportado: **20.3.1.6**. O nome "Studio" não é retornado pelo número de versão; a licença/edição não foi validada programaticamente.
- Fusion object: AVAILABLE.
- UI Manager e UIDispatcher: AVAILABLE.
- Fusion composition context: AVAILABLE.
- GetToolList encontrou **7 nodes nativos** na composição ativa.
- Métodos **SetData / GetData**, **AddTool**, **StartUndo / EndUndo**: detectados como funções.
- Hash SHA-256 do relatório recebido: `a0be23708788772f1fa46f45a130d1727ad4c7dad76b4fc9f484f733da547ee0`.

**Limitação importante:** este teste é somente uma descoberta de capacidades. Nenhuma chamada de criação de node, alteração de Inspector, conexão de graph, render, persistência, Undo, exclusão ou reabertura foi executada. A presença dos métodos não implica funcionamento.

**Decisão técnica:** autorizar a etapa de *teste controlado* das APIs de criação real em **composição descartável e com confirmação explícita do editor**. O próximo pacote não constitui implementação de Scene/WorldMap/Camera nem substitui A01–A20/B01–B20. Resultados desses 40 casos permanecem NOT RUN. Sem aprovação de release.
