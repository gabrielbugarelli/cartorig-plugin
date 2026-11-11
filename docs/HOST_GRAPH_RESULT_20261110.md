# Marco A — diagnóstico de execução no Fusion

**Ambiente informado pelo relatório:** DaVinci Resolve 20.3.1.6, em 2026-11-10T23:02:50Z.

**Resultado do teste 0.2:** `Create` resultou em `BLOCKED/FAILED`. Motivo reportado: `BLOCKED: use NEW disposable Fusion Composition without editorial nodes`.

**Causa confirmada no código:** `src/CartoRig/native_probe.lua` recusava a composição ao encontrar qualquer node com `TOOLS_RegID` diferente de `MediaOut`, independentemente do risco de modificá-lo. O bloqueio ocorreu no `preflight`, **antes** de `AddTool`. Portanto, o relatório não indica uma falha na criação de nodes pelo host e não demonstra qualquer alteração do projeto.

**Correção implementada (preview 0.3):** composição com nodes existentes permitida. Verificação explícita apenas de API necessária, colisões com os nomes reservados `CRTEST_*`, identidade de teste já registrada e confirmação de projeto descartável. Operações de conexão, rename e exclusão limitadas às ferramentas recém-criadas. As demais ferramentas são preservadas por design e cobertas por testes unitários de isolamento; a comprovação de funcionamento no Resolve depende de novo teste manual.

**Correção de UX e instalação:** menu único `Workspace → Scripts → Comp → CartoRig`, com atualização no mesmo local e migração automática, pelos desinstaladores originais, das duas instalações de diagnóstico. Menu e janela não usam a terminologia técnica de implementação.

**Estado formal:** A01–A20/B01–B20 continuam 40 NOT RUN; nenhum teste de renderização/cartografia ou persistência do plugin foi aprovado. O teste 0.3 exige execução humana em composição descartável, captura de Viewer e relatório de Save/Reopen.
