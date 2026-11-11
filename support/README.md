# Diagnóstico da entrada cartorig-dev 0.6.3 no Resolve

Este kit é **somente de leitura**: não instala scripts, não modifica Fusion Compositions e não acrescenta entradas no menu do DaVinci Resolve.

A partir da 0.6.0, a **única entrada** `cartorig-dev` pertence ao escopo **Utility**, permitindo executar `Create Scene` desde a página Edit, sem Fusion Composition aberta.

## Como executar

1. No mesmo Windows em que usa o Resolve, extraia o ZIP da build aprovada.
2. Dê duplo clique em `verificar-cartorig-dev.cmd` utilizando **a mesma conta de usuário do Resolve**.
3. Envie o relatório `%TEMP%\cartorig-dev-install-check.txt`.

O diagnóstico verifica se `cartorig-dev.lua` existe em **%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility**; compara presença de scripts no antigo diretório Comp, verifica as dependências e apresenta caminhos, tamanhos e hashes SHA-256. Também registra resíduos de migração e se há processos Resolve sob outras contas, sem ler conteúdo dos projetos.

**Importante:** presença do arquivo no Windows não prova que o Resolve exibiu a entrada no menu. A verificação de interface real e os 40 testes de aceite exigem execução no host. Nenhum teste do produto está automaticamente aprovado pelo diagnóstico.
