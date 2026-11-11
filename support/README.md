# Diagnóstico da entrada ausente no menu do DaVinci Resolve

A versão 0.5.1 ainda não foi confirmada em um host Resolve real. A presença do arquivo em GitHub Actions **não comprova** que o menu do editor o exibirá.

Este kit **não instala nada**, **não cria outra entrada no menu Scripts**, **não acessa o conteúdo de projetos** e não requer Resolve aberto.

1. Baixe o artefato ZIP de uma execução verde do workflow **CartoRig install visibility diagnostic**.
2. Extraia os arquivos e dê duplo clique em **verificar-cartorig-dev.cmd**, na mesma conta Windows utilizada para executar o Resolve. Não execute como outro usuário ou Administrador.
3. O relatório será salvo em **%TEMP%\cartorig-dev-install-check.txt**.
4. Envie o TXT para identificar se o launcher está ausente, em outro diretório de scripts, sem runtime UI ou presente no disco mas não enumerado pelo Resolve.

O relatório inclui presença, tamanho e SHA-256 dos arquivos do CartoRig nas pastas usuais, informações genéricas sobre a conta do processo Resolve e existência da chave de desinstalação. Os caminhos do perfil são substituídos por %USERPROFILE% para evitar divulgar o nome do usuário.

Limite: o kit não abre o Resolve nem verifica seu menu. Se os arquivos estiverem presentes e a entrada continuar ausente, o diagnóstico correto é **FILES_PRESENT_MENU_VISIBILITY_NOT_VERIFIED**. Esse resultado exige uma investigação no host real, não outra declaração de sucesso na CI.

A01–A20 e B01–B20 continuam NOT RUN.
