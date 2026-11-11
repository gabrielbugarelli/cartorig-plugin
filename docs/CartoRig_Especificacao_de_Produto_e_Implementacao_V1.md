# CartoRig — Especificação de Produto e Implementação

**Versão do produto:** 1.0  
**Plataforma de autoria:** Fusion, no DaVinci Resolve Studio 20  
**Plataforma-alvo de distribuição:** Windows  
**Idioma do produto:** inglês  
**Idioma deste documento:** português  
**Tipo de produto:** extensão/plugin gratuito e de código aberto para criação e animação cartográfica 2D  
**Abrangência:** requisitos de produto, interfaces, nodes, geografia, animação, integração, persistência, qualidade, empacotamento e testes de aceitação

## 1. Produto

### 1.1. Finalidade

O CartoRig é uma ferramenta de composição cartográfica no Fusion. Permite criar uma cena com mapa-base mundial, acrescentar continentes, países, estados, rotas, marcadores e rótulos como **nodes reais e individuais**, editar suas propriedades no Inspector e aplicar animações prontas que continuam ajustáveis com os recursos de animação do Fusion. O uso normal não exige programação, terminal, preparação de dados GIS nem montagem manual de pipelines geográficos.

O resultado é uma composição nativa, conectável ao `MediaOut`, com transparência, persistência no projeto e renderização pelo DaVinci Resolve. As capacidades instaladas funcionam integralmente offline.

### 1.2. Regras fundamentais

| Código | Regra obrigatória |
|---|---|
| `PRD-01` | A criação e a gestão estrutural de objetos CartoRig acontecem exclusivamente pela janela **Scene**, implementada com UI Manager. |
| `PRD-02` | Cada objeto autoral existe como **um node real, visível, nomeado, selecionável e independente** no Node Editor do Fusion. |
| `PRD-03` | O usuário seleciona o node **diretamente no Node Editor** para exibir suas áreas **Control** e **Motion** no Inspector. Não precisa abrir Scene para editar. |
| `PRD-04` | **Control** contém as propriedades granulares do node; **Motion** aplica, atualiza e remove animações predefinidas; **Spline/Keyframes** do Fusion permitem refinamento temporal. |
| `PRD-05` | Cada `Create Scene` insere automaticamente uma Fusion Composition independente na timeline e cria/conecta seus nodes ao MediaOut, sem preparação nem conexões manuais. |
| `PRD-06` | A câmera cartográfica é única por cena e transforma todos os objetos geoancorados de forma coerente em qualquer frame. |
| `PRD-07` | Uma alteração em um node não modifica outro node indevidamente; estilos, identidade, parâmetros e animações são independentes. |
| `PRD-08` | Nenhum objeto autoral ganha rota, rótulo, marcador, destaque ou animação editorial sem comando explícito. |
| `PRD-09` | Geometrias, nomes e âncoras provêm dos dados locais instalados ou de coordenadas explícitas; o sistema não inventa informações geográficas ausentes. |
| `PRD-10` | A composição continua editável, salvável e renderizável com a janela Scene fechada e sem internet. |

### 1.3. Fluxos elementares

**Destacar Brasil.** O usuário abre Scene, cria a cena e escolhe `Add Country → Brazil`. Scene cria `CR_Country_Brazil_001` e integra o node à composição. O usuário fecha Scene, clica no node no Node Editor e, em **Control**, modifica `Fill Color`. A cor do Brasil muda; a cor dos demais países e do mapa-base não muda.

**Criar rota Brasil → Argentina.** O usuário abre Scene, adiciona Brasil e Argentina e escolhe `Add Route`. Seleciona **os dois nodes já existentes** e define uma coordenada de origem e outra de destino. Scene cria um terceiro node, `CR_Route_Brazil_Argentina_001`, sem recriar países. O usuário fecha Scene, seleciona a Route diretamente no Node Editor, altera sua cor em Control e aplica `Draw Path` em Motion. Pode editar os canais resultantes em Control e a curva de velocidade no Spline nativo.

**Animar câmera.** O usuário seleciona `CR_Camera_Main` diretamente no Node Editor, escolhe `Fly To` em Motion, configura os enquadramentos e refina a animação. Os países, rotas, marcadores e rótulos permanecem vinculados às respectivas posições geográficas durante o movimento.

### 1.4. Limites do produto

A V1 é um compositor cartográfico 2D, não um sistema GIS cadastral, calculador de rotas por rodovias, geocodificador de endereços, cliente obrigatório de mapas online, editor de vídeo paralelo ou clone de outros plugins. A entrada CartoRig está disponível em Workspace → Scripts em todas as páginas do Resolve. A página Edit contém os clipes Fusion Composition criados automaticamente pelo CartoRig; a seleção e a edição de nodes continuam na página Fusion. O CartoRig não recria a timeline, o Spline ou os Keyframes do Fusion.

## 2. Superfícies de interação e divisão de responsabilidades

### 2.1. Scene: interface estrutural

Scene é uma janela UI Manager destinada a criar, pesquisar para adicionar, renomear, duplicar, reordenar, gerenciar dependências e remover **cenas e objetos**. Pode mostrar nomes, tipos, estado estrutural, vínculos e lista de objetos para identificar o alvo de um comando CRUD. **Não é uma interface de seleção para edição**, não aciona o Inspector e não inclui controles de cor, borda, sombra, câmera, efeito ou keyframes.

A seleção de uma linha em Scene serve **somente para identificar o alvo de uma operação estrutural** (`Rename`, `Duplicate`, `Delete`, `Reorder`, referência de Route). Selecionar essa linha não seleciona o node no Fusion. Fechar Scene depois de criar um objeto é o fluxo normal.

### 2.2. Node Editor: seleção nativa

Os nodes CartoRig são selecionados por clique direto no Node Editor do Fusion. A seleção apresenta os controles desse exato node no Inspector nativo. Selecionar outro node substitui o contexto do Inspector, sem possibilidade de editar involuntariamente o objeto anterior. Não existe segunda árvore de seleção dedicada à personalização do CartoRig.

### 2.3. Control: propriedades

Control é uma seção/página contextual do Inspector do node selecionado. Reúne propriedades visuais, geométricas, geográficas e os canais criados por Motion. Propriedades não aplicáveis são omitidas ou desativadas, nunca simuladas. Configurações de câmera ficam no Control do node Camera; edição de origem e destino de uma Route existente fica no Control da Route. Ações que criam ou excluem nodes ficam exclusivamente em Scene.

### 2.4. Motion: animação pronta

Motion é uma segunda seção/página contextual no Inspector do node selecionado. Mostra somente os presets compatíveis, seus parâmetros iniciais e as ações `Apply`, `Update`, `Remove`. Motion **não contém editor de curvas nem timeline própria**. As propriedades efetivas são refináveis em Control; tempos, keyframes e interpolação são refináveis com os recursos nativos do Fusion.

### 2.5. Matriz de responsabilidades

| Operação | Superfície responsável |
|---|---|
| Criar, duplicar, renomear, remover e reordenar objetos | Scene |
| Pesquisar regiões/cidades para adicionar objetos | Scene |
| Criar uma Route a partir de nodes existentes ou localidades | Scene |
| Definir dependências durante a criação de um objeto | Scene |
| Selecionar um node para editar ou animar | Node Editor nativo |
| Alterar cor, borda, sombra, glow, opacidade e visibilidade | Control |
| Alterar endpoints/curvatura de uma Route existente | Control da Route |
| Alterar foco, centro, zoom e orientação da câmera | Control da Camera |
| Aplicar e gerenciar preset animado | Motion |
| Ajustar canal animado, valores e propriedades | Control |
| Refinar keyframes, easing e curvas temporais | Fusion Keyframes/Spline |
| Compor com footage, pré-visualizar e exportar | Fusion Viewer/MediaOut/Deliver |

### 2.6. Apresentação no Inspector

`Control` e `Motion` são duas áreas claramente nomeadas no Inspector do node. A solução deve usar páginas, abas ou agrupamento nativo equivalente que efetivamente exponha as duas áreas e seus controles. A UI não exige instalar outro painel de edição e não redireciona o usuário ao Scene. Nodes estruturais sem presets mostram `No motion presets for this node` em Motion, sem controles inoperantes.

## 3. Catálogo e identidade de nodes

### 3.1. Tipos obrigatórios da V1

| Tipo | Quantidade por cena | Criação | Propósito |
|---|---:|---|---|
| `Scene` | 1 | Automática ao executar `Create Scene` | Estrutura, identificação e composição gerenciada da cena |
| `WorldMap` | 1 | Automática com Scene | Mapa-base neutro: terra, oceano e bordas instaladas |
| `Camera` | 1 | Automática com Scene | Enquadramento e transformação geográfica compartilhada |
| `Continent` | 0..N | `Add Continent` | Região continental composta segundo a classificação dos dados |
| `Country` | 0..N | `Add Country` | País com polígono Admin 0 |
| `State` | 0..N | `Add State/Province` | Estado/província com polígono Admin 1 disponível |
| `Route` | 0..N | `Add Route` | Trajetória entre âncoras geográficas |
| `Marker` | 0..N | `Add Marker` | Símbolo pontual georreferenciado |
| `Label` | 0..N | `Add Label` | Texto editável com âncora geográfica |

`Continent`, `Country` e `State` compartilham a família funcional `Region`, inclusive os três presets Region; isso não reduz sua individualidade como nodes autorais. `City` é uma localização **pontual** de catálogo, utilizável como marcador, label, alvo de câmera ou endpoint, e não um polígono municipal genérico. `Group` e `DataLayer` não pertencem à V1.

### 3.2. Contrato físico

Cada objeto autoral da tabela corresponde a **um node físico do Fusion**. Não é suficiente existir em um array de uma ferramenta única ou em uma lista virtual. Esse node deve apresentar identidade própria, Inspector com Control/Motion pertinente, propriedades independentes, persistência e participação efetiva na composição. É permitido usar nodes auxiliares internos, Fuses, macros, processamento nativo e renderização compartilhada, sem expor um node por vértice ou feição do dataset.

`Scene`, `WorldMap` e `Camera` são nodes estruturais distintos. `WorldMap` e `Camera` não podem ser removidos isoladamente na V1 porque são dependências da cena. Sua configuração é editável; sua remoção ocorre com `Delete Scene`. O node `Scene` não oferece edição de geografia ou efeitos visuais: seu Control exibe identidade e diagnóstico somente-leitura.

### 3.3. Nomenclatura e identificadores

O nome visível padrão é `CR_<Type>_<ReadableName>_<NNN>` para objetos múltiplos. Para os objetos únicos: `CR_Scene_Main`, `CR_WorldMap_Main`, `CR_Camera_Main`. Exemplos: `CR_Continent_SouthAmerica_001`, `CR_Country_Brazil_001`, `CR_State_Brazil_MatoGrosso_001`, `CR_Route_Brazil_Argentina_001`, `CR_Marker_Brasilia_001`, `CR_Label_Brasilia_001`.

- `scene_id` e `object_id` são UUIDs imutáveis; cada node autoral tem seu `object_id` próprio, inclusive os estruturais.
- `node_name` é nome de exibição, **nunca chave de relacionamento**. Renomear o node no Fusion ou pelo comando CRUD não rompe dependências.
- `display_name` preserva Unicode; o slug técnico é ASCII legível, sem pontuação inválida. A numeração começa em `001`, incrementa sem colisão e não renumera objetos já existentes.
- `source_id`/`source_version` identificam a feição do Natural Earth, quando existir; `object_type` identifica o contrato funcional; `schema_version` controla migrações.
- Dois nodes da mesma localidade são permitidos e recebem UUIDs/overrides independentes. Duplicar um node cria outro UUID, mesmo que geometria e estilo sejam iguais.
- Copiar nodes manualmente e produzir UUID repetido exige diagnóstico e correção controlada antes de permitir operações destrutivas.

### 3.4. Topologia de composição

Cada cena é criada em um clipe Fusion Composition próprio, com pipeline válido de `CR_WorldMap_Main`, `CR_Camera_Main` e `CR_Scene_Main` conectado ao MediaOut efetivo da composição. A saída padrão disponível deve ser reutilizada; não se exige conexão manual nem se duplica MediaOut por falha de inspeção. Adicionar objetos cria nodes vinculados funcionalmente ao mesmo sistema de câmera e renderização. O usuário não conecta geometrias, transformações ou `Merge` manualmente.

```text
[CR_WorldMap_Main]  ----------------------\
[CR_Continent_SouthAmerica_001] -----------\
[CR_Country_Brazil_001] -------------------\
[CR_Country_Argentina_001] -----------------+--> [CR_Scene_Main] --> MediaOut
[CR_Route_Brazil_Argentina_001] -----------/
[CR_Marker_Brasilia_001] ------------------/
[CR_Label_Brasilia_001] ------------------/
                        [CR_Camera_Main] --(transformação compartilhada)--> cena
```

O esquema representa relações **funcionais**, não a contagem de portas físicas. A engenharia pode implementar agregação por conexões, cadeia de Merge ou adaptador equivalente, desde que os nove tipos de nodes autorais existam como elementos reais e cada adição produza resultado renderizável. Nodes de terceiros não pertencem ao sistema gerenciado e não podem ser alterados ou excluídos implicitamente.

### 3.5. Ordem visual

A ordem inicial das camadas, do fundo para a frente, é: `WorldMap → Continent → Country → State → Route → Marker → Label`. A câmera não é camada visual. Entre objetos da mesma classe, prevalece a ordem de criação. `Reorder` em Scene muda a prioridade visual de renderização, mas não altera coordenadas, propriedades, IDs ou referências geográficas. O estado visual e a ordem persistem no projeto.

## 4. Scene — contratos de CRUD

### 4.1. Abertura, contexto e ciclo de vida de cenas

A janela UI Manager **Scene** pode ser aberta pela entrada única **CartoRig** em Workspace → Scripts, de qualquer página do Resolve; a versão de desenvolvimento usa o nome **cartorig-dev**. Não se exige uma Fusion Composition previamente criada, a abertura manual da página Fusion nem a preparação de nodes ou da saída.

**Cada Scene corresponde exatamente a uma Fusion Composition independente na timeline.** Todo clique em `Create Scene` cria um novo clipe Fusion Composition, cria os três nodes estruturais reais com UUIDs próprios, conecta automaticamente o MediaOut desse clipe e disponibiliza o resultado na timeline. Os clipes existentes não podem ser sobrescritos, deslocados ou removidos silenciosamente. Quando não existir timeline, o plugin usa a API do Resolve para criar/ativar uma; se a API recusar, informa erro explícito e não declara criação bem-sucedida.

| Comando | Entrada | Resultado obrigatório |
|---|---|---|
| `Create Scene` | Projeto Resolve ativo, com ou sem Fusion Composition anterior | Nova Fusion Composition na timeline, Scene/WorldMap/Camera e saída conectada; nenhum wiring manual |
| `Create Scene` repetido | Uma ou várias cenas existentes | Cada clique cria outra composição independente, IDs próprios e nenhuma alteração nas cenas anteriores; cinco cliques produzem cinco composições distintas |
| Reabrir cena existente | Selecionar seu clipe na timeline e abrir CartoRig | Lista estrutural reconstruída automaticamente dos dados persistidos; sem botão `Open Scene` |
| `Rename Scene` | Novo título | Atualiza o título sem trocar UUID ou composição |
| `Duplicate Scene` | Nova composição de destino | Copia nodes gerenciados para um clipe independente, remapeando UUIDs e referências |
| `Delete Scene` | Cena identificada e confirmação | Remove somente clipe e nodes gerenciados, após validar referências e proteção de material externo |

**Cardinalidade:** uma única Scene por Fusion Composition, múltiplas composições por timeline e projeto. `Create Scene` nunca reutiliza a composição atual como destino de uma nova cena. **O botão `Open Scene` não existe.**

A lista Scene serve apenas a operações estruturais e nunca muda a seleção dos nodes ou o Inspector. O usuário seleciona o node diretamente no Fusion. O salvamento e a renderização independem da janela aberta. Se a inserção ou inicialização falhar, o sistema tenta reverter apenas o clipe e nodes recém-criados, sem apagar materiais anteriores, e relata qualquer recurso não revertido.
### 4.2. Busca geográfica offline

O campo `Search location` utiliza um índice instalado localmente e apresenta resultados tipados. A interface aceita nomes com e sem acento, variações de caixa e aliases reconhecidos (`Brasil/Brazil`, `Sao Paulo/São Paulo`). O filtro `Geographic type` permite `All`, `Continent`, `Country`, `State/Province` e `City`; filtro e pesquisa podem ser combinados.

Cada resultado mostra **nome canônico, tipo, país/estado pai quando aplicável, fonte, geometria disponível** (`Polygon`, `Point`, `Unavailable`) e as ações de criação válidas. Homônimos são distintos, como `Rio de Janeiro — State` e `Rio de Janeiro — City`; `Georgia — Country` não se confunde com subdivisão homônima. A pesquisa não modifica a cena. Nenhum nome pesquisado se converte automaticamente em node.

| Resultado | Ação de criação na V1 | Limites |
|---|---|---|
| Continent com agrupamento geográfico válido | `Add Continent` | União/composto dos países presentes na fonte instalada |
| Country com Admin 0 | `Add Country` | Região poligonal verdadeira |
| State/Province com Admin 1 | `Add State/Province` | Região poligonal somente onde houver cobertura |
| City / ponto de catálogo | `Add Marker`, `Add Label` | Sem inventar um polígono municipal |
| Local sem geometrias suficientes | Nenhuma ação de geometria indisponível | Mensagem com a limitação real e alternativas suportadas |

As localidades do catálogo também podem ser consultadas durante a criação/edição de Route ou configuração de Camera **nas superfícies responsáveis por cada operação**. A busca de Scene, por si só, não altera o foco da câmera e não oferece botões de edição de câmera.

### 4.3. CRUD de objetos

| Comando Scene | Semântica de implementação |
|---|---|
| `Add Object` | Cria um node do tipo escolhido, com UUID novo, propriedades padrão, sem animação aplicada; liga o node ao renderizador e persiste a operação |
| `Rename` | Altera o nome apresentado sem alterar identidade geográfica, UUID ou relações |
| `Duplicate` | Cria node autoral independente, preservando geometria/âncora/estilo e copiando curvas/keyframes para canais próprios, conforme regras por tipo |
| `Delete` | Exclui somente o node escolhido e recursos exclusivamente seus; verifica dependentes antes de remover |
| `Reorder` | Altera draw order e atualiza Viewer, sem modificar ancoragem ou geometria |
| `Object List` | Exibe tipos, nomes e dependências suficientes para identificar o alvo do CRUD; não controla seleção de Inspector |
| `Inspect Dependencies` | Exibe consumidores/vínculos que precisam de tratamento em operações estruturais; não abre edição granular |

As operações confirmam sucesso somente depois de criar/alterar/remover os nodes corretos e atualizar o modelo persistente. Modificações de aparência, visibilidade, bloqueio de propriedades, endpoints da Route existente, propriedades da câmera e animações **não** aparecem como ferramentas de edição no Scene.

### 4.4. Criação de Route a partir de objetos existentes

O fluxo principal de `Add Route` mostra dois campos de referência, `From` e `To`, com **nodes compatíveis que já estão na cena**. Permite escolher Brasil e Argentina e os trata como referências, não como pontos automaticamente determinados. Antes de confirmar `Create Route`, cada ponta deve possuir coordenadas concretas provenientes de uma opção explícita:

- `Representative Point`: ponto interno válido para o território, identificado como ponto representativo, jamais capital implícita;
- `Choose City/Location`: ponto conhecido do catálogo local, apresentado com nome e posição;
- `Enter Coordinates`: latitude e longitude inseridas pelo usuário e validadas.

`From` e `To` também permitem escolher uma localização do catálogo ou coordenadas **sem instanciar país/marker adicional**, embora o uso de nodes existentes seja a primeira opção mostrada. A UI indica claramente quando o endpoint está **vinculado a um node** e quando é apenas uma coordenada/localidade independente. A Route resultante é um node novo, com geometria e estilo próprios.

Se o endpoint escolhido for estado, país ou continente, o usuário deve confirmar a âncora A/B de modo explícito; a interface não escolhe silenciosamente capital ou centroide. Para `Choose City/Location`, uma cidade fora do polígono só será aceita como endpoint independente com indicação clara, não como ponto dentro do território vinculado.

### 4.5. Política de dependências e exclusão

| Situação | Resultado obrigatório |
|---|---|
| Excluir Route | Remove Route, preservando seus endpoints e demais objetos |
| Excluir Country/State/Continent usado por Route | Exibe lista de vínculos; opção padrão `Keep Route and Freeze Anchor` preserva a Route e a última coordenada válida, desvinculando apenas a referência; alternativa `Cancel` não altera nada |
| Excluir Marker utilizado como âncora | Mesmo fluxo: congelar coordenada em consumidores ou cancelar |
| Excluir objeto usado por Label | Preserva o texto e a última âncora geográfica quando autorizado, sinalizando vínculo desvinculado |
| Excluir objeto usado como alvo de Fly To | Exibe dependência; `Freeze Camera Target` conserva pose final e curvas com valores efetivos, desvinculando o alvo; `Cancel` preserva todos os nodes e canais |
| Excluir WorldMap, Camera ou Scene node isoladamente | Bloqueado na V1, com orientação para excluir a cena completa |
| Excluir cena com nodes Fusion externos interligados | Não altera nodes de terceiros; avisa sobre impossibilidade de preservar conexões e cancela até haver ação segura |
| Duplicar Route | Cria uma nova Route e keyframes independentes, mas mantém referências aos mesmos objetos de origem/destino |
| Duplicar Country/State/Marker/Label | Cria UUID e canais próprios, sem duplicar consumidores ou referências externas automaticamente |
| Duplicar cena | Copia todos os objetos CartoRig e remapeia internamente referências; original permanece independente |
| Renomear ou ocultar origem de Route | Preserva vínculo e geometria da Route; ocultação não remove objeto |

A confirmação de exclusão explicita quais objetos serão removidos e quais referências serão congeladas. A remoção não pode criar endpoints inválidos, nodes órfãos, perda silenciosa de animações ou corrupção de conexões do usuário.

### 4.6. Transações estruturais

Toda operação CRUD segue esta ordem lógica:

1. Identificar e validar a composição Fusion ativa e o `scene_id` correspondente.
2. Validar comando, objeto, tipo geográfico, fonte, geometria, IDs e dependências.
3. Registrar um ponto de recuperação transacional e o conjunto de recursos afetados.
4. Executar criação/alteração/remoção de **recursos CartoRig pertencentes à cena**.
5. Atualizar referências, hierarquia, draw order, nós e conexões gerenciadas.
6. Persistir o estado e sincronizar os canais nativos pertinentes.
7. Invalidar os caches afetados e atualizar a composição no Viewer.
8. Confirmar integridade e concluir; em falha, reverter ou apresentar recuperação não destrutiva.

A transação não deve produzir duplicação de nodes quando o usuário repete ou interrompe uma ação. Operações concluídas devem integrar o Undo/Redo nativo na medida em que o host suporte; cada comando estrutural constitui uma unidade lógica de desfazer. Para operações sem suporte nativo, oferecer recuperação segura e documentar a limitação específica, sem prometer Undo inexistente.

### 4.7. Estados e feedback de Scene

| Estado | Comportamento |
|---|---|
| `NO_SCENE` | Apresenta `Create Scene`; operações sobre objetos desabilitadas |
| `SCENE_READY` | Mostra nome da composição, lista CRUD e ações de criação |
| `SEARCHING` | Lista resultados tipados sem mutar composição |
| `NO_RESULTS` | Mostra `Location not found in installed offline data` e opções de filtro |
| `POINT_ONLY` | Permite Marker/Label; explica indisponibilidade de polígono |
| `WRONG_CONTEXT` | Suspende CRUD até confirmar composição ativa |
| `DEPENDENCY_WARNING` | Exibe objetos afetados e opções de congelamento/cancelamento |
| `HOST_ERROR` | Não afirma sucesso; preserva estado anterior ou apresenta procedimento de reparo seguro |
| `DATA_MISSING` | Informa dataset e feição ausentes; não fabrica resultado |

## 5. Control — inventário funcional por node

### 5.1. Regras transversais

Control mostra propriedades do node selecionado **exclusivamente pelo Node Editor**. Cada instância permite overrides independentes. Os parâmetros devem ter unidade, intervalo, valor inicial e comportamento claro no Viewer. `Color Picker` é o meio primário de escolher cor; entrada hexadecimal é alternativa. Alterações podem gerar keyframes quando o canal estiver animado, respeitando o comportamento do Fusion e sem sobrescrever todos os frames silenciosamente.

| Grupo | Controles e regras |
|---|---|
| `Identity` | Tipo, nome, fonte geográfica quando aplicável e UUID como detalhe técnico de leitura |
| `Fill` | Color e Opacity quando o objeto possui superfície preenchível |
| `Stroke` | Color, Width, Opacity e Style quando o objeto possui borda/linha |
| `Composition` | Opacity geral, Visibility e Blend/Composite quando houver suporte efetivo |
| `Shadow` | Enabled, Color, Opacity, Blur, Distance e Angle nos objetos visuais compatíveis |
| `Glow` | Enabled, Color, Intensity, Radius e Mix nos objetos visuais compatíveis |
| `Reset` | `Reset Property` age apenas sobre a propriedade escolhida; `Reset Object Style` restaura apenas o estilo do node alvo |
| `Animation` | Propriedades realmente afetadas por Motion permanecem visíveis/animáveis; canais editados manualmente indicam estado `Customized` |
| `Geo` | Informações/âncoras reais e mensagens sobre disponibilidade de geometria e precisão |

`Visibility` esconde o objeto sem apagar seu estilo nem keyframes. `Opacity` geral não equivale a `Fill Opacity` ou a alpha do WorldMap. Opções sem sentido, como Fill de uma Route, não aparecem. Controle que não tem implementação real não aparece como se fosse funcional.

### 5.2. Contrato Scene (node)

O Control de `CR_Scene_Main` é **somente leitura**: nome/título, `scene_id`, versão do esquema, estado de ligação do WorldMap/Camera, versão dos dados e diagnóstico básico. As operações de renomear, duplicar e excluir cena pertencem à janela Scene; o node Scene não oferece Motion na V1.

### 5.3. Contrato WorldMap

| Grupo | Propriedades obrigatórias | Semântica |
|---|---|---|
| Land | `Land Fill Color`, `Land Opacity` | Aparência das superfícies terrestres do mapa-base |
| Ocean | `Ocean Fill Color`, `Ocean Opacity` | Aparência da superfície oceânica |
| Borders | `Border Color`, `Border Width`, `Border Opacity` | Fronteiras representadas na fonte disponível |
| Layers | `Land Visible`, `Ocean Visible`, `Borders Visible` | Ativa/desativa a camada base sem apagar Regions autorais |
| Composition | `WorldMap Opacity`, `Background Transparent` | Composição sobre footage e animação de Fade In |
| Source | Dataset, versão, escala e camada | Detalhes de leitura, sem editor de dados brutos |

Mudar a cor do WorldMap altera o padrão herdado de regiões sem override, mas nunca apaga `Fill` explicitamente aplicado a um Country/State/Continent. WorldMap não contém um sistema de mapas online, tiles externos nem seletores de projeção não implementados.

### 5.4. Contrato Continent, Country e State (família Region)

| Grupo | Propriedades obrigatórias | Semântica |
|---|---|---|
| Appearance | `Fill Color`, `Fill Opacity`, `Stroke Color`, `Stroke Width`, `Stroke Opacity` | Estilos individuais, nunca recoloração de outro objeto |
| Composition | `Opacity`, `Visibility` | Transparência geral e exibição |
| Shadow | Todos os campos de Shadow compatíveis | Sombra separada da geometria da região |
| Glow | Todos os campos de Glow compatíveis | Brilho separado do Fill persistente |
| Motion Channels | `Reveal Progress`, `Highlight Color`, `Highlight Strength` | Permitem ajustar presets `Reveal` e `Highlight` e keyframes |
| Geography | Nome canônico, tipo, pai, fonte, versão, escala, limites | Informações e âncoras reais, persistentes |
| Camera Target | `Fit Bounds` informativo | Disponibiliza a geometria como alvo de Camera, sem criar animação |

O Country e seu State podem coexistir com estilos diferentes. A Region não ganha controles genéricos livres de latitude/escala que a descolem da geografia. `Reveal Progress` modifica apenas a máscara de revelação; `Highlight Strength` aplica destaque temporário sem sobrescrever `Fill Color` estático. Geometria e identidade não mudam quando a câmera move.

### 5.5. Contrato Route

| Grupo | Propriedades obrigatórias | Semântica |
|---|---|---|
| Endpoints | `From Link`, `To Link`, `From Latitude/Longitude`, `To Latitude/Longitude` | Referências estáveis opcionais + coordenadas efetivas |
| Path | `Path Type`, `Curvature` | `Geodesic` ou `Curved`; curvatura visual georreferenciada |
| Stroke | `Stroke Color`, `Stroke Width`, `Stroke Opacity`, `Stroke Style` | `Solid`, `Dashed`, `Dotted` |
| Arrowhead | `Enabled`, `Size`, `Direction` | Ponta independente, alinhada à tangente do percurso visível |
| Reveal/Trim | `Reveal Progress`, `Trim Start`, `Trim End` | Controlam fração visível ao longo do comprimento normalizado do caminho |
| Composition | `Opacity`, `Visibility` | Afetam só a Route |
| Shadow/Glow | Todos os campos definidos nos efeitos | Efeitos próprios da Route |
| Source | IDs dos vínculos, modo da âncora, origem das coordenadas | Informações verificáveis e persistentes |

Mudar endpoints de uma Route **existente** em Control não recria seu node nem perde os canais animados. `Path Type` não deve oferecer tipos não implementados. Uma Route não calcula navegação por ruas, trânsito nem distâncias rodoviárias.

### 5.6. Contrato Marker

| Grupo | Propriedades obrigatórias | Semântica |
|---|---|---|
| Position | `Latitude`, `Longitude`, `Offset X`, `Offset Y` | Geoanchor estável + deslocamento local em pixels |
| Symbol | `Symbol`, `Size`, `Motion Scale` | Símbolos V1: `Circle`, `Square`, `Diamond`, `Pin` |
| Appearance | `Fill Color`, `Stroke Color`, `Stroke Width`, `Opacity`, `Visibility` | Estilo próprio do marker |
| Shadow/Glow | Todos os campos definidos nos efeitos | Efeitos próprios do Marker |
| Link | Objeto vinculado, quando aplicável | Relação persistente por UUID, sem duplicação silenciosa |

`Size` é em pixels de saída por padrão, não escala geográfica. `Motion Scale` multiplica apenas o símbolo visual e não desloca o geoanchor. `Offset X/Y` são offsets de tela relativos à posição projetada; não reescrevem a latitude/longitude. Marker não aparece automaticamente ao pesquisar uma cidade ou criar Route.

### 5.7. Contrato Label

| Grupo | Propriedades obrigatórias | Semântica |
|---|---|---|
| Content | `Text`, `Font Family`, `Font Size` | Texto editável com Unicode e fontes instaladas |
| Typography | `Text Color`, `Alignment`, `Halo Color`, `Halo Width` | Legibilidade e estilização contextual |
| Position | `Latitude`, `Longitude`, `Linked Object`, `Offset X`, `Offset Y` | Âncora geográfica e offset visual |
| Composition | `Opacity`, `Visibility` | Propriedades individuais |
| Shadow/Glow | Todos os campos definidos nos efeitos | Efeitos próprios do texto |

Label acompanha sua âncora quando a câmera move. A fonte faltante ao reabrir um projeto aciona fallback de sans-serif local e diagnóstico identificável, não desaparecimento silencioso do texto. A V1 não inclui colisão automática, `Screen Pinned` nem templates tipográficos complexos.

### 5.8. Contrato Camera

| Grupo | Propriedades obrigatórias | Semântica |
|---|---|---|
| Center | `Latitude`, `Longitude` | Centro cartográfico da cena |
| View | `Zoom`, `Bearing` | Escala de aproximação e orientação do mapa |
| Target | `Focus Target`, `Fit to Location`, `Fit to Objects` | Enquadramento estático sem keyframes automáticos |
| Pose | `Reset Pose`, `From Pose`, `To Pose` | Estados de câmera usados por presets e canais nativos |
| Motion Channels | `Center Latitude`, `Center Longitude`, `Zoom`, `Bearing` | Canais animáveis acessíveis em Control/Spline |
| Source | Projeção e limites suportados | Configuração informativa da câmera compartilhada |

`Focus Target` pode ser um node de região existente, uma localidade do catálogo ou coordenadas. Focar ou enquadrar é uma alteração **estática** até que o usuário crie keyframes ou aplique Motion. `Camera` não é camada de imagem, não duplica objetos e não possui controles de estilo como Fill/Stroke/Shadow.

### 5.9. Defaults, unidades e faixas

| Propriedade | Valor padrão V1 | Domínio e validação |
|---|---|---|
| Land / Ocean / Border | `#D6D7D2` / `#152B3C` / `#75818B` | Color picker RGB/hex; alpha separado |
| WorldMap | Oceano e terra visíveis; Opacity 100% | Fundo pode ser transparente; camadas independentes |
| Region Fill | Herdado da cor de Land; sem override inicial | Alpha 0–100%; editar cria override próprio |
| Region Stroke | Herdado da borda; Width 1 px | Width 0–40 px; opacidade 0–100% |
| Region Reveal | 100% | Progress 0–100% |
| Region Highlight | Strength 0%, Color `#E5A94D` | Strength 0–100%; cor própria |
| Route Stroke | `#E5A94D`, 4 px, `Solid` | Width 0–40 px; Opacity 0–100%; `Solid/Dashed/Dotted` |
| Route Arrowhead | Enabled, 12 px, `Forward` | Size 0–64 px; segue tangente do percurso |
| Route Path | `Geodesic`, Curvature 0 | Curvature −1,0 a +1,0; usada somente em `Curved` |
| Route Trim | Start 0%; End 100% | 0 ≤ Start ≤ End ≤ 100 |
| Route Reveal | 100% | 0–100% |
| Marker | `Circle`, 12 px, `#E5A94D`, Motion Scale 1,0× | Size 1–200 px; Scale 0–4× |
| Label | Sans-serif instalada, 36 px, `#FFFFFF` | Font Size 1–400 px, texto Unicode; halo 0 px |
| Opacity / Visibility | 100% / Visible | Opacity 0–100%; Visibility boolean |
| Shadow | Disabled, `#000000`, Opacity 25%, Blur 12 px, Distance 4 px, Angle 45° | Blur 0–100 px, Distance 0–200 px, Angle 0–360°, Opacity 0–100% |
| Glow | Disabled, `#8AC7FF`, Intensity 50%, Radius 16 px, Mix 100% | Intensity 0–200%, Radius 0–100 px, Mix 0–100% |
| Camera | Center 0° lat / 0° lon, Fit World, Bearing 0° | Lat −90°..90°, lon normalizada, Bearing −180°..180° |
| Camera Zoom | Fit World = 1,0× | 0,25×–64×, com limite explícito no Inspector |
| Camera Projection | Equirectangular 2D | Sem seletor de projeção na V1 |

Unidades em pixels são relativas à resolução renderizada. Em `Shadow`, `Angle=0°` desloca no sentido positivo do eixo horizontal da imagem e `90°` no sentido positivo do eixo vertical; o vetor de deslocamento é calculado a partir de `Distance` e `Angle`. `Blur` e `Glow Radius` são medidos na imagem de saída e não alteram o geoanchor. Valores fora do domínio exibem erro e não substituem silenciosamente a entrada por outro valor. `Reset Property` retorna ao padrão ou valor herdado sem alterar outras propriedades, keyframes ou overrides independentes. Para componentes com `Enabled = false`, os parâmetros permanecem armazenados e reaparecem ao reativá-los.

### 5.10. Precedência visual e edição animada

O valor efetivo de uma propriedade é calculado, nesta ordem: **padrão da cena → padrão da categoria → override do objeto → valor do canal animado no frame**. Um override explícito de Region sobrevive a mudanças do WorldMap. Se o canal é animado, o Inspector deve distinguir o valor no frame atual do valor estático/base; mudanças obedecem ao comportamento de keyframing do Fusion e não apagam curvas de outros frames sem comando explícito.

A composição deve preservar alpha correto, inclusive quando Shadow ou Glow ultrapassam os limites visuais da geometria. Shadow/Glow são efeitos pós-estilo do próprio node, não alterações permanentes de seus polígonos ou linhas. A resolução, o espaço de cor e a ordem de composição devem produzir resultado correspondente entre Viewer e render final.

## 6. Motion — biblioteca obrigatória e contrato temporal

### 6.1. Princípio operacional

Motion apresenta uma biblioteca de animações compatíveis com o **node selecionado diretamente no Fusion**. O comando `Apply` instala keyframes, modificadores ou expressões que o Fusion consegue avaliar em um frame arbitrário; a animação não pode existir apenas como vídeo pré-renderizado. Seus parâmetros efetivos permanecem acessíveis em Control e suas curvas temporais devem ser editáveis por Spline/Keyframes nativos. Não há timeline, editor Bézier nem mecanismo de reprodução paralelo.

Nenhum node ganha animação ao ser criado. Motion pode ser aberto sem Scene. `Scene` (node) não recebe presets. `Camera` é o único tipo de node com presets de movimento e zoom da **visualização geográfica inteira**.

### 6.2. Catálogo exato de 12 presets na V1

| ID | Node compatível | Preset exibido | Duração padrão | Canais afetados |
|---|---|---|---:|---|
| `MO-CAM-01` | Camera | `Zoom In` | 1,0 s | Camera Zoom |
| `MO-CAM-02` | Camera | `Zoom Out` | 1,0 s | Camera Zoom |
| `MO-CAM-03` | Camera | `Fly To` | 2,0 s | Camera Center, Zoom e Bearing quando configurado |
| `MO-REG-01` | Continent, Country, State | `Fade In` | 0,6 s | Opacity |
| `MO-REG-02` | Continent, Country, State | `Highlight` | 1,0 s | Highlight Strength/Color |
| `MO-REG-03` | Continent, Country, State | `Reveal` | 1,0 s | Reveal Progress |
| `MO-RTE-01` | Route | `Draw Path` | 1,5 s | Reveal Progress |
| `MO-RTE-02` | Route | `Erase Path` | 1,5 s | Reveal Progress |
| `MO-MRK-01` | Marker | `Pop In` | 0,4 s | Motion Scale e Opacity |
| `MO-MRK-02` | Marker | `Pulse` | 0,8 s | Motion Scale |
| `MO-LBL-01` | Label | `Fade In` | 0,5 s | Opacity |
| `MO-MAP-01` | WorldMap | `Fade In` | 0,8 s | WorldMap Opacity |

As entradas Region são compartilhadas entre três tipos de node, mas cada aplicação é independente por instância. Presets com mesmo nome em tipos diferentes são entradas distintas quando seus contratos e canais diferem. A V1 contém exatamente essas 12 entradas obrigatórias; a engenharia não pode substituir alguma por outra animação com comportamento superficialmente semelhante.

### 6.3. Parâmetros comuns dos presets

| Campo | Semântica e padrão |
|---|---|
| `Start` | Frame atual do playhead ao aplicar; depois editável sem deslocar outros objetos |
| `Duration` | Duração acima, exibida em segundos com conversão para frames segundo FPS; mínimo de 1 frame |
| `Delay` | 0 frame por padrão; não negativo; intervalo antes do começo efetivo |
| `Easing` | `Ease In Out` por padrão para câmera/fade/pop; `Linear` para Draw/Erase; Spline permanece editável |
| `Direction` | Apenas quando determina direção espacial ou de progressão do preset |
| `From` / `To` | Alvos, poses ou valores explícitos, conforme o preset |
| `Strength` / `Amount` / `Amplitude` | Apenas para efeitos com intensidade variável |
| `Apply` | Instala a animação, criando identificador de preset e canais controlados |
| `Update` | Atualiza parâmetros e canais pertencentes ao preset, sem proliferar nodes ou keyframes |
| `Remove` | Remove o preset com política de preservação de edições manuais |
| `Customized` | Estado sinalizado quando qualquer canal sob o preset foi editado manualmente |

Os valores de `Start`, `Duration` e `Delay` usam a escala temporal do Fusion e armazenam uma representação inequívoca de frames/FPS. Em uma alteração de FPS, o sistema deve manter coerência da duração em segundos dos presets, atualizando os frames gerenciados sem alterar silenciosamente animações personalizadas. Mudanças de retime, corte de composição ou reprodução reversa não podem produzir frames diferentes para a mesma avaliação temporal sem regra documentada.

### 6.4. Especificação de cada preset

#### 6.4.1. Camera — Zoom In

**Efeito:** anima apenas `Camera Zoom`, com foco mantido na posição geográfica atual. `Start Zoom` é a leitura do início da animação; `End Zoom` = `Start Zoom × Zoom Factor`, com fator padrão **1,5** e fator configurável maior que 1. O resultado é limitado à faixa de zoom válida e informa o clamp quando atingido. Não escala país/rota individualmente, não altera posições geográficas nem escreve keyframes nos demais nodes.

#### 6.4.2. Camera — Zoom Out

**Efeito:** anima apenas `Camera Zoom` do valor inicial para `Start Zoom ÷ Zoom Factor`, com fator padrão **1,5**, maior que 1. Conserva o foco geográfico e respeita limites de zoom. Nenhum outro node recebe keyframes por causa desse zoom.

#### 6.4.3. Camera — Fly To

**Efeito:** anima a pose da câmera de `From` até `To`. `From` assume `Current Camera Pose`; o usuário pode indicar outra pose ou um node existente. `To` aceita node `Continent/Country/State/Marker`, localização geográfica conhecida ou coordenadas. Para objeto poligonal, `Fit` utiliza a extensão real da geometria com `Fit Margin` padrão **8%** (0–40%); não infere capital. Para ponto, usa `End Zoom` explícito ou o valor da câmera atual como padrão. Bearing final é opcional. Animar centro e zoom juntos é permitido e utiliza os canais de Camera compatíveis com Spline. A interpolação de longitudes evita giro de 360° desnecessário e respeita a política de antimeridiano.

#### 6.4.4. Region — Fade In

**Efeito:** anima `Opacity` de **0%** até o valor-base efetivo da Region no início da animação, mantendo Fill, Stroke e geometria intactos. O valor-base de destino é armazenado e permanece editável. Aplicar sobre um canal Opacity já animado exige política de conflito, não substituição silenciosa.

#### 6.4.5. Region — Highlight

**Efeito:** `Highlight Strength` varia de **0% → intensidade configurada → 0%** ao longo da duração. `Highlight Color` padrão `#E5A94D`; intensidade padrão **100%** (intervalo 0–100%). Metade da duração conduz ao pico, salvo edição manual dos keyframes. A camada de destaque é calculada sobre o Fill/Stroke do node sem destruir seus valores autorais. A região volta à aparência-base ao finalizar o preset.

#### 6.4.6. Region — Reveal

**Efeito:** `Reveal Progress` varia de **0% a 100%**, revelando apenas o polígono do node por máscara espacial. A direção inicial é `Left to Right`, calculada no retângulo projetado da geometria no instante avaliado. Outras direções somente podem ser oferecidas se implementadas e testadas. Ilhas e multipolígonos seguem a mesma progressão espacial, preservando contorno e alpha corretos.

#### 6.4.7. Route — Draw Path

**Efeito:** anima `Reveal Progress` de **0% a 100%**. O progresso segue o comprimento normalizado do percurso já recortado por Trim, de `From` até `To`. A ponta de seta, quando ligada, acompanha o extremo da porção visível; a espessura e os efeitos são herdados dos controles atuais da Route. Duração padrão 1,5 s, interpolação inicial `Linear`.

#### 6.4.8. Route — Erase Path

**Efeito:** anima `Reveal Progress` de **100% a 0%**, retirando progressivamente a parte visível na direção inversa do desenho. Não apaga o node, nem seus endpoints, nem seu estilo; término em 0% significa linha invisível apenas naquele instante temporal. Duração padrão 1,5 s, interpolação inicial `Linear`.

#### 6.4.9. Marker — Pop In

**Efeito:** `Motion Scale` assume **0,70× → 1,10× → 1,00×** e `Opacity` assume **0% → opacidade-base**. Padrão `Overshoot` **10%**, ajustável. O símbolo muda de tamanho ao redor de sua âncora projetada, sem modificar latitude/longitude. Duração 0,4 s.

#### 6.4.10. Marker — Pulse

**Efeito:** `Motion Scale` assume **1,00× → 1,20× → 1,00×**, amplitude padrão **20%** (0–100%) e `Cycles` padrão **1** (inteiro 1–10). A opacidade e a âncora não mudam por padrão. Duração 0,8 s.

#### 6.4.11. Label — Fade In

**Efeito:** `Opacity` passa de **0%** à opacidade-base do Label. Conteúdo, fonte, halo, posição e vínculo geográfico permanecem intocados. Duração padrão 0,5 s.

#### 6.4.12. WorldMap — Fade In

**Efeito:** `WorldMap Opacity` passa de **0%** à opacidade-base configurada. Os overrides de Country, State e Continent permanecem independentes. Duração padrão 0,8 s.

### 6.5. Conflitos, coexistência e edição manual

- **Um preset ativo por canal animável.** Dois presets podem coexistir se não modificarem o mesmo canal. Exemplo: um preset `Highlight` na Region pode coexistir com `Fade In` porque controlam canais distintos.
- Se um novo preset afetar um canal já ocupado, Motion oferece `Replace` ou `Cancel`, com explicação dos canais afetados. A V1 não mescla automaticamente keyframes no mesmo canal.
- `Update` reconhece o identificador da aplicação e atualiza o conjunto existente sem multiplicar keyframes, nós, modificadores ou expressões.
- Edição manual de qualquer canal do preset sinaliza `Customized`. Uma atualização que sobrescreva os keyframes manuais só é executada após confirmação específica.
- `Remove` de preset não personalizado apaga somente sua animação gerenciada, restaurando o estado estático efetivo. Para `Customized`, oferecer `Keep Animation` (desassociar preset e preservar keyframes) ou `Remove Animation` (remover os canais que pertencem à aplicação, não o objeto).
- Um preset nunca remove outro canal independente, não modifica nodes de terceiros e não pode sobrescrever o estilo estático sem comando deliberado.
- Animação aplicada sobre frame fora do intervalo válido da composição produz erro claro. Duração mínima é de um frame.
- O estado do preset e as curvas permanecem corretos após salvar/reabrir, duplicar cena ou renderizar frames em ordem aleatória.

### 6.6. Contrato de dados para os presets

Cada aplicação de preset guarda: `preset_id`, `preset_version`, `instance_id`, `object_id`, `supported_object_types`, `input_parameters`, `animated_channels`, `start_frame`, `duration_frames`, `delay_frames`, `fps_reference`, `initial_keys`, `interpolation`, `existing_animation_policy`, `manual_edit_state`, `remove_reset_policy` e referências aos canais reais do Fusion. A implementação deve conseguir distinguir estado base de valor temporal e reconstruir o contexto `Customized` ao reabrir o projeto.

O único estado temporal que decide pixels é a avaliação dos canais no frame solicitado pelo host. Não depender da passagem sequencial por frames, de timers da janela Scene nem de cache temporal divergente.

## 7. Catálogo geográfico e dados offline

### 7.1. Fonte e datasets instalados

O Natural Earth é a **fonte geográfica da V1**. O instalador inclui os dados e índices necessários para utilizar toda a V1 sem internet, com uma base vetorial na escala **1:50m** e respectivos conjuntos suportados no manifesto: Admin 0, Admin 1 disponível, Populated Places, superfícies terrestres/oceânicas e limites necessários ao WorldMap. Um conjunto só pode ser anunciado como suportado se seus arquivos e geometrias estiverem de fato incluídos e testados. Não instalar silenciosamente fontes alternativas.

O manifesto registra para cada pacote: `dataset_id`, nome, versão da fonte, escala, tipo de feição, atributos necessários, caminho relativo, SHA-256, cobertura, atribuição/licença, status de instalação e status de suporte. O produto não promete cobertura universal de cidades ou estados onde a fonte não fornece dados. Escalas adicionais e arquivos raster não são obrigação da V1.

### 7.2. Índice de busca e identidade

O catálogo local indexa nome canônico, aliases, variantes com/sem acento, tipo geográfico, pai administrativo, identificador estável da fonte, geometria disponível, ponto representativo quando houver, bounding box, dataset/versão e capacidades permitidas. Busca por nomes deve funcionar sem código ISO e sem diferenciar `São` de `Sao` no reconhecimento. Resultados homônimos devem incluir hierarquia suficiente para desambiguação.

A busca não fabricará correspondência exata de endereço/rua, perímetro municipal ausente ou relação administrativa não presente nos dados. Se a localidade estiver disponível somente como ponto, deve informar `Point available; administrative polygon unavailable` e desabilitar ações que dependem de polígono.

### 7.3. Tipos e geometrias

| Tipo geográfico | Representação V1 | Uso |
|---|---|---|
| Continent | Composição de polígonos Admin 0 classificados pela fonte | Region composta e alvo de Fit |
| Country | Polígono/multipolígono Admin 0 | Country node, Fill/Stroke/Highlight/Reveal |
| State/Province | Polígono/multipolígono Admin 1 disponível | State node, Fill/Stroke/Highlight/Reveal |
| City | Ponto Populated Places quando disponível | Marker, Label, endpoint ou alvo da câmera |
| Custom Point | Latitude/longitude informadas pelo usuário | Marker, Label, endpoint ou alvo da câmera |
| Urban Area | Dado separado, sem equivalência automática com município | Não é tipo autoral próprio na V1 |
| Address/Street | Sem cobertura própria de geocodificação | Não suportado |

### 7.4. Coordenadas, geometria e limites

A referência espacial interna para âncoras usa latitude/longitude WGS84 em graus. Latitude deve ficar entre −90° e +90°; longitude é normalizada para intervalo definido de ±180°, preservando continuidade no tratamento da câmera. Polígonos devem preservar multipolígonos, ilhas, anéis, furos, bordas compartilhadas, geometrias multipartes e recortes no antimeridiano. A V1 não promete precisão legal/cadastral nem inventa detalhamento acima da escala de origem.

O renderizador calcula projeção e clipping para os dados instalados. Deve impedir fissuras, contornos duplicados sem motivo, polígonos invertidos, preenchimento de lagos/furos e saltos na passagem pelo antimeridiano. Política editorial de fronteiras contestadas segue a fonte versionada e deve ser identificável em documentação; não deve ser modificada silenciosamente pelo plugin.

### 7.5. Continentes

Cada Continent node representa o conjunto de países classificados naquele continente pela fonte instalada. Suas peças devem ser compostas preservando ilhas e geometrias válidas; não é permitido substituir a forma por um retângulo ou contorno fictício. O resultado não se apresenta como fronteira administrativa oficial do continente. Se algum país não tiver geometria disponível, o diagnóstico informa o limite do conjunto.

### 7.6. Versões e persistência de dados

Cada objeto geográfico persiste `source_id`, `source_version`, dataset e escala associados. Atualizar o CartoRig não substitui silenciosamente geometrias utilizadas por projetos salvos. Se a versão necessária não estiver instalada, a abertura mostra diagnóstico e oferece instalação por interface de pacote compatível ou migração explícita, com confirmação e possibilidade de manter o projeto sem alterações. O projeto não deverá fabricar geometrias para preencher uma ausência.

O catálogo pode possuir índices adicionais otimizados, mas os arquivos essenciais devem estar dentro do pacote distribuído. Nenhum recurso instalado depende de token, conta, tile server, chamada externa ou download manual de arquivo ZIP pelo usuário.

## 8. Route — contrato cartográfico, vínculos e visualização

### 8.1. Modelo do objeto

A Route contém identidade e estilo próprios, pelo menos dois endpoints, tipo de trajetória, parâmetros de desenho e canais temporais. Cada endpoint reúne: `linked_object_id` opcional, `anchor_mode`, `latitude`, `longitude`, origem dos dados e referência versionada quando existir. A referência a Country/State/Continent/Marker ajuda a gerenciar dependências, mas **nunca substitui a coordenada**. A Route mantém a última coordenada efetiva válida mesmo quando o objeto de referência é removido com congelamento confirmado.

### 8.2. Anchor A e Anchor B

- `Representative Point`: ponto interno estável gerado por método geométrico válido sobre o polígono instalado e indicado ao usuário como representativo; não presume capital nem centroide fora de território.
- `Choose City/Location`: ponto do catálogo com latitude/longitude conhecida, apresentado com nome, país/hierarquia e condição de estar dentro do objeto vinculado quando pertinente.
- `Enter Coordinates`: latitude/longitude explícitas, com validação de faixa e, para modo vinculado, confirmação se o ponto estiver fora do polígono de referência.

Quando a âncora está vinculada a um `Marker`, alterar a latitude/longitude desse Marker atualiza o endpoint efetivo da Route no mesmo frame, sem reescrever o histórico do node Route. Para `Country`, `State` ou `Continent`, a âncora escolhida permanece uma coordenada explícita, não acompanha automaticamente capital, centroide ou a seleção de outra localidade. O último par de coordenadas efetivas é mantido para eventual congelamento de dependência.

Ao criar uma Route entre Brasil e Argentina, o usuário deve confirmar uma âncora para cada país. O preenchimento automático de um campo baseado no país escolhido não cria uma decisão editorial invisível. Se o usuário não configurar um dos endpoints, `Create Route` permanece indisponível e indica qual campo falta.

### 8.3. Tipos de trajetória

| Tipo | Definição observável |
|---|---|
| `Geodesic` | Trajetória geográfica curta entre duas coordenadas sobre o modelo terrestre adotado, amostrada em segmentos suficientes para o zoom/resolução e corretamente projetada/recortada |
| `Curved` | Arco visual entre os mesmos endpoints com ponto de controle calculado de forma determinística no espaço cartográfico, preservando georreferenciamento durante pan/zoom |

`Geodesic` usa o caminho mais curto na superfície do elipsoide **WGS84**, calculado por algoritmo geodésico inverso/direto robusto e amostrado adaptativamente. Os segmentos projetados devem respeitar erro visual máximo de aproximadamente 1 pixel na resolução de render (ou um limite mais estrito quando necessário para contornos suaves), sem limitar pontos a um número fixo que produza cantos visíveis em 4K. Na descontinuidade de longitude, cortar os trechos na borda do mapa e continuar do lado correto, sem traçar linha atravessando o mapa inteiro.

`Curved` é uma Bézier **quadrática no espaço cartográfico mundial antes da câmera**. Após desenrolar longitudes para o trecho contínuo mais curto, os endpoints projetados desse espaço são `P0` e `P2`; o ponto central é `M=(P0+P2)/2`; a perpendicular unitária ao segmento é `N`; o ponto de controle é `P1=M + Curvature × (|P2-P0|/2) × N`; o arco é `B(t)=(1−t)²P0 + 2(1−t)tP1 + t²P2`, para `0≤t≤1`. `Curvature` varia de −1 a +1: `0` produz segmento projetado sem deflexão, o sinal escolhe o lado e o módulo determina a intensidade. Essa construção é geoancorada no plano cartográfico, nunca recalculada a partir dos pixels do Viewer após cada pan/zoom. A amostragem deve respeitar o mesmo limite visual de erro e o mesmo clipping do antimeridiano. Curved não é rota rodoviária nem geodésica.

Em ambos os tipos, mover câmera não altera as coordenadas dos endpoints nem produz drift no Viewer. Trechos de comprimento zero ou coordenadas inválidas desabilitam criação/aplicação com mensagem apropriada; não gerar uma seta sem direção definida.

### 8.4. Stroke, estilos, arrowhead e efeitos

Route aceita linha contínua, pontilhada e tracejada. Width, dash spacing e pontilhado devem ter unidades em pixels de renderização e resultado previsível entre preview/render, inclusive quando o zoom muda. Arrowhead é um elemento visual independente do Stroke: pode ser desabilitado, tem tamanho configurável e segue a tangente do trecho visível na direção escolhida. Shadow e Glow operam sobre o traço visível, sem modificar a geometria base nem os endpoints.

### 8.5. Trim e Reveal Progress

O percurso possui uma parametrização **por comprimento acumulado**, normalizado de 0% a 100%. `Trim Start` e `Trim End` recortam o intervalo geométrico ativo, exigindo `0 ≤ Trim Start ≤ Trim End ≤ 100`. `Reveal Progress` (0–100%) controla a fração visível **desse trecho recortado**, a partir de sua origem na direção ativa. Exemplo: com Trim 20–80 e Reveal 50, aparece a primeira metade do subtrecho 20–80. O `Draw Path` anima Reveal 0→100; `Erase Path`, 100→0. Uma linha com Reveal 0 permanece como node válido, apenas não produz traço naquele frame.

### 8.6. Dependência e edição posterior

Editar cor, estilo, direção ou visibilidade dos países de origem/destino **não** altera a Route. Uma `Label` vinculada a um Marker acompanha sua posição geográfica, mantendo o próprio offset visual. Quando um preset `Fly To` aponta para um node alvo que deixa de existir, a operação de exclusão exige `Freeze Camera Target` ou `Cancel`; o congelamento preserva a pose de destino e os canais animados, não move a câmera abruptamente. Renomear país preserva vínculo por UUID. Editar endpoints em Control mantém node e outros keyframes; mudanças que alterem o significado de uma animação são sinalizadas, mas não removem curvas não relacionadas. Duplicar Route cria canais próprios e reutiliza referências aos mesmos endpoints. Excluir origem vinculada apresenta `Keep Route and Freeze Anchor` ou `Cancel`; nunca exclui Route automaticamente.

### 8.7. Limites da V1

A Route V1 não tem waypoints arbitrários, edição manual de handles no Viewer, cálculo de estradas/trânsito, marcador viajante, múltiplas arrowheads, roteamento em lote ou trajetórias calculadas por serviços online. Esses recursos não devem aparecer como opções ativas na UI.

## 9. Camera — projeção e navegação geográfica

### 9.1. Câmera compartilhada

Há uma única `CR_Camera_Main` por cena. Todos os objetos geoancorados utilizam, para cada frame, a **mesma transformação geográfica** de latitude/longitude para coordenadas projetadas e tela. Um pan, zoom ou Fly To modifica a visualização comum, nunca reescreve individualmente os anchors dos objetos. A câmera é node controlador real, não uma camada de vídeo independente.

### 9.2. Projeção V1

A V1 utiliza **projeção equiretangular 2D**, com coordenadas e clipping coerentes para mundo inteiro, incluindo antimeridiano. Não apresenta seletor de projeção não implementada. O centro da câmera é latitude/longitude, zoom relativo a `Fit World` e bearing orienta o mapa de forma consistente. Limites da projeção e da geometria devem ser respeitados com clipping previsível e mensagens quando o usuário exigir detalhe inexistente no dataset.

### 9.3. Operações estáticas em Control

- `Focus Target`: centraliza na coordenada/localidade/node escolhido **sem keyframe automático**.
- `Fit to Location`: ajusta foco/zoom para incluir o ponto ou polígono; para ponto preserva zoom atual quando não houver tamanho espacial para enquadrar.
- `Fit to Objects`: encontra bounding box combinada de objetos selecionados no campo próprio do Camera Control, sem seleção via Scene.
- `Reset Pose`: retorna ao enquadramento mundial documentado, sem apagar keyframes de outros canais.
- `Save Pose`: permite registrar uma pose como valor de referência da própria Camera quando houver interface para reutilização, sem criar outro node.

### 9.4. Movimento animado

`Zoom In`, `Zoom Out` e `Fly To` pertencem exclusivamente ao Motion de Camera. Um alvo Country usa os limites da geometria como referência de Fit, com margem. Um alvo Marker/City é ponto; a escala final é explícita ou mantém valor atual. Durante Fly To, todos os overlays seguem o centro/zoom/bearing calculados no frame; nenhuma Region ou Route recebe keyframes duplicados de movimento.

### 9.5. Interpolação e bordas de mundo

O sistema trata cruzamentos próximos de ±180° sem giro longo involuntário, mantendo continuidade de longitude para interpolação e normalização na apresentação. Para o modo equiretangular, a posição base segue `x = longitude desembrulhada` e `y = latitude` em coordenadas angulares; centro, zoom, aspect ratio e bearing são aplicados posteriormente como transformação de visualização única. `Fit World` enquadra a extensão global na imagem mantendo a proporção do frame, sem esticar países. Um objeto e sua Route devem usar a mesma cadeia de projeção e transformação. Projeção/clipping devem evitar duplicação de continentes/linhas no limite de imagem e separar corretamente polígonos que atravessam o antimeridiano. Redimensionar a composição muda o enquadramento de saída preservando alvos/anchors e regras de Fit; não converte coordenadas para posições fixas de tela.

## 10. Arquitetura de software e integração com o Fusion

### 10.1. Componentes lógicos

A tecnologia concreta pode combinar Lua/Python integrado ao ambiente suportado, Fuses, macros, módulos nativos e adaptadores do host. O usuário não instala compiladores nem dependências de desenvolvimento. Independentemente dos binários escolhidos, a implementação deve preservar os contratos abaixo.

| Componente | Entrada | Responsabilidade | Saída garantida |
|---|---|---|---|
| `SceneUI` | Eventos de criação e CRUD | Exibir janela UI Manager, filtrar catálogo, validar comandos estruturais | Comando de domínio; não edita estilo ou animação |
| `SceneService` | Comando + projeto/timeline + IDs | Criar nova Fusion Composition por cena e executar operações estruturais de forma transacional | Composição e estado isolados ou rollback seguro |
| `GeoCatalog` | Query, tipo, hierarquia | Consultar índice Natural Earth offline | Localizações tipadas, dados de geometria e aliases |
| `GeoEngine` | Feições, âncoras, câmera | Projeção, caminho, clipping, regiões e integridade cartográfica | Primitivas de render no frame solicitado |
| `NodeFactory` | Tipo, UUID, campos e relações | Criar/configurar nodes físicos do Fusion e seus controles | Node selecionável, integrado e persistente |
| `FusionAdapter` | Resolve Project/Timeline/TimelineItem e composição Fusion | Inserir clipe pela API do Resolve, operar nodes/Inspector/Undo/Viewer/Spline e conectar MediaOut | Uma composição física por Scene, sem alterar recursos externos |
| `MapRenderer` | Estado autoral + dados + tempo + tamanho | Renderizar WorldMap e objetos com efeitos/alpha | Frame RGBA determinístico |
| `MotionEngine` | Preset, playhead, FPS, canais | Aplicar/atualizar/remover canais temporais nativos | Animação editável e recuperável |
| `StateStore` | IDs, relações, parâmetros e versão | Persistência e migração de cena/objetos | Save/reopen sem janela Scene |
| `Diagnostics` | Erros do host, datasets e estado | Diagnóstico seguro, recuperação e registros técnicos | Falhas compreensíveis, sem perda silenciosa |
| `Installer` | Artefatos compilados e dados | Instalar/atualizar/remover pelo Windows | Produto pronto para uso, offline |

O software pode agrupar esses componentes internamente, mas não pode fundir as responsabilidades a ponto de bloquear edição independente ou exigir Scene aberto para avaliar/renderizar a composição.

### 10.2. Entradas, saídas e identidade de cada node

| Interface lógica do node | Requisito |
|---|---|
| `Identity` | UUID, `scene_id`, tipo, nome visível, `schema_version`, estado CartoRig-owned |
| `Geography` | Source ID/versão, geometria ou anchor quando aplicável; vínculo à câmera compartilhada |
| `Control` | Controles de Inspector nativos correspondentes ao tipo e canais animáveis aplicáveis |
| `Motion` | Presets compatíveis, identificação de aplicações e canais resultantes |
| `Render` | Contribuição visual ou controle estrutural real no pipeline da cena |
| `Persistence` | Valores efetivos, IDs, curvas e relações salvos no contexto do projeto |
| `Diagnostics` | Estado de dado ausente, link quebrado, erro de projeção ou incompatibilidade de versão |

Os nodes podem comunicar-se com renderizador compartilhado por atributos, conectores ou metadados persistentes, desde que o comportamento seja nativo ao fluxo Fusion. Se o Node Editor exibir nodes auxiliares técnicos, devem ser identificáveis como gerenciados; não devem obscurecer os nodes autorais nem exigir manipulação cotidiana do usuário.

### 10.3. Pipeline de avaliação de um frame

A avaliação no frame `t` deve seguir dependências estáveis, sem exigir processamento dos frames anteriores:

1. Carregar o estado persistente da cena ativa, IDs e manifesto de geodados correspondente.
2. Avaliar os canais de Control e Motion no frame solicitado pelo Fusion.
3. Determinar pose geográfica efetiva da Camera no frame.
4. Resolver âncoras e geometrias dos nodes e aplicar projeção/clipping compartilhados.
5. Aplicar estilos herdados, overrides e valores animados dos objetos.
6. Gerar geometrias visíveis de Region, Route, Marker e Label, incluindo Trim/Reveal.
7. Aplicar Shadow/Glow e opacidades por node, conservando alpha.
8. Compor pela ordem visual persistente sobre WorldMap.
9. Produzir buffer compatível com Viewer/MediaOut e invalidar caches dependentes quando houver alterações.

A saída deve corresponder ao mesmo frame na reprodução normal, seek aleatório, reprodução reversa e exportação. O cache pode otimizar geometria estática e dados, mas não pode reutilizar uma imagem com Fill, câmera, endpoints ou keyframes desatualizados.

### 10.4. Estado canônico e interfaces nativas

`StateStore` mantém identidade, hierarquia, fontes, relações, versões e demais dados do domínio. Os parâmetros editáveis e curvas precisam estar integrados ao mecanismo real do Fusion. Se algum valor aparecer tanto em um node quanto em metadados do domínio, sua regra de atualização deve ser unívoca: **o estado efetivo do node/canal prevalece para render e Inspector; o armazenamento do domínio preserva identidade e relações e registra referências ao canal**. Sincronização por nome textual ou cópia de variável apenas em memória da janela não é permitida.

Salvar com Scene fechado deve serializar tudo que a renderização precisa, incluindo geometrias/referências à fonte, overrides, links e animações. A interface UI Manager nunca constitui uma dependência de execução de cada frame.

### 10.5. Modelo mínimo de serialização

O formato abaixo descreve uma estrutura semântica obrigatória. A serialização física pode usar dados associados aos nodes, à composição e arquivos de recursos versionados. As chaves e os relacionamentos devem possuir equivalentes estáveis e migráveis.

```json
{
  "schema_version": "1.0.0",
  "scene_id": "<scene-uuid>",
  "title": "Map Scene",
  "dataset_manifest_id": "<manifest-sha256>",
  "world_map_id": "<worldmap-uuid>",
  "camera_id": "<camera-uuid>",
  "objects": [
    {
      "object_id": "<country-uuid>",
      "scene_id": "<scene-uuid>",
      "object_type": "Country",
      "display_name": "Brazil",
      "node_name": "CR_Country_Brazil_001",
      "source": {
        "dataset_id": "<natural-earth-dataset>",
        "source_version": "<version>",
        "feature_id": "<stable-feature-id>"
      },
      "draw_order": 20,
      "style_overrides": {"fill_color": "#E5A94D"},
      "visible": true,
      "motion": []
    },
    {
      "object_id": "<route-uuid>",
      "scene_id": "<scene-uuid>",
      "object_type": "Route",
      "display_name": "Brazil to Argentina",
      "node_name": "CR_Route_Brazil_Argentina_001",
      "from": {
        "linked_object_id": "<country-uuid>",
        "anchor_mode": "EnterCoordinates",
        "latitude": "<selected-latitude>",
        "longitude": "<selected-longitude>"
      },
      "to": {
        "linked_object_id": "<argentina-uuid>",
        "anchor_mode": "ChooseCity",
        "latitude": "<selected-latitude>",
        "longitude": "<selected-longitude>"
      },
      "path_type": "Geodesic",
      "curvature": 0.0,
      "trim_start": 0.0,
      "trim_end": 1.0,
      "reveal_progress": 1.0,
      "motion": []
    }
  ]
}
```

`<...>` indica campos obrigatoriamente substituídos por dados reais da cena; não são coordenadas ou IDs usados automaticamente pelo produto. Os endpoints mantêm `linked_object_id = null` após congelamento autorizado; latitude e longitude continuam válidas. `motion` referencia a definição e o estado dos canais nativos, com versão, timing e condição `Customized`. Cada objeto estrutural também possui UUID, mesmo quando omitido da amostra simplificada.

### 10.6. Cache, invalidação e desempenho interno

Mudanças em câmera, geometrias, dados, Fill/Stroke, Shadow/Glow, offsets, texto/fonte, endpoints, Curvature, Trim/Reveal, ordem visual e canais animados invalidam os caches pertinentes. A engenharia deve separar preparação de geometria estática de avaliação temporal sempre que possível. Não reconstruir toda a lista de nodes nem reler datasets completos a cada mudança de keyframe. O catálogo deve funcionar sem bloquear a UI do Fusion em operações ordinárias de consulta.

## 11. Persistência, duplicação e integridade

### 11.1. Save/reopen

O projeto deve preservar a cena e cada node com sua geometria/fonte versionada, ordem visual, override de estilo, câmera, âncoras, vínculos, parâmetros Motion, keyframes e curvas. Fechar/reabrir o Resolve sem Scene aberto deve produzir o mesmo quadro no Viewer e na Deliver. Projetos salvos devem renderizar sem carregar a janela UI Manager, executar busca ou exigir autorização de rede.

### 11.2. Duplicação de objeto e de composição

Uma cópia de objeto recebe UUID novo e parâmetros/curvas independentes. Cópia de Route conserva os mesmos endpoints referenciados, salvo criação separada dos endpoints. Uma cópia de cena ou composição recebe novo `scene_id` e novos UUIDs para **todos os nodes CartoRig**, com remapeamento de ligações internas; modificar a cópia não afeta o original. O mecanismo deve reconhecer duplicação feita pelo próprio Fusion e evitar que duas composições permaneçam compartilhando IDs internos por acidente.

### 11.3. Renomeação e nós de terceiros

Renomear nodes pelo Fusion ou Scene altera identificação visual, não a referência por UUID. Nodes que não sejam `CartoRig-owned` nunca são apagados, recoloridos, desconectados ou reconfigurados silenciosamente por CRUD do plugin. Se um rearranjo manual do grafo tornar uma operação insegura, Scene bloqueia a ação com diagnóstico, sem destruir o trabalho do usuário.

### 11.4. Undo, rollback e falhas parciais

Cada ação CRUD possui escopo transacional. Se o Fusion fornecer Undo/Redo adequado, a operação entra na pilha nativa como uma ação coerente. Se houver limitação comprovada para um comando, a operação deve oferecer rollback/recuperação consistente e uma mensagem clara; nunca depender de restaurar arquivos manualmente. Uma criação interrompida não deixa um node gerenciado aparente mas sem vínculo; uma exclusão interrompida não remove apenas metade das relações.

### 11.5. Migração e compatibilidade

O `schema_version`, as versões do renderizador e dos dados permitem migrar objetos salvos preservando UUID, overrides e curvas. Mudança de dataset não altera geometrias silenciosamente. Se uma migração segura não estiver disponível, o projeto permanece intacto e a interface informa o componente ou versão necessária. Um upgrade não regrava automaticamente o projeto ao abrir sem solicitação explícita de migração quando há risco de perda de compatibilidade.

### 11.6. Diagnóstico

O produto registra eventos suficientes para identificar erros de integração, dataset, node, versão, projeção, operações CRUD e presets, com código, contexto técnico e caminho de recuperação. Mensagens são compreensíveis no idioma da interface; logs não coletam projetos ou informações pessoais sem ação voluntária do usuário. Erro de geometria de um objeto não deve derrubar o DaVinci Resolve nem corromper toda a cena.

## 12. UI, estados, ergonomia e consistência

### 12.1. Estrutura mínima de Scene

A janela Scene contém título/composição ativa; comandos de ciclo de vida da cena; campo de busca geográfica e filtro de tipo; resultados tipados com ações de criação; lista de objetos existentes voltada **somente para CRUD**; comandos Rename/Duplicate/Delete/Reorder; criação de Route com escolha de referências/âncoras; mensagens de validação e erro. Não inclui color pickers, presets Motion, editor de câmera, painel detalhado de propriedades ou ferramentas de seleção para edição.

Comando estrutural executado com êxito pode informar `Node created: CR_Country_Brazil_001`. Não precisa selecionar o node no grafo nem abrir o Inspector. A ação `Close Scene` pode ser usada imediatamente após criar objetos.

### 12.2. Estrutura mínima do Inspector

Ao clicar em um node CartoRig, o Inspector mostra identificação do node e as seções `Control` e `Motion`, com grupos de parâmetros pertinentes ao tipo. Identificadores técnicos, hashes, versões e logs ficam em área de informações/diagnóstico secundária. O usuário não precisa digitar ISO3, editar scripts ou conhecer APIs do Fusion para tarefas comuns. O Inspector não contém CRUD estrutural (Add/Delete/Duplicate de objetos) como principal função.

### 12.3. Estados e mensagens

| Condição | Comportamento exibido |
|---|---|
| Ausência de cena | `Create Scene` disponível em Scene; nenhum objeto fictício é apresentado |
| Busca sem resultados | Mensagem de ausência nos dados instalados, com orientação de filtro |
| Cidade sem polígono | Marker/Label disponíveis; `Add State/Country` desabilitados conforme tipo |
| Node de terceiro selecionado | Inspector nativo desse node; não exibir Control/Motion de objeto CartoRig anterior |
| Node CartoRig selecionado | Control/Motion do exato `object_id` do node |
| Node estrutural selecionado | Control de leitura/edição pertinente; Motion sem presets quando não aplicável |
| Propriedade sem suporte no tipo | Não expor campo enganoso ou desabilitar com razão clara |
| Bloqueio de vínculo | Informar referência inválida e impedir operação destrutiva |
| Dados geográficos faltantes | Informar dataset, feição ou cobertura ausente |
| Fonte incompatível | Não substituir geometria; indicar migração/instalação compatível |
| Falha ao criar ou apagar | Mostrar falha; rollback ou reparo seguro |
| Preset em conflito | `Replace` / `Cancel` e canais que seriam alterados |
| Preset modificado manualmente | Indicar `Customized` e preservar keyframes na política de Update/Remove |

### 12.4. Ergonomia, localização e acessibilidade

A interface do produto é inteiramente em inglês; nomes geográficos pesquisáveis podem aparecer em outras línguas e com diacríticos. Rótulos usam `Scene`, `Control`, `Motion`, `Region`, `Route`, `Fill`, `Stroke`, `Zoom`, `Fly To` de modo consistente. A UI deve funcionar em diferentes escalas de exibição do Windows e em layouts de trabalho do Fusion com alturas/larguras usuais do Inspector. Controles precisam ter contraste, foco visível, teclado quando suportado, valores tabuláveis e mensagens que não dependam apenas de cor.

A equipe deve observar usuários que conhecem o DaVinci Resolve, mas não GIS, criando Brasil, mudando sua cor, adicionando rota Brasil→Argentina e animando a câmera. Se o fluxo os induzir a voltar ao Scene para selecionar objetos ou a procurar controles no lugar errado, a interface precisa ser corrigida.

## 13. Requisitos não funcionais e qualidade de imagem

### 13.1. Renderização e alpha

Os nodes CartoRig precisam compor corretamente em RGBA com outras ferramentas e `MediaIn` do Fusion. Fundo transparente do WorldMap não pode ser substituído por preto opaco inesperado; bordas, sombras, brilho e texto não podem gerar halos de alpha incorretos em composições sobre footage. O resultado no Viewer e na Deliver deve manter geometria, estilos, keyframes e gestão de cor coerentes. Renderizar na timeline Edit é permitido como consumo da composição pronta, nunca como requisito de autoria.

### 13.2. Resoluções de teste

A V1 deve ser avaliada em 1920×1080, 2560×1440 e 3840×2160. Os testes devem incluir cenas vazias, regiões extensas, estados pequenos, rotas curvas, labels acentuados, câmeras animadas, alpha sobre footage e mudança de fps. O relatório registra hardware (CPU/GPU/RAM), versão do Windows, Resolve Studio, driver, dataset e escala, resolução, quantidade de objetos, latência, uso de memória e duração de render.

### 13.3. Responsividade e estabilidade

A pesquisa offline não pode travar indefinidamente o Viewer. O render não pode gerar crescimento ilimitado de nodes/caches a cada Apply/Update de Motion, Seek ou edição granular. Cenários de carga devem usar cenas com dezenas de Regions, múltiplas rotas, markers e labels, não apenas o mapa vazio. Antes de anunciar desempenho em tempo real, 60 fps ou limite de objetos suportados, produzir medição reproduzível no ambiente-alvo.

### 13.4. Exatidão cartográfica

A qualidade geográfica mínima inclui preservação de ilhas, furos, multipolígonos, desenho de fronteiras coerente, clipping em antimeridiano, comportamento de regiões sobrepostas e nenhuma região administrativa inventada. Os efeitos visuais não podem mudar a localização da feição. Resultados de busca apontam a identidade correta, mesmo com nomes ambíguos ou acentos.

### 13.5. Segurança de projeto

Os nós livres do usuário, recursos de terceiros, cenas de outras composições, dados vinculados e arquivos de projeto precisam ser protegidos contra exclusão/mutação indevida. Falhas de importação, dataset ausente, renderização de um objeto ou preset inválido devem apresentar diagnóstico e preservar o projeto. Uma ação estrutural que não possa ser concluída com segurança será bloqueada em vez de modificar silenciosamente uma composição parcialmente.

## 14. Matriz de aceitação da V1

### 14.1. Regras de execução e evidência

Cada teste registra: `test_id`, build do CartoRig, sistema operacional, versão exata do Resolve Studio, versão dos datasets, pré-condição, passos, resultado observado, resultado `PASS/FAIL/NOT RUN`, captura/projeto de evidência, defeito relacionado e responsável. Os testes de UI e render são executados no **Windows com DaVinci Resolve Studio 20**. `NOT RUN` e `FAIL` não satisfazem uma entrega estável.

Um teste só passa quando confirma **o resultado e a persistência correspondente**; um botão visível, um mock, um único screenshot ou um teste de função isolada não bastam para validar o comportamento do produto. A execução não deve modificar dados do usuário: utilizar projetos de teste descartáveis e arquivos de entrada controlados.

### 14.2. Testes funcionais obrigatórios — A01 a A20

| ID | Preparação e ação | Resultado esperado |
|---|---|---|
| **A01** | Abrir projeto Resolve sem criar Fusion Composition manualmente; executar Scene → `Create Scene` cinco vezes | Cinco clipes Fusion Composition independentes na timeline; cada um contém Scene, WorldMap e Camera físicos e UUIDs próprios, todos conectados ao MediaOut sem wiring manual; Viewer mostra mapa neutro |
| **A02** | Scene → pesquisar e adicionar `Brazil`, `Argentina`, `Mato Grosso` | Três nodes geográficos independentes, visíveis no grafo; país/estado corretos; IDs únicos e render coerente |
| **A03** | Em Scene, marcar linha do Brasil somente como alvo de `Rename` | O Inspector não muda, o node não é selecionado para edição no Fusion; a linha serve apenas para CRUD |
| **A04** | Fechar Scene; clicar diretamente em `CR_Country_Brazil_001` no Node Editor | Inspector exibe Control e Motion do Brasil; mudar Fill altera só esse node, sem abrir Scene |
| **A05** | Com Country Brasil visível, selecionar State Mato Grosso e mudar Fill/Stroke | Estado mantém bordas corretas e cor independente; Brasil, WorldMap e Argentina não são recoloridos |
| **A06** | Scene → `Add Route`, escolher nodes Brasil e Argentina, configurar duas âncoras e criar | Um node Route próprio é criado; as referências são pelos UUIDs dos países; países não são duplicados; endpoints válidos |
| **A07** | Selecionar Route no Node Editor; em Control mudar Stroke, Arrowhead, Curvature, Shadow e Glow | Só a Route muda; Viewer e render refletem cada ajuste; propriedades persistem depois do reopen |
| **A08** | Em Motion da Route, aplicar `Draw Path`; editar Reveal em Control e Bézier em Spline | Animação usa canais reais e produz avanço correto da linha; busca aleatória de frames equivale à reprodução normal |
| **A09** | Selecionar Camera no Node Editor; Motion → `Fly To` Brasil → Argentina | Câmera anima o enquadramento; Countries, State, Marker, Label e Route permanecem geoancorados sem drift |
| **A10** | Aplicar em Regions `Fade In`, `Highlight` e `Reveal`, em instâncias separadas | Cada efeito corresponde ao contrato de canais; parâmetros permanecem editáveis; Fill base não é destruído |
| **A11** | Criar Marker por ponto e Label com texto `São Paulo`; aplicar Pop In e Fade In | Nodes distintos, texto Unicode, geoanchors corretos e animações editáveis durante zoom/pan |
| **A12** | Aplicar e atualizar Motion; editar keyframes manualmente | Não há proliferação de keyframes/nodes; estado `Customized` é identificado e alterações protegidas |
| **A13** | Duplicar Country e Route; renomear país referenciado | UUIDs/canais independentes; Route preserva links corretos; renomeação não quebra a relação |
| **A14** | Excluir país usado por Route; escolher `Keep Route and Freeze Anchor`; repetir com `Cancel` | Na primeira operação, país é removido e Route permanece com coordenada; em Cancel, tudo permanece intacto |
| **A15** | Salvar, fechar Resolve, reabrir e renderizar com Scene fechado | Nodes, propriedades, fontes, câmera, rotas, fontes tipográficas, links e curvas mantêm estado e render esperado |
| **A16** | Com internet bloqueada, buscar `Brasil`, `São Paulo`, `Sao Paulo`, `Rio de Janeiro`, `Georgia` | Busca por aliases e desambiguação conforme dados instalados; nenhuma dependência de internet/conta/terminal |
| **A17** | Sobrepor WorldMap com fundo transparente, Regions e Route sobre MediaIn em HD/QHD/4K | Alpha, composição de cor, efeitos e geometria correspondem no Viewer e Deliver; não há opacidade de fundo inesperada |
| **A18** | Misturar nodes CartoRig e nodes livres; executar CRUD, reorder e delete seguros | Nodes externos preservados; operações não reconectam/deletam recursos de terceiros sem autorização |
| **A19** | Selecionar outra Fusion Composition CartoRig na timeline e abrir Scene | A lista da cena selecionada carrega automaticamente; nenhuma operação altera outra composição; não existe comando `Open Scene` |
| **A20** | Instalar no Windows Studio 20; abrir CartoRig na página Edit sem comp preparada; Create Scene e renderizar | Entrada Utility única; o clipe Fusion Composition, os nodes e o MediaOut são criados/conectados automaticamente, sem Python, SDK, terminal ou rede |

### 14.3. Testes complementares obrigatórios — B01 a B20

| ID | Preparação e ação | Resultado esperado |
|---|---|---|
| **B01** | Criar duas instâncias de `Country Brazil` na mesma cena | Dois nodes com UUIDs, nomeações, estilos e animações independentes |
| **B02** | Fechar Scene, alternar seleção direta entre Country, Route e Camera no Node Editor | Inspector contextual muda para o tipo correto; nenhum parâmetro de outro node fica acessível por engano |
| **B03** | Em Scene, selecionar linha para `Duplicate`, `Delete` ou `Reorder` sem executar a ação | Não dispara seleção no Node Editor, nem abre Control/Motion; apenas identifica alvo CRUD |
| **B04** | Aplicar override em State e Country; mudar Land no WorldMap; executar Reset Property | Overrides são preservados; Reset atinge somente a propriedade do objeto designado |
| **B05** | Alterar ordem de desenho de dois nodes de região/rota em Scene | Render muda a ordem efetiva; geometrias, UUIDs, anchors e animações não mudam |
| **B06** | Tentar excluir WorldMap e Camera individualmente | Interface bloqueia, explica dependência estrutural e mantém cena íntegra |
| **B07** | Iniciar Route com Country como endpoint e omitir seleção de âncora | `Create Route` fica indisponível; nenhuma capital/centroide é escolhida silenciosamente |
| **B08** | Criar Route vinculada a Marker; mover a latitude/longitude do Marker em Control | Endpoint vinculado acompanha a coordenada efetiva do Marker; Route mantém identidade e outros objetos não mudam |
| **B09** | Duplicar Route, editar espessura e curva da cópia; excluir a original | Cópia mantém geometria e referências, mas preserva estilo/keyframes próprios |
| **B10** | Excluir objeto referenciado, escolher `Cancel` | Não altera node, âncora, links, keyframes, ordem nem arquivos |
| **B11** | Excluir objeto referenciado por Route/Label ou alvo de Camera Fly To; escolher congelamento permitido | Consumidores e canais são mantidos, referências removidas, última coordenada/pose preservada e estado de vínculo diagnosticável |
| **B12** | Reaplicar o mesmo preset no mesmo canal e executar `Update` | Identificador da aplicação é reutilizado, sem multiplicar keyframes, ferramentas ou modificadores |
| **B13** | Aplicar preset em canal previamente animado manualmente; escolher `Cancel` | Animação original permanece byte/semanticamente íntegra; alteração cancelada não cria resíduos |
| **B14** | Modificar keyframes de preset, remover com `Keep Animation` | Keyframes permanecem editáveis no Fusion e deixam de estar gerenciados pelo preset |
| **B15** | Modificar keyframes de preset, remover com `Remove Animation` | Somente os canais pertencentes à aplicação são removidos; estilo estático e demais presets são preservados |
| **B16** | Criar Route e Fly To que cruzam ±180° longitude | Sem segmentos transglobais errados, saltos artificiais, deslocamento de âncoras ou duplicação de feições |
| **B17** | Criar Labels `São Paulo`, `Amapá`, `Brasília` com fonte instalada e simular ausência posterior | Unicode renderiza corretamente; fallback tipográfico explícito mantém texto legível |
| **B18** | Remover/alterar versão de dataset usado por projeto salvo | Diagnóstico de fonte/versão incompatível; sem polígono inventado, troca silenciosa ou rede obrigatória |
| **B19** | Interromper criação/exclusão por falha de integração e reabrir projeto | Operação é revertida ou recuperável; não deixa nodes/cartografia parcialmente inválidos nem afeta recursos livres |
| **B20** | Duplicar composição completa com Route e animações, editar a cópia | Todos os IDs internos são distintos; ligações da cópia apontam somente para sua cena e original não muda |

### 14.4. Cenários de integração e carga

Executar a matriz nas três resoluções definidas, com FPS de projeto diferentes e playback normal, seek aleatório, avanço quadro a quadro e exportação final. Medir primeira renderização, cache aquecido, alterações de Fill, Shadow/Glow, geometria de Route, Fly To e seleção do Inspector. Testar ao menos uma cena com **25 Regions, 10 Routes, 20 Markers e 10 Labels** para identificar crescimento de memória, latência e proliferação de nodes; registrar dados e eventuais limites reais sem alegações de performance não mensurada.

A equipe deve registrar testes separados para estados de erro, Undo/Redo ou recuperação, rede bloqueada, reinstalação/atualização, arquivo de dataset ausente, compositing sobre footage, cópia de composição, mudança de FPS e alteração manual de conexões. Mudanças de interface devem ser verificadas com escalonamento do Windows e Inspector redimensionado.

### 14.5. Aceite funcional por característica

Uma característica está concluída somente quando: possui controle funcional na superfície correta; altera o node e o Viewer como definido; valida entrada e estados de erro; preserva save/reopen; respeita nodes externos; produz render consistente; conta com teste reproduzível no host; e tem documentação de uso e dependências. Uma demonstração isolada de UI ou renderizador não atende ao conjunto.

## 15. Escopo da versão 1.0 e organização de implementação

### 15.1. Obrigatório na versão estável

- Scene UI Manager funcional com ciclo de vida da cena, busca offline, CRUD, ordem visual e criação de Route a partir de nodes existentes.
- Nove tipos autorais: Scene, WorldMap, Camera, Continent, Country, State, Route, Marker e Label, com nodes reais e conexão automática.
- Control completo por tipo conforme seção 5, incluindo Shadow e Glow nos objetos visuais aplicáveis.
- Motion com as 12 entradas definidas e canais editáveis; ausência de timeline paralela.
- Geografia Natural Earth offline versionada; pesquisa natural, aliases, desambiguação e limites verdadeiros de cobertura.
- Georreferenciamento, projeção 2D, Camera compartilhada, Route Geodesic/Curved, âncoras e política de dependências.
- Persistência, duplicação, migração segura, rollback, coexistência com nodes livres, alpha e render nativo.
- Instalação por GUI no Windows, código-fonte, documentação, licenciamento e testes da seção 14.

### 15.2. Fora do escopo da versão 1.0

`Group` e `DataLayer` como nodes; importação GeoJSON/CSV/TSV e coropléticos orientados a dados; globo 3D, pitch, terreno volumétrico e extrusão; mapas online/tile servers, busca de endereço e roteamento viário; municípios poligonais universais; waypoints/handles espaciais livres; várias câmeras na mesma cena; click-picking obrigatório de país no Viewer; marcador percorrendo Route; colisão automática de Labels; editor temporal/curvas próprio do CartoRig; bibliotecas de animações não enumeradas; escalas de Natural Earth adicionais como seletor obrigatório.

Opções fora do escopo não aparecem como botões ativos, nem são simuladas por comportamento não relacionado. Expansões podem receber contratos próprios depois da entrega da V1.

### 15.3. Marcos de engenharia

| Marco | Implementação vertical | Saída de aceite |
|---|---|---|
| **A — Núcleo** | Scene, WorldMap, Camera, Country/State, NodeFactory, Inspector, render, persistência, catálogo offline | Criar cena, adicionar Brasil, selecionar node diretamente e alterar Fill; save/reopen sem UI Manager |
| **B — Geografia e vínculos** | Continent, Route, anchors, dependências, reorder, duplicação e exclusão | Rota Brasil→Argentina; referências estáveis; política Keep/Freeze; geometria correta |
| **C — Aparência e objetos** | Marker, Label, Shadow/Glow, estilos, alpha e controles por tipo | Independência visual, Unicode, composição sobre footage e 4K |
| **D — Motion e distribuição** | 12 presets, conflitos, Customized, Spline, instalador, guias e regressão | A01–A20/B01–B20 e pacote instalável, com resultados registrados |

Cada marco implementa funcionalidades de ponta a ponta (UI/CRUD quando aplicável → node real → Control/Motion → Viewer → persistência → render). Concluir somente a interface ou somente o motor gráfico não conclui o marco correspondente.

## 16. Instalação, licenças, documentação e entrega

### 16.1. Plataforma e experiência de instalação

A distribuição inicial oferece instalador/desinstalador gráfico para **Windows, DaVinci Resolve Studio 20**. O usuário não instala manualmente Python do sistema, SDK, compilador, CMake nem ZIP de dados. O pacote instala interfaces, nodes, adaptador do host, renderer, recursos de ícones/efeitos, presets, dados Natural Earth, índices e documentação. A instalação deve funcionar sem conta ou conexão de internet para os recursos incluídos.

O instalador detecta incompatibilidade de host/arquitetura antes de modificar o sistema e evita sobreescrever configurações de outros plugins. Uma atualização preserva projetos e recursos de usuário; a desinstalação não apaga arquivos `.drp`/composições do usuário e documenta dependências que deixam de estar disponíveis.

### 16.2. Licenciamento

O **código próprio do CartoRig** será disponibilizado sob licença **MIT**, com uso gratuito pessoal e comercial. Dependências, componentes do Fusion e geodados Natural Earth mantêm seus avisos e condições de terceiros. O pacote inclui `LICENSE` e `THIRD_PARTY_NOTICES` e deve conferir a compatibilidade de redistribuição dos artefatos realmente incluídos. O código-fonte próprio, scripts e instruções de compilação são disponibilizados de forma reproduzível.

### 16.3. Entregáveis obrigatórios

| Artefato | Conteúdo requerido |
|---|---|
| Instalador GUI | Todos os binários/scripts, interfaces, nodes, dados e índices necessários à V1 |
| Desinstalador/atualização | Remoção segura, upgrade e recuperação de versões suportadas |
| `VERSION` / release manifest | Versão CartoRig, componentes e plataforma-alvo |
| Manifesto Natural Earth | Conjuntos, versões, escala, hashes, geometria, cobertura e atribuições |
| `LICENSE` e `THIRD_PARTY_NOTICES` | Licenciamento de código próprio e avisos reais de terceiros |
| Código-fonte e build | Repositório, dependências fixadas, tags e passos reproduzíveis para mantenedores |
| Manual de instalação/uso | Guia desde Create Scene até render, sem exigir conhecimento GIS |
| Manual técnico | Componentes, fluxos, esquema de dados, APIs adotadas, migrações, erros e manutenção |
| Exemplos editáveis | Projetos de teste independentes, nunca carregados automaticamente ao criar cena |
| Testes e evidências | Matriz A/B, relatórios do host, screenshots/vídeos, benchmarks e defeitos |
| Changelog/release notes | Alterações, requisitos de host e eventuais limitações aprovadas |

### 16.4. Fluxos que a documentação do usuário deve ensinar

O guia deve explicar concretamente `Workspace → Scripts → CartoRig → Create Scene (insere Fusion Composition e conecta MediaOut) → Add Country Brazil → Close Scene → Click CR_Country_Brazil in Node Editor → Control → Fill Color`, e `Scene → Add Brazil/Argentina → Add Route from existing nodes → Choose Anchors → Close Scene → Select Route → Control → Motion Draw Path → Fusion Spline → Deliver`.

A documentação também deve explicar como enquadrar a Camera, congelar uma âncora quando o node de referência é removido, identificar limites dos dados geográficos, resetar propriedade, remover preset personalizado, duplicar composição, usar alpha e restaurar um projeto que aponte para dataset ausente.

### 16.5. Condições de release

O pacote só pode ser divulgado como CartoRig V1 estável quando todos os tipos de nodes, controles, 12 presets, fluxos e 40 testes obrigatórios estiverem implementados e aprovados, os dados e avisos estiverem incluídos e a instalação/renderização funcionarem no ambiente-alvo. Funcionalidades incompletas precisam de correção ou de uma revisão explícita do escopo e identificação da entrega como versão diferente.

## 17. Glossário e regras finais de interpretação

| Termo | Significado neste produto |
|---|---|
| `Scene` (UI) | Janela UI Manager para operações estruturais CRUD e pesquisa para adicionar objetos |
| `Scene` (node) | Node estrutural real da composição CartoRig |
| `Node Editor` | Interface nativa do Fusion para selecionar o node que será editado |
| `Control` | Área contextual do Inspector com propriedades granulares do node selecionado |
| `Motion` | Área contextual do Inspector com presets de animação pertinentes ao tipo selecionado |
| `Object / authorial node` | Objeto adicionado/gerenciado por Scene que possui node físico próprio |
| `Location` | Item de catálogo geográfico que não cria um objeto até ação explícita |
| `Region` | Família funcional compartilhada pelos tipos Continent, Country e State |
| `Geoanchor` | Coordenada geográfica estável, projetada pela Camera no frame solicitado |
| `Route` | Node de trajetória cartográfica entre duas âncoras, sem cálculo viário |
| `Endpoint` | Âncora geográfica de uma ponta de Route, com vínculo opcional a node |
| `Preset` | Configuração reutilizável que instala canais/keyframes/modificadores refináveis no Fusion |
| `Customized` | Preset cujo canal/curva recebeu edição manual e requer proteção contra sobrescrita |
| `Style Override` | Valor definido por objeto que prevalece sobre o padrão herdado |
| `CartoRig-owned` | Recurso gerenciado por CartoRig em uma composição identificada |
| `CRUD` | Criar, ler/listar para gestão, modificar estrutura, duplicar e remover objetos/cenas |

A interpretação de cada funcionalidade deve respeitar os contratos específicos de tipo e seus testes de aceitação. **Scene não seleciona para editar; o usuário seleciona diretamente no Node Editor. Cada objeto autoral é um node real. Control personaliza; Motion aplica animações prontas; Spline/Keyframes nativos refinam curvas.** Essas fronteiras permanecem válidas para todas as telas, comandos, mensagens, exemplos e implementações internas do CartoRig V1.
