# CartoRig V1.0 — matriz de rastreabilidade

**Estado de partida:** nenhum teste de host executado. `NOT RUN` não é aprovado.

Fonte normativa: `docs/CartoRig_Especificacao_de_Produto_e_Implementacao_V1.md` (SHA-256 `af25a7816b0d4cb616f81d30f1c2c77b4c663f783c9f8dc41d96e0b2936427c9`).

Critério `DONE`: node real, UI na superfície contratada, render e persistência, segurança de dependências, teste no host real e evidência aprovada pelo GitHub Actions **do mesmo commit/build**.

| Teste | Marco | Ação normativa | Resultado normativo | Implementação | Teste executável | Evidência Actions | Commit / PR | Status |
|---|---|---|---|---|---|---|---|---|
| A01 | A | Abrir composição Fusion sem CartoRig; Scene → `Create Scene` | Nodes reais `CR_Scene_Main`, `CR_WorldMap_Main`, `CR_Camera_Main` aparecem, conectados funcionalmente; Viewer/MediaOut exibem mapa neutro; nenhum keyframe ou destaque editorial automático | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A02 | A | Scene → pesquisar e adicionar `Brazil`, `Argentina`, `Mato Grosso` | Três nodes geográficos independentes, visíveis no grafo; país/estado corretos; IDs únicos e render coerente | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A03 | A | Em Scene, marcar linha do Brasil somente como alvo de `Rename` | O Inspector não muda, o node não é selecionado para edição no Fusion; a linha serve apenas para CRUD | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A04 | A | Fechar Scene; clicar diretamente em `CR_Country_Brazil_001` no Node Editor | Inspector exibe Control e Motion do Brasil; mudar Fill altera só esse node, sem abrir Scene | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A05 | A | Com Country Brasil visível, selecionar State Mato Grosso e mudar Fill/Stroke | Estado mantém bordas corretas e cor independente; Brasil, WorldMap e Argentina não são recoloridos | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A06 | B | Scene → `Add Route`, escolher nodes Brasil e Argentina, configurar duas âncoras e criar | Um node Route próprio é criado; as referências são pelos UUIDs dos países; países não são duplicados; endpoints válidos | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A07 | C | Selecionar Route no Node Editor; em Control mudar Stroke, Arrowhead, Curvature, Shadow e Glow | Só a Route muda; Viewer e render refletem cada ajuste; propriedades persistem depois do reopen | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A08 | D | Em Motion da Route, aplicar `Draw Path`; editar Reveal em Control e Bézier em Spline | Animação usa canais reais e produz avanço correto da linha; busca aleatória de frames equivale à reprodução normal | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A09 | D | Selecionar Camera no Node Editor; Motion → `Fly To` Brasil → Argentina | Câmera anima o enquadramento; Countries, State, Marker, Label e Route permanecem geoancorados sem drift | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A10 | D | Aplicar em Regions `Fade In`, `Highlight` e `Reveal`, em instâncias separadas | Cada efeito corresponde ao contrato de canais; parâmetros permanecem editáveis; Fill base não é destruído | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A11 | C,D | Criar Marker por ponto e Label com texto `São Paulo`; aplicar Pop In e Fade In | Nodes distintos, texto Unicode, geoanchors corretos e animações editáveis durante zoom/pan | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A12 | D | Aplicar e atualizar Motion; editar keyframes manualmente | Não há proliferação de keyframes/nodes; estado `Customized` é identificado e alterações protegidas | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A13 | B | Duplicar Country e Route; renomear país referenciado | UUIDs/canais independentes; Route preserva links corretos; renomeação não quebra a relação | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A14 | B | Excluir país usado por Route; escolher `Keep Route and Freeze Anchor`; repetir com `Cancel` | Na primeira operação, país é removido e Route permanece com coordenada; em Cancel, tudo permanece intacto | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A15 | A-D | Salvar, fechar Resolve, reabrir e renderizar com Scene fechado | Nodes, propriedades, fontes, câmera, rotas, fontes tipográficas, links e curvas mantêm estado e render esperado | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A16 | A | Com internet bloqueada, buscar `Brasil`, `São Paulo`, `Sao Paulo`, `Rio de Janeiro`, `Georgia` | Busca por aliases e desambiguação conforme dados instalados; nenhuma dependência de internet/conta/terminal | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A17 | C | Sobrepor WorldMap com fundo transparente, Regions e Route sobre MediaIn em HD/QHD/4K | Alpha, composição de cor, efeitos e geometria correspondem no Viewer e Deliver; não há opacidade de fundo inesperada | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A18 | B | Misturar nodes CartoRig e nodes livres; executar CRUD, reorder e delete seguros | Nodes externos preservados; operações não reconectam/deletam recursos de terceiros sem autorização | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A19 | A | Trocar composição ativa, reabrir Scene e criar objeto na segunda composição | Cada comando atua somente na cena correta; não cria nodes órfãos nem edita composição anterior | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| A20 | D | Executar instalação limpa no Windows com Studio 20, abrir Scene e criar/renderizar mapa | Produto instalável e utilizável por GUI, sem Python manual, SDK, CMake, terminal ou rede | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B01 | A | Criar duas instâncias de `Country Brazil` na mesma cena | Dois nodes com UUIDs, nomeações, estilos e animações independentes | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B02 | A | Fechar Scene, alternar seleção direta entre Country, Route e Camera no Node Editor | Inspector contextual muda para o tipo correto; nenhum parâmetro de outro node fica acessível por engano | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B03 | A | Em Scene, selecionar linha para `Duplicate`, `Delete` ou `Reorder` sem executar a ação | Não dispara seleção no Node Editor, nem abre Control/Motion; apenas identifica alvo CRUD | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B04 | C | Aplicar override em State e Country; mudar Land no WorldMap; executar Reset Property | Overrides são preservados; Reset atinge somente a propriedade do objeto designado | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B05 | B | Alterar ordem de desenho de dois nodes de região/rota em Scene | Render muda a ordem efetiva; geometrias, UUIDs, anchors e animações não mudam | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B06 | A | Tentar excluir WorldMap e Camera individualmente | Interface bloqueia, explica dependência estrutural e mantém cena íntegra | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B07 | B | Iniciar Route com Country como endpoint e omitir seleção de âncora | `Create Route` fica indisponível; nenhuma capital/centroide é escolhida silenciosamente | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B08 | B | Criar Route vinculada a Marker; mover a latitude/longitude do Marker em Control | Endpoint vinculado acompanha a coordenada efetiva do Marker; Route mantém identidade e outros objetos não mudam | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B09 | B | Duplicar Route, editar espessura e curva da cópia; excluir a original | Cópia mantém geometria e referências, mas preserva estilo/keyframes próprios | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B10 | B | Excluir objeto referenciado, escolher `Cancel` | Não altera node, âncora, links, keyframes, ordem nem arquivos | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B11 | B | Excluir objeto referenciado por Route/Label ou alvo de Camera Fly To; escolher congelamento permitido | Consumidores e canais são mantidos, referências removidas, última coordenada/pose preservada e estado de vínculo diagnosticável | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B12 | D | Reaplicar o mesmo preset no mesmo canal e executar `Update` | Identificador da aplicação é reutilizado, sem multiplicar keyframes, ferramentas ou modificadores | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B13 | D | Aplicar preset em canal previamente animado manualmente; escolher `Cancel` | Animação original permanece byte/semanticamente íntegra; alteração cancelada não cria resíduos | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B14 | D | Modificar keyframes de preset, remover com `Keep Animation` | Keyframes permanecem editáveis no Fusion e deixam de estar gerenciados pelo preset | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B15 | D | Modificar keyframes de preset, remover com `Remove Animation` | Somente os canais pertencentes à aplicação são removidos; estilo estático e demais presets são preservados | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B16 | B,D | Criar Route e Fly To que cruzam ±180° longitude | Sem segmentos transglobais errados, saltos artificiais, deslocamento de âncoras ou duplicação de feições | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B17 | C | Criar Labels `São Paulo`, `Amapá`, `Brasília` com fonte instalada e simular ausência posterior | Unicode renderiza corretamente; fallback tipográfico explícito mantém texto legível | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B18 | A | Remover/alterar versão de dataset usado por projeto salvo | Diagnóstico de fonte/versão incompatível; sem polígono inventado, troca silenciosa ou rede obrigatória | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B19 | A,B | Interromper criação/exclusão por falha de integração e reabrir projeto | Operação é revertida ou recuperável; não deixa nodes/cartografia parcialmente inválidos nem afeta recursos livres | PENDING | PENDING | PENDING | PENDING | NOT RUN |
| B20 | B | Duplicar composição completa com Route e animações, editar a cópia | Todos os IDs internos são distintos; ligações da cópia apontam somente para sua cena e original não muda | PENDING | PENDING | PENDING | PENDING | NOT RUN |

## Regras de atualização

- Nenhum `PASS` sem resultado observado, evidência, build SHA-256, commit, dataset e versão de Resolve atribuídos ao teste.
- Preencher os campos por PR e vincular cada caso ao relatório estruturado de execução. Nunca converter `NOT RUN` em `PASS` por cálculo, mock ou aprovação manual externa ao Actions.
- Relatórios de testes do host são vinculados ao mesmo instalador da candidatura; o release gate recusa `FAIL`, `SKIPPED`, `BLOCKED`, `NOT RUN` e IDs ausentes.
- Cobrir também PRD-01 a PRD-10, geografia, os nove tipos autorais, os 12 presets, migração, alpha, 1920×1080/2560×1440/3840×2160, FPS e carga 25/10/20/10 conforme a especificação.
