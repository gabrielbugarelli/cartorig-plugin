# Marco A — Renderização cartográfica: contratos e validação

Escopo: etapa 1 do Marco A. Esta entrega não é uma aprovação da V1 nem
substitui a observação do Viewer/MediaOut no DaVinci Resolve Studio 20.

## Referência de implementação

- **Blackmagic Design, Fusion Fuse SDK**: Shape, MoveTo/LineTo/Close,
  ImageChannel, FillStyle, OutlineOfShape e PutToImage(CM_Merge):
  https://documents.blackmagicdesign.com/UserManuals/Fusion_Fuse_SDK.pdf
- Fonte cartográfica: Natural Earth fixada em
  `f1890d9f152c896d250a77557a5751a93d494776`, com versões e
  hashes no manifesto de datasets da build.
- Base de referência: WGS84 e projeção equiretangular 2D, conforme a
  especificação do CartoRig.

## Invariantes do render implementados

1. `render_geometry.lua` implementa **uma única projeção** para WorldMap e
   Region, considerando dimensões e pixel aspect (XAspect/YAspect).
2. `project` produz coordenadas width-normalized usadas pelo Shape do Fuse.
   Em pixels físicos: `scale = min(width*XAspect/360, height*YAspect/180)`;
   `x = width/2 + lon*scale/XAspect`;
   `y = height/2 + lat*scale/YAspect`.
3. A Camera usa esse mesmo fator físico para converter Center Lat/Lon em
   offsets normalizados. O zoom e bearing continuam em seu próprio node.
4. Polígonos são recortados na descontinuidade de longitude de ±180° antes
   da criação dos contornos preenchidos.
5. Linhas de fronteira e Stroke das Regions são divididos na descontinuidade,
   **sem** transformar a borda artificial do recorte em uma linha visível.
6. A orientação original de cada anel é preservada para manter a convenção
   de anéis externos e furos da fonte. O comportamento de winding do
   rasterizador Fusion necessita confirmação visual no host real.
7. Region reutiliza geometrias somente depois de comparar `source_id`,
   `source_version` e `scale` do node com os dados. Cache de dados
   validado é limitado a oito geometrias.
8. A renderização não depende de Scene UI aberta nem do histórico de frames:
   as funções de projeção/clipping são puras e independentes de sequência.

## Testes locais (sem GitHub Actions)

Execução em infraestrutura de desenvolvimento:

```shell
texlua tests/lua/test_render_geometry.lua
texlua tests/lua/test_render_fuzz.lua
```

- `test_render_geometry`: HD (1920×1080), QHD (2560×1440), 4K
  (3840×2160), proporção 2048×858, pixel aspect não quadrado,
  projeção WGS84, corte da antimeridiana, geometria inválida,
  orientação de anéis de furos e Shape simulado.
- `test_render_fuzz`: 800 retângulos com cruzamento de ±180° em
  orientações opostas; área recortada conservada em todos os casos.

Esses testes **não** renderizam pixels Fusion: Shape, ImageChannel e
Image:Transform são funções do host e não estão disponíveis no ambiente
de testes local.

## Gate obrigatório no Resolve Studio 20 (ainda NOT RUN)

Usar somente projeto descartável e instalador do commit candidato:

1. Na página Edit abrir `cartorig-dev`, executar Create Scene sem criar
   Fusion Composition manualmente. Verificar WorldMap→Camera→Scene→MediaOut.
2. Adicionar **Brazil**, **Argentina** e **Mato Grosso** como três nodes
   independentes. Verificar que Mato Grosso está na camada State do Brasil,
   e que a fronteira da Argentina e do Brasil mantém sua forma real.
3. Com a janela Scene fechada, visualizar WorldMap, cada Region e MediaOut
   em 1920×1080, 2560×1440 e 3840×2160. Alterar Fill/Stroke da Region
   selecionada diretamente no Node Editor; cada objeto deve ser independente.
4. Em WorldMap, verificar Land/Ocean/Admin 0 borders, toggles de camada,
   opacidades e fundo transparente. Exportar e conferir alpha com MediaIn.
5. Conferir ilhas, multipolígonos e furos: bordas não devem se cruzar,
   preenchimentos não podem cobrir lagos/furos inexistentes na fonte.
6. Conferir Fiji/Rússia/Antártida ou feições da fonte que cruzem ±180°
   e verificar ausência de traços atravessando o quadro ou preenchimento
   espúrio na borda do mapa.
7. Alterar Center Latitude/Longitude, Zoom e Bearing da Camera, preservando
   a posição relativa de WorldMap/Regions e sem reescrever sua geografia.
8. Salvar, fechar e reabrir o projeto; renderizar novamente **sem** Scene
   aberta, comparar imagem e metadados e anotar versão exata do host,
   versão de dataset, commit/SHA do instalador e resultados observados.

**Condição de aprovação:** PASS no host para Viewer, MediaOut, alpha, 
geografia, projeção e save/reopen. Teste local verde ou build compilada
não mudam os testes A01/A02/A04/A05/A15 de NOT RUN.
