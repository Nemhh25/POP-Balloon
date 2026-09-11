# Milestone 7 — UI/UX e visual

## Escopo e auditoria

Redesign de apresentação sobre o loop existente de alvo único. Não altera fórmulas, custos reais, dano, requisitos de reveal, chance de drops, progressão ou formato do save. O baseline desta etapa já continha mudanças de gameplay não commitadas, que foram preservadas.

A interface anterior distribuía listas extensas pela parte inferior, competindo com o balão e aumentando o tamanho mínimo do HUD. Custos e efeitos tinham a mesma hierarquia, enquanto feedbacks e a tela de vitória podiam se misturar ao jogo.

## Direção visual e layout

- Fundo azul-noite com iluminação circular discreta e pontos desenhados pela engine; sem assets externos.
- Texto claro `#edf4ff`, secundário `#acbbd3`, ação/progresso mint `#73e4bd`, Coins dourado `#ffcf6a` e Diamonds violeta `#a8abff`.
- Cabeçalho compacto com título e moedas. Área esquerda dedicada ao balão, HP local, combate, combo/buff e opção Hold ON/OFF. Objetivo e requisitos ficam abaixo, sem sobreposição.
- Loja lateral com abas Upgrades, Equipment e Global. Cada aba tem rolagem vertical independente, sem aumentar a altura do jogo.
- Containers distribuem espaço; base lógica 1280×720, stretch canvas_items/expand preservado. Validado também em janela 1100×650 e fullscreen 1920×1080. Retrato/mobile não são alvos desta entrega.
- Vitória opaca e centralizada, com estatísticas compactas e botão de Endless; HUD e efeitos ocultos.

## Componentes e dados

`pop_theme.gd` centraliza estilos, cores, estados de botões e barras. `upgrade_card.gd` apresenta título, nível, efeito, próximo milestone quando aplicável, custo e estado NEW. O Button original é reaproveitado para preservar suas conexões de compra. Visibilidade dos cards e abas segue os reveals existentes: conteúdo HIDDEN não ocupa espaço.

`number_format.gd` formata K/M/B/T e frações sem modificar valores internos. `play_background.gd` redesenha apenas quando necessário. O balão mantém sua lógica e recebe somente ajustes de tamanho, HP e tween visual.

O HUD consulta serviços e reage a sinais; não calcula uma nova economia. As barras de requisito usam contadores reais de pops, Coins e equipamento. Buff Frequency mostra o contador existente; countdown de buff é atualizado por um timer visual central de 1 segundo.

Feedback tem no máximo uma instância ativa por categoria (dano normal, crítico, pop, Coins, Diamonds), substituída com cancelamento do tween anterior. Dano normal é limitado visualmente a uma atualização por 180 ms; críticos têm destaque imediato. Isso não limita nem agrega dano real.

## UI Polish Pass — microinterações

O layout anterior foi preservado. Alterações exclusivamente de apresentação:

- Balloon: corpo 12% maior, hover com cursor e highlight, squash/recoil em 0,19 s, entrada em 0,18 s e burst/fade de pop em 0,10 s. A transformação é só do desenho, sem mover HP ou alterar o hitbox durante o tween. O clique continua disponível durante a entrada. O anel de specials foi ajustado para não encostar no HP.
- HP: número e barra principal imediatos; barra secundária dourada acompanha em 0,18 s. Últimos 20% recebem accent mais quente. Nenhum valor lógico é interpolado.
- Floating feedback: áreas separadas à esquerda/direita do balão para dano normal/crítico, recompensas abaixo e pop no centro. Variação controlada de posição usa RNG visual próprio. Crítico tem título, tamanho e punch; Diamond tem glifo, punch e duração de 0,8 s. Demais textos duram 0,55 s.
- Combo: crescimento, queda e teto atual têm tratamentos distintos. O indicador MAX consulta o cap existente; não cria novos marcos. Hold ON/OFF ganha cor e resposta curta. Buff inicia com bump, mostra countdown e encerra com fade.
- Cards: bordas indicam disponibilidade, custo insuficiente permanece legível e `✓ MAX` comunica conclusão. Mudança de nível produz flash/bump, sem disparar por tentativa de compra recusada. Milestones consultam os níveis/multiplicadores do equipamento e exibem badge temporário.
- NEW: cards recém-visíveis entram com highlight/fade; aba fechada recebe indicador até ser visitada. Badge do card é reconhecido ao passar o mouse ou focar seu botão. Não há novos dados de save para notificações.
- Progressão: identidade de cor do próximo tier, requisitos completos com check e cor, unlock com bump único quando passa a estar disponível. Aba selecionada recebe borda inferior e troca de conteúdo usa fade de 0,14 s.
- Moedas: valor exato atualiza por evento; bump de ganho/gasto tem limite de uma vez a cada 250 ms por contador. Efeitos flutuantes substituem os anteriores da mesma categoria — não somam recompensas fictícias.

### Garantias e testes do polish

`tests/ui_polish_validation.gd` usa save isolado, input de mouse encaminhado ao viewport para clique/hover, compra e toggle, e fixtures controladas para crítico, combo e milestone. Foram verificados NEW, aba, requisitos, unlock, buff, MAX, falta de Coins, save/load e 80 pops rápidos (com dano fatal sintético), com limite de cinco feedbacks ativos e sem crescimento de balões/tweens. A renderização de Auto DPS alto também usa a suíte visual existente. Resultados: `UI_POLISH_RESULTS: []`, `VISUAL_LAYOUT_RESULTS: []` e `SAVE_VALIDATION_PASSED`.

As capturas `polish_*.png` registram os estados intermediários. Houve inspeção visual e segunda rodada de ajustes em badges, aba ativa e espaço do anel especial. A suíte de layout cobre base, janela menor, fullscreen, boss e vitória. Não houve alterações em scenes/layout, fórmulas, dados, saves ou áudio neste pass; os hashes de dados e serviços de gameplay foram comparados antes/depois.

Limitação preexistente confirmada: Hold to Click é transitório e volta a OFF ao reabrir o jogo. Esse comportamento foi preservado. Arte continua procedural; sem partículas ou áudio novos. O teste de 80 pops não substitui profiling prolongado de uma sessão humana.

## Validação

- Godot 4.7.2: `tests/save_validation.gd` passou, incluindo bindings de compra e regressões existentes de progressão/save.
- `tests/ui_visual_validation.gd`: renderização real com nove cenários — início, Purple, Rainbow, globais, buff/rolagem, janela menor, fullscreen, boss e vitória. Capturas em `tests/ui_captures/`.
- Verificação automática de limites do HUD e ausência de sobreposição entre balão, loja e ação de progressão. Inspeção das capturas levou à redução de margens, limite de feedback, limpeza da vitória e remoção das ações de navegação/desafio durante o boss.
- Testes usam arquivo de save isolado; não usam nem sobrescrevem o progresso pessoal. Hashes de `data/`, `scripts/game/`, `scripts/services/` e `autoload/` permaneceram iguais ao início desta etapa.
- Execução headless apresenta aviso do ambiente Windows sobre leitura de certificados; a suíte termina com `SAVE_VALIDATION_PASSED`.

## Limitações e pendências separadas

Coins e Diamonds no HUD usam ícones SVG próprios; balões e fundo continuam desenhados pela engine. Não foram criadas trilha, sistema de localização ou menu principal. Textos mantêm o inglês atual. A responsividade validada é desktop/paisagem.

Achados de gameplay/documentação anteriores, fora do escopo e sem correção nesta etapa:

- Reveal de Golden Special usa tier 1, apesar da intenção histórica de começar no Blue.
- Buff Frequency ainda precisa de auditoria funcional da aplicação ao scheduler e da contagem de cliques; a UI só apresenta o estado existente.
- O teto calculado de Critical Chance pode chegar a 35,1%, divergindo de referências a 35%.
- Existem descrições históricas de curvas e milestones que não correspondem às fórmulas atuais. Não foram usados esses textos como autorização para rebalancear.

As capturas são fixtures de teste, não evidência de duração de campanha ou balanceamento. Um playtest humano completo continua necessário para avaliar conforto e pacing.

## Cartoon UI Art Direction Pass

### Auditoria e direção

A estrutura anterior foi preservada: cabeçalho, alvo principal, progressão e loja lateral por abas. A referência enviada orientou somente a linguagem gráfica — contornos fortes, preenchimentos vivos e componentes com aparência física. Nenhum cenário, asset ou composição da referência foi copiado. Não foi adotado um pipeline de pixel art.

### Sistema visual

- `pop_theme.gd`: placas arredondadas, outline azul-preto, sombra curta, botões cyan com estados de pressão/hover, ação de unlock dourada e tabs sólidas. FontVariation usa a fonte embutida da engine com peso reforçado; títulos recebem contorno e sombra. Não há fonte externa para licenciar.
- `upgrade_card.gd`: acabamento comum de cards, bordas de disponibilidade menos pesadas, conclusão e stickers NEW/milestone. Custos, efeitos, níveis e os botões existentes permanecem ligados aos mesmos serviços.
- `main_hud.gd`: moedas em placas compactas com ícones originais `assets/ui/coin.svg` e `diamond.svg`, títulos arcade, progressão e Endless com ação dourada. Feedbacks flutuantes reutilizam tipografia contornada. Hold, Combo, críticos, reveal e compras mantêm suas regras anteriores.
- `balloon.gd`: contorno, brilho e sombra desenhados, nó visual do balão e HP contornado. Hitbox, valores e cadência não foram alterados neste art pass.
- `play_background.gd`: raios estáticos suaves e pequenas estrelas, sem partículas permanentes nem lógica por frame. Boss e vitória recebem o mesmo tema; não foi criado menu novo.

### Validação e segunda rodada

Godot 4.7.2 executado com saves de teste separados. Inspeção de capturas de início, late game, Equipment, críticos/Diamonds, NEW/milestone, janela menor e vitória. Após a primeira inspeção, foram reduzidas a largura da rolagem e as bordas dos cards; stickers e barras foram ajustados.

Resultados finais: `VISUAL_LAYOUT_RESULTS: []` em 1280×720, 1100×650 e fullscreen 1920×1080; `UI_POLISH_RESULTS: []` para input, compras, reveal, combo/crítico, buffs, unlock, 80 pops rápidos e save/load; `SAVE_VALIDATION_PASSED` na suíte de regressão. Capturas atuais em `tests/ui_captures/`.

Limites: arte procedural e ícones vetoriais leves, sem novos sons/partículas, localização ou arte ilustrada final. Não houve rebalanceamento, novas mecânicas ou mudança da estrutura principal. O aviso de certificado no headless é do ambiente Windows; a execução visual não apresentou erros do projeto.
