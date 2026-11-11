# Auditoria da regressão: `cartorig-dev` ausente do menu do Resolve

Data: 2026-11-11. Branch base: `fix/cartorig-dev-launcher-upgrade` (versão 0.5.1).

## Fatos comprovados no código

1. O instalador 0.5 usava desinstalação antecipada que apagava `Comp/cartorig-dev.lua`; isso era um defeito real de migração, alterado na 0.5.1.
2. A 0.5.1 instala o launcher em `%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Comp\cartorig-dev.lua`. Este caminho é um dos diretórios documentados para scripts por usuário no Windows; não há evidência de que seja errado de forma geral.
3. Testes GitHub Actions da 0.5.1 confirmam o arquivo naquele caminho **somente no usuário do runner Windows**. O pipeline não tem DaVinci Resolve Studio 20 licenciado, não abre o menu e não verifica enumeração. O `PASS` de instalação é insuficiente para garantir visibilidade no host do editor.
4. O `host/cartorig-dev-launcher.lua` grava `last-error.txt` somente quando `pcall(dofile,ui)` produz uma exceção. Diversas falhas de pré-condição no arquivo `host/cartorig-dev-scene.lua` usam `print(...); return`, que fazem `pcall` retornar sucesso. **Erro confirmado de diagnóstico:** ausência de `last-error.txt` não comprova abertura bem-sucedida da janela.
5. A 0.5.1 pode interromper a instalação se encontrar restos de scripts de diagnóstico antigos que não puderam ser removidos pelos respectivos desinstaladores, ou um `.backup` pendente. O CI anterior não reproduzia todos os estados órfãos possíveis da máquina do editor.
6. `Comp` é um escopo de script da página Fusion. A presença do nome no menu também depende da página/contexto em que o Resolve o exibe. Isso é diferente de um script ausente no disco.

## O que **não** foi determinado

O relato do editor informa que `cartorig-dev` continua ausente. Ainda não há evidência do Windows do editor sobre a presença do arquivo no caminho padrão, perfil da conta que executa Resolve, bloqueios antigos ou menu efetivo. **A causa exata não está provada.** Não classificar a 0.5.1 como correção confirmada.

## Evidência adicional produzida

- `support/cartorig-dev-diagnose.ps1` e `support/verificar-cartorig-dev.cmd`: inspeção somente leitura, fora do menu Scripts, sem instalação e sem alterações em projetos ou preferências.
- Workflow `.github/workflows/install-visibility-diagnostic.yml`: teste em runner Windows padrão, com estados de arquivo ausente, runtime UI ausente, arquivo presente, arquivo em outro caminho padrão, restos do instalador antigo e arquivos `.pending`.
- Mesmo com todos os testes desse diagnóstico aprovados no Actions, `MENU_ENUMERATION` permanece `NOT_RUN`; não há substituição do host real por simulação.
- A próxima decisão sobre instalador **depende do resultado de diagnóstico na mesma conta Windows em que o Resolve é executado**. Se o launcher estiver presente mas não for enumerado, investigar caminho de scripts real, perfil e logs do Resolve no host; não adicionar indiscriminadamente cópias em Utility/Comp/ProgramData.

## Política de entrega

Nenhuma nova build de produto 0.5.x foi gerada neste PR de auditoria. O kit de diagnóstico é separado do instalador e não cria uma nova entrada no menu. O PR permanece em rascunho; os 40 testes A/B seguem `NOT RUN` e nenhuma release V1 pode ser publicada.
