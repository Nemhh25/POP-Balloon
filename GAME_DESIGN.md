# POP Balloon — Game Design Document

**Status:** visão de design para a versão 1.0  
**Engine planejada:** Godot 4.x  
**Linguagem planejada:** GDScript 2.0  
**Plataforma inicial:** PC  
**Gênero:** clicker, incremental, idle leve, single-player  
**Duração-alvo da campanha:** aproximadamente duas horas na primeira conclusão

Este documento define a experiência, as regras de alto nível, o conteúdo e os limites de POP Balloon. Valores numéricos de HP, custos, DPS, recompensas, multiplicadores e tempos exatos pertencem ao futuro `BALANCE.md`. Decisões de implementação pertencem ao futuro `TECHNICAL_DESIGN.md`.

## Game Overview

POP Balloon é um clicker incremental curto em que o jogador estoura balões, recebe Coins, compra poder e avança por uma sequência de balões cada vez mais resistentes. O clique manual é a ação principal; equipamentos automáticos complementam essa ação e transformam gradualmente uma ferramenta simples em uma pequena fábrica de destruição.

A campanha tem começo, meio e fim: o jogador aprende o loop com o Red Balloon, desbloqueia seis tiers principais, enfrenta o Balloon King e recebe uma condição real de vitória. O modo Endless só aparece depois da conclusão e é opcional.

## Vision

> Começar estourando um balão simples com um clique e terminar usando uma fábrica absurda de equipamentos para destruir o rei dos balões.

A experiência deve ser curta, polida, legível e imediatamente compreensível. Cada ação importante deve produzir uma resposta clara, e cada compra deve aproximar o jogador de uma meta visível. O jogo não deve parecer uma máquina de retenção artificial: a campanha deve ser satisfatória mesmo quando o jogador decide encerrá-la ao derrotar o boss.

### Objetivos de experiência

- Fazer o primeiro pop parecer bom antes de qualquer sistema avançado.
- Entregar uma decisão ou uma pequena melhoria com frequência, principalmente no início.
- Fazer a transformação de clique manual em automação visualmente evidente.
- Manter o clique relevante sem exigir atenção incessante.
- Fazer cada tier introduzir uma mudança de leitura, resistência, recompensa ou estratégia.
- Dar ao jogador uma próxima meta compreensível até a preparação final do boss.

## Target Audience

Jogadores de PC que apreciam loops incrementais simples, feedback audiovisual, progressão curta e sensação de completar uma experiência. O jogo deve ser acolhedor para quem nunca jogou um clicker, mas oferecer pequenas decisões suficientes para manter jogadores experientes interessados durante uma sessão de até aproximadamente duas horas.

Não é projetado para competição online, otimização matemática extrema ou sessões obrigatoriamente longas.

## Platform and Session

- **Plataforma inicial:** PC, com mouse como dispositivo principal.
- **Controles:** clique e ações de interface; teclado pode oferecer atalhos de conforto, sem substituir a legibilidade da interface.
- **Sessão:** o jogo deve ser confortável tanto em sessões curtas quanto em uma sessão longa de campanha.
- **Conclusão:** a campanha principal termina com a derrota do Balloon King, e não com uma escala infinita.
- **Retorno:** o jogador pode sair e voltar sem perder a sensação de segurança do progresso; o save automático será especificado tecnicamente depois.

## Game Pillars

### 1. Satisfying Popping

Estourar é o centro da experiência. Um clique deve produzir resposta imediata: deformação breve do balão, dano legível, som curto e feedback visual. O pop deve combinar animação, partículas, movimento, número de recompensa e sensação de impacto sem transformar a tela em ruído.

### 2. Constant Progression

O jogador deve estar sempre perseguindo uma meta próxima: upgrade, equipamento, desbloqueio, novo tier, especial, marco ou boss. Metas de duração maior podem existir no late game, mas devem ser acompanhadas por progresso observável e decisões intermediárias.

### 3. Active + Idle

Clicar ativamente acelera a ação, cria combos e aproveita críticos e buffs. Equipamentos causam dano quando o jogador não está clicando, permitindo pausas e reduzindo fadiga. A automação complementa o clique; ela nunca deve comunicar que a presença do jogador deixou de ter valor.

### 4. Short and Finishable

A campanha é uma experiência completa e concluível em cerca de duas horas. Sistemas não devem existir apenas para atrasar o final. O Endless é uma recompensa opcional para quem quer continuar, não uma condição para considerar o jogo terminado.

## Core Loop

```text
BALÃO
  ↓
DANO POR CLIQUE E EQUIPAMENTO
  ↓
POP
  ↓
RECOMPENSA
  ↓
UPGRADE OU EQUIPAMENTO
  ↓
MAIOR PODER
  ↓
NOVO BALÃO / NOVO SISTEMA
  ↓
PREPARAÇÃO
  ↓
BALLOON KING
```

O jogador vê um alvo legível, clica para causar dano e observa o HP diminuir. Quando o balão estoura, recebe Coins — e, em ocasiões especiais, Diamonds ou um buff — e escolhe como converter a recompensa em poder. O próximo alvo, equipamento ou desbloqueio dá direção para a ação seguinte.

O loop permanece interessante porque cada camada muda a sensação do mesmo gesto: um clique deixa de ser apenas dano e passa a interagir com crítico, combo, buff e estado do balão. Equipamentos tornam o campo vivo mesmo durante uma pausa, enquanto desbloqueios de conteúdo dão significado à próxima meta em vez de apenas aumentar números.

## Core Mechanics

### Balloon as the focus

Um único balão de progressão ocupa o foco do campo. Ele possui HP visível, estado de dano e uma animação de reação. O jogador não precisa procurar o alvo nem interpretar uma lista abstrata de inimigos: o alvo atual é sempre claro.

### Damage and pop

Cliques e equipamentos reduzem o HP do balão. Ao chegar a zero, o balão executa uma animação de pop, concede a recompensa e a progressão escolhe ou apresenta o próximo alvo desbloqueado. O pop é uma conclusão curta e celebrada, não uma tela de carregamento entre balões.

### Rewards and choices

Coins são a recompensa recorrente e alimentam a progressão normal. Ao ganhar Coins, o jogador normalmente decide entre aumentar o poder imediato do clique, fortalecer a automação ou economizar para uma compra de progressão. O jogo pode recomendar a próxima meta, mas não deve remover a escolha.

## Balloon System

Todos os balões de campanha têm HP, recebem dano e estouram. Além desses atributos comuns, cada tier tem identidade por aparência, resistência relativa, recompensa, comportamento de feedback, efeitos e papel na jornada.

### Balloon Progression

Os nomes abaixo são a nomenclatura de trabalho da campanha. Cada tier é desbloqueado por progressão visível, não por aparição aleatória desde o início.

#### Tier 1 — Red Balloon

É o primeiro contato. Tem pouca resistência, recompensa simples e uma leitura visual amigável. Ensina o jogador a clicar, observar o HP, receber Coins e reconhecer o pop. Deve morrer rápido o bastante para o primeiro ciclo ser imediatamente satisfatório.

#### Tier 2 — Blue Balloon

É o primeiro sinal de que o poder do jogador precisa crescer. Resiste mais que o Red Balloon e recompensa melhor. Seu papel é fazer o jogador entender que um upgrade não é decoração: ele altera de forma perceptível o tempo e a sensação de cada pop.

#### Tier 3 — Green Balloon

Marca a chegada da automação como parte importante do loop. Sua resistência incentiva a combinação de clique e equipamento, mas não deve exigir que o jogador abandone a ação manual. O visual e o feedback podem sugerir energia e ritmo mais acelerado.

#### Tier 4 — Purple Balloon

Representa o midgame. O jogador já conhece upgrades, equipamentos, críticos e combo, e começa a tomar decisões de gasto. O Purple Balloon deve parecer um salto de status sem criar uma parede que só pode ser vencida esperando.

#### Tier 5 — Golden Balloon

É um balão de campanha avançado, valioso e reconhecível como resultado de progresso permanente. Tem estética rica e recompensa alta dentro da progressão normal. Não é o mesmo que o **Golden Special Balloon**: o Golden Balloon é um alvo de campanha persistente; o especial é um evento opcional, temporário e de recompensa imediata.

#### Tier 6 — Rainbow Balloon

É o endgame normal da campanha. Visualmente marcante, combina cores e intensidade para comunicar que o jogador está perto do desafio final. Exige a integração de clique, automação, críticos, combo e últimos upgrades, mas continua sendo uma versão compreensível do loop principal.

#### Final Boss — Balloon King

O Balloon King é o último alvo e não apenas um tier com números maiores. É enorme, tem apresentação própria, barra de HP especial, reações de dano e identidade visual de soberano. Sua derrota encerra a campanha.

### Balloon unlocks

Cada novo tier fica bloqueado até que o jogador alcance uma combinação apropriada de progresso: pops acumulados, avanço de estágio, poder desenvolvido e/ou uma compra de desbloqueio. O requisito deve ser exibido antes de ser alcançado, com uma indicação clara do que falta.

O jogador deve sempre conseguir responder:

- qual é o próximo balão;
- qual requisito o desbloqueia;
- quanto já foi alcançado;
- que tipo de recompensa ou desafio o novo tier representa.

O desbloqueio recebe uma apresentação curta para criar antecipação, sem interromper o fluxo com um tutorial longo.

## Player Power

O jogador começa com pouco dano e cresce através de uma linha pequena e legível de upgrades. O poder é dividido em três eixos suficientes para gerar escolhas sem virar uma árvore complexa:

- **Click Damage:** aumenta o dano básico de cada clique e é a melhoria mais direta.
- **Critical Chance:** aumenta a frequência de cliques críticos.
- **Critical Damage:** aumenta o impacto de um crítico quando ele ocorre.

Esses atributos devem ser fáceis de entender no momento da compra. Nenhum deles deve esconder a regra principal atrás de dezenas de subatributos.

## Critical Hits

Um crítico é um evento de celebração e uma ferramenta para manter o clique relevante. Ele causa dano muito maior que o clique comum, mostra um número de destaque e recebe som, flash ou animação diferenciados. A leitura deve funcionar mesmo em uma tela cheia de outros efeitos.

Críticos devem ser frequentes o bastante para serem esperados, mas especiais o bastante para continuar emocionando. Seu balanceamento deve reforçar a ação manual sem tornar equipamentos ou planejamento irrelevantes.

## Combo

O combo recompensa uma sequência de cliques ativos com um multiplicador ou bônus temporário. A progressão visual pode seguir uma escala conceitual como `x1.0`, `x1.1`, `x1.2` e assim por diante, mas os valores finais pertencem ao `BALANCE.md`.

O combo sobe quando o jogador mantém um ritmo confortável e diminui ou é perdido após uma pausa suficientemente longa. Ele deve:

- dar um motivo para clicar mesmo quando o DPS automático já é bom;
- ser visível perto do balão e não depender de leitura de um menu;
- ter uma janela generosa, de modo que não pareça um teste de velocidade ou uma obrigação;
- aceitar pausas naturais e não punir o jogador por olhar a loja;
- combinar com críticos e buffs sem criar uma rotação complexa.

O combo é um convite à atividade, não um medidor que transforma toda a sessão em manutenção cansativa.

## Automatic Equipment

Equipamentos são produtores de DPS que atacam o balão automaticamente. Cada um tem nome, silhueta, som e animação reconhecíveis. A sequência deve comunicar a transformação de uma ferramenta simples em uma linha de máquinas.

1. **Needle** — primeira ferramenta automática; introduz a ideia de dano persistente.
2. **Dart** — ferramenta melhor e mais rápida, ainda simples de compreender.
3. **Dart Launcher** — primeira máquina claramente automatizada, com presença visual maior.
4. **Pressure Gun** — equipamento intermediário de impacto, associado a pressão e cadência.
5. **Balloon Popping Machine** — máquina dedicada, capaz de fazer o campo parecer uma linha de produção.
6. **PopBot** — robô especializado, com personalidade e animação própria.
7. **Anti-Balloon Cannon** — equipamento de endgame, exagerado e deliberadamente absurdo.

Os nomes podem ser refinados durante a produção, mas a escalada deve permanecer: ferramenta simples → ferramenta melhor → máquina → tecnologia avançada → equipamento de endgame.

### Equipment progression and shop

Equipamentos são compráveis, têm níveis e aumentam seu dano automático. Seus custos crescem com o nível; o valor exato dessa curva será definido separadamente. A loja mostra claramente dano atual, próximo benefício, preço, disponibilidade e relação com o próximo desbloqueio.

Equipamentos antigos continuam úteis por pelo menos uma destas razões: níveis ainda valiosos, contribuição acumulada para o DPS, requisito de progressão ou papel complementar à estratégia. O jogador não deve sentir que uma compra anterior virou lixo instantaneamente, mas também deve haver espaço para o equipamento novo parecer uma conquista.

A loja deve favorecer decisões pequenas e frequentes: melhorar algo que já ajuda, comprar uma nova fonte de dano ou economizar para uma compra de progresso. Ela não deve exigir planilha nem apresentar dezenas de itens simultaneamente.

## Economy

### Coins

Coins são a moeda principal. Vêm principalmente de pops de balões e são usadas em click damage, críticos, equipamentos e desbloqueios normais. A moeda deve circular com frequência para que o jogador veja causa e efeito entre pop, compra e próximo pop.

### Diamonds

Diamonds são raros e não necessários para completar a campanha. Podem vir de balões especiais, conquistas, marcos importantes e eventos. São reservados para melhorias especiais ou desbloqueios interessantes, sempre comunicados como bônus e não como uma barreira.

O design funciona integralmente sem monetização. Não há microtransações, anúncios obrigatórios ou moedas adicionais planejadas. O jogador deve compreender, a qualquer momento, por que ganhou ou gastou cada moeda.

## Special Balloons

Balões especiais aparecem ocasionalmente como eventos rápidos. Eles são opcionais, visualmente distintos e não substituem o balão de progressão. Perder um especial nunca deve impedir o avanço principal.

- **Golden Special Balloon:** aparece por pouco tempo e concede uma grande recompensa em Coins ao ser estourado.
- **Crystal Balloon:** oferece uma oportunidade rara de obter Diamonds.
- **Electric Balloon:** concede temporariamente velocidade de ataque ou DPS aos equipamentos.
- **Frenzy Balloon:** ativa um breve período de bônus de clique ou facilita a construção de combo.

Os especiais devem chamar atenção por cor, movimento, som e aviso visual, gerar uma pequena urgência e sair rapidamente. A quantidade deve permanecer pequena para que cada tipo seja memorável e para que o balão normal continue sendo o centro da progressão.

## Temporary Buffs

Buffs de curta duração podem vir de especiais e eventos. Exemplos são maior Click Damage, DPS, chance de crítico, ganho de Coins ou facilidade de manter combo. Eles criam momentos de intensidade e fazem o jogador querer aproveitar uma janela de ação, mas não substituem upgrades permanentes.

Um buff deve explicar seu efeito, duração aproximada e encerramento. Buffs não devem ser obrigatórios para derrotar um tier e não devem acumular complexidade até parecerem uma segunda árvore de habilidades.

## Progression Structure

### Early Game

O jogador aprende clicar, causar dano, estourar, receber Coins e comprar o primeiro upgrade. Logo depois conhece a primeira ferramenta automática e vê o primeiro novo tier. O jogo ensina por contexto: a ação acontece antes da explicação longa.

### Early-Mid Game

Entram equipamentos mais fortes, críticos, combo e os primeiros balões especiais. A loja começa a criar escolhas entre poder imediato e próxima conquista, mas continua pequena e legível.

### Mid Game

O jogador combina Click Damage, automação e upgrades de crítico para superar balões mais resistentes. Novos equipamentos e tiers entregam saltos visuais e sonoros de poder. A progressão deve ser expressiva sem esconder o objetivo seguinte.

### Late Game

Números e efeitos ficam maiores, e equipamentos avançados passam a responder por parte significativa do DPS. O clique continua relevante por meio de críticos, combo e buffs; clicar não é obrigatório a cada segundo, mas é a melhor forma de acelerar momentos importantes.

### Endgame

Rainbow Balloons apresentam a etapa final normal. O jogador compra os últimos upgrades, desbloqueia ou melhora o equipamento final e recebe sinais claros de que o Balloon King está próximo. A antecipação é parte da recompensa.

### Final

O Balloon King reúne o poder criado durante a campanha. A luta continua usando clicar, automação, upgrades, críticos, combo e buffs já conhecidos. Ao reduzir o HP do boss a zero, a campanha é oficialmente concluída.

## Pacing

O alvo de aproximadamente duas horas será calibrado em `BALANCE.md`, mas o design deve obedecer a estas regras:

- os primeiros minutos entregam pops, compras e desbloqueios com frequência;
- a duração de uma meta aumenta gradualmente, sem criar espera vazia;
- toda parede de progressão oferece uma decisão ou melhoria perceptível;
- o jogador não precisa deixar o jogo aberto por longos períodos para avançar;
- novos sistemas são apresentados antes de se tornarem necessários;
- o endgame acelera a sensação de preparação, em vez de alongar a campanha artificialmente.

## Player Decisions

As decisões são pequenas, frequentes e reversíveis o bastante para não gerar ansiedade:

- melhorar o clique ou comprar o próximo equipamento;
- aumentar um equipamento atual ou guardar Coins para um desbloqueio;
- investir em críticos ou em dano constante;
- aproveitar um especial agora ou continuar o alvo de campanha;
- usar uma janela de buff para clicar ativamente ou deixar a automação trabalhar.

Essas escolhas devem produzir estilos momentâneos diferentes, não uma estratégia complexa com respostas únicas. O jogo pode sinalizar compras recomendadas, mas não deve jogar sozinho pelo jogador.

## Onboarding

O onboarding é contextual e começa no campo de jogo:

1. O jogador vê um Red Balloon e uma indicação curta de clicar.
2. O primeiro dano e o primeiro pop demonstram a resposta imediata.
3. A recompensa em Coins aponta para o primeiro upgrade.
4. Uma apresentação breve introduz o primeiro equipamento.
5. O próximo desbloqueio mostra qual novo balão está sendo perseguido.

Não há uma tela grande de texto antes da primeira ação. Conceitos são apresentados no instante em que passam a ser úteis, e cada tutorial pode ser dispensado ou concluído rapidamente sem interromper o loop.

## UI / UX Concept

A interface prioriza o balão e a leitura do próximo objetivo. Uma composição de referência é:

```text
┌────────────────────────────────────────────┐
│ Coins                         Progress     │
│ Diamonds                                   │
│                                            │
│                 BALLOON                    │
│                 HP BAR                     │
│              Combo / Buffs                 │
│                                            │
│ Click Damage              Auto DPS         │
├───────────────────┬────────────────────────┤
│ UPGRADES           │ EQUIPMENT              │
│ Click Damage       │ Needle                 │
│ Critical Chance    │ Dart                   │
│ Critical Damage    │ Machines...            │
└───────────────────┴────────────────────────┘
```

Esse mockup não é um layout obrigatório. A implementação deve garantir:

- balão central e grande;
- Coins, Diamonds e progresso fáceis de encontrar;
- HP, dano, combo e buffs legíveis sem disputar o centro;
- loja simples, com estado bloqueado, preço e benefício claros;
- próximo tier e requisito sempre visíveis;
- feedback que não cubra permanentemente controles ou HP;
- adaptação às resoluções previstas para PC.

## Game Feel

O feedback deve fazer o jogador sentir a diferença entre agir, progredir e concluir.

### Clique

Squash breve, pequeno movimento ou reação elástica, número de dano e som curto. A resposta deve acontecer no instante do clique, mesmo quando o dano é pequeno.

### Pop

Animação rápida de estouro, partículas, som satisfatório, moeda ou recompensa voando em direção à UI, número de recompensa e pequeno impacto visual. Variações de som e movimento reduzem repetição.

### Critical

Número maior, texto “CRITICAL”, som mais forte, flash ou tratamento de cor distinto e uma reação do balão mais intensa. O efeito deve ser reconhecível sem ser agressivo.

### Compra

Som e microanimação confirmam a compra, os valores mudam imediatamente e o novo poder é perceptível no próximo dano. A loja não deve apenas trocar um número silenciosamente.

### Unlock

Uma apresentação curta destaca o novo balão ou equipamento, mostra seu papel e devolve o controle rapidamente ao jogador. Unlocks importantes podem alterar fundo, paleta ou intensidade musical por um instante.

O conjunto deve manter hierarquia visual: o pop normal é frequente, críticos e especiais chamam mais atenção, e boss/vitória são os picos. Excesso de flashes, números e partículas deve ser evitado.

## Art Direction

A direção visual é colorida, limpa e viável para um desenvolvedor solo ou equipe indie pequena:

- formas simples e silhuetas reconhecíveis;
- cores fortes com bom contraste;
- balões expressivos, com diferenças claras por tier;
- animações curtas reutilizáveis com variações de escala, cor e partículas;
- interface limpa, com tipografia legível;
- efeitos suficientes para game feel sem exigir centenas de sprites.

Red, Blue, Green, Purple, Golden e Rainbow devem ser identificados à primeira vista. O Balloon King usa escala, coroa, ornamentos e composição para parecer um personagem de encerramento, não apenas um balão colorido maior.

## Audio Direction

O áudio é leve, alegre e com energia suficiente para uma sessão longa. Pops usam várias variações curtas para evitar repetição; volumes e densidade devem permitir que o jogador ouça feedback importante sem fadiga.

Eventos com assinatura própria:

- clique;
- pop;
- crítico;
- compra;
- unlock;
- balão especial;
- entrada e fases do boss;
- vitória.

Uma trilha, caso presente, deve ter camadas ou variações suaves e não competir com os efeitos. O silêncio ou redução de intensidade em momentos importantes pode ser tão útil quanto adicionar sons.

## Achievements

O jogo possui um conjunto pequeno de conquistas que registra momentos de compreensão e progresso, sem virar uma lista de tarefas paralela. Exemplos:

- estourar o primeiro balão;
- alcançar um marco de pops;
- comprar o primeiro equipamento;
- realizar o primeiro crítico;
- encontrar o primeiro balão especial;
- desbloquear um tier importante;
- derrotar o Balloon King.

Algumas conquistas podem oferecer pequenas recompensas, mas nenhuma deve ser necessária para completar a campanha. O texto da conquista deve dizer o que aconteceu e por que aquilo importa.

## Statistics

O jogo acompanha estatísticas simples, úteis tanto para feedback quanto para a tela final:

- total de cliques;
- balões estourados;
- Coins obtidas;
- Diamonds obtidos;
- dano total;
- maior crítico;
- tempo jogado;
- balões especiais estourados;
- equipamentos comprados ou evoluídos.

As estatísticas são informativas, não uma obrigação de maximização. O jogador deve conseguir consultá-las sem sair do fluxo principal.

## Boss — Balloon King

O Balloon King tem uma introdução própria, é muito maior que um balão normal e aparece com uma barra de HP especial. A arena, paleta, música e efeitos devem comunicar que a campanha chegou ao seu teste final.

A luta permanece fiel ao loop conhecido:

- cliques causam dano e podem gerar críticos;
- equipamentos causam DPS contínuo;
- combo e buffs recompensam períodos de atividade;
- upgrades comprados antes ou durante as oportunidades permitidas mudam o poder percebido.

Para dar ritmo sem criar outro gênero, o boss pode mudar de expressão, cor, pose ou intensidade em alguns limiares de HP. Pode haver uma breve janela visual de buff, reação mais forte a críticos e aumento de música/partículas próximo do fim. Não haverá plataforma, esquiva, ataques de ação ou uma árvore de habilidades exclusiva do boss.

O Balloon King deve parecer resistente e importante, mas não uma parede baseada em espera. A vitória deve resultar do poder acumulado e das decisões do jogador ao longo da campanha.

## Victory

Quando o boss chega a zero HP:

1. ocorre uma sequência de pop especial e legível;
2. o jogador recebe uma celebração visual e sonora;
3. a interface declara explicitamente que a campanha foi concluída;
4. estatísticas da partida são apresentadas;
5. créditos são disponibilizados;
6. uma opção de continuar desbloqueia o Endless.

A mensagem precisa transmitir sem ambiguidade: **“Você zerou POP Balloon.”** A tela final pode exibir tempo total, balões estourados, total de cliques, maior crítico, Coins obtidas, equipamentos comprados e especiais encontrados.

## Endless Mode

Após a vitória, o jogador pode continuar em um modo Endless opcional. Ele pode escalar HP, DPS e recordes indefinidamente e permitir a continuidade das compras, mas não é parte da duração principal nem condição para qualquer conquista de campanha.

Não haverá Prestige inicialmente. O Endless deve ser apresentado como espaço para brincar com números maiores e testar limites, sem redefinir o objetivo original de finalizar o jogo.

## Save Experience

O save automático futuro deve fazer o progresso parecer seguro: sair e voltar retoma a campanha, compras e desbloqueios sem exigir uma rotina manual. Este documento define apenas a expectativa da experiência; formato, armazenamento, migração e validação pertencem ao `TECHNICAL_DESIGN.md`.

## Version 1.0 Scope

A versão 1.0 de escopo controlado contém:

- seis tiers principais de balões: Red, Blue, Green, Purple, Golden e Rainbow;
- um boss final: Balloon King;
- poucos tipos de balões especiais;
- aproximadamente sete equipamentos automáticos;
- três upgrades principais de clique: dano, chance crítica e dano crítico;
- combo;
- críticos;
- Coins e Diamonds;
- desbloqueios de tiers;
- conquistas pequenas;
- estatísticas;
- expectativa de save automático;
- tela final com créditos e resumo;
- Endless Mode pós-game.

O conteúdo deve ser polido e reutilizar estruturas de feedback quando isso não reduzir a identidade de cada tier. A campanha não precisa de dezenas de itens para parecer completa.

## Out of Scope

Não fazem parte da versão inicial:

- multiplayer, co-op ou PvP;
- personagens jogáveis ou classes;
- crafting;
- inventário complexo;
- skill tree extensa;
- Prestige ou reset de campanha;
- microtransações, battle pass ou anúncios obrigatórios;
- rankings multiplayer, contas online ou cloud backend;
- dezenas de moedas, equipamentos ou sistemas paralelos;
- narrativa extensa, diálogos longos ou cutscenes cinematográficas;
- action combat, esquiva, movimentação livre ou fases de plataforma;
- conteúdo procedural necessário para preencher a campanha;
- cloud save sem uma solicitação futura explícita.

Ideias fora do escopo podem ser registradas como possibilidades futuras, mas não devem alterar a campanha atual sem revisão do objetivo de uma experiência curta e finalizável.

## Design Risks

### Clicking becomes irrelevant

Automação pode vencer tudo sozinha e transformar o jogador em espectador. Combo, críticos, buffs e decisões de compra devem tornar o clique uma forma valiosa de acelerar e celebrar a ação, sem exigir atenção constante.

### Repetition

O loop é deliberadamente repetitivo. Desbloqueios de tiers, silhuetas, efeitos, equipamentos, especiais, metas e variações de feedback devem renovar a leitura sem esconder que o jogo continua sendo sobre estourar balões.

### Economy walls

Se uma meta exigir apenas esperar, o ritmo quebra. Cada trecho deve oferecer uma melhoria, uma compra, um especial ou uma decisão, e o balanceamento posterior deve evitar grind artificial e idle prolongado obrigatório.

### Too much complexity

Críticos, combo, duas moedas, especiais e equipamentos já são suficientes para uma primeira versão. Novas regras só entram se melhorarem diretamente o loop e puderem ser explicadas no momento em que aparecem.

### Two-hour target

Uma economia rápida demais ignora sistemas; uma lenta demais transforma a campanha em espera. O `BALANCE.md` deve testar a duração por estágio, tempo de decisão e frequência de desbloqueios, preservando sempre um começo, meio e fim claros.

### Feedback overload

Se todo clique gerar o máximo de partículas e sons, nada parece especial. A direção de game feel deve reservar os maiores tratamentos para críticos, especiais, unlocks, boss e vitória.

### Weak final payoff

Se o boss parecer apenas mais um balão, a campanha perde sentido. Sua apresentação, escala, feedback, estatísticas e tela de conclusão devem confirmar que o jogador atravessou uma jornada completa.

## Player Experience Target

Ao terminar, o jogador deve sentir a transformação:

```text
PEQUENO
  ↓
MAIS FORTE
  ↓
AUTOMAÇÃO
  ↓
MÁQUINAS
  ↓
NÚMEROS GRANDES
  ↓
CAOS CONTROLADO
  ↓
BALLOON KING
```

O jogador deve conseguir explicar o jogo em uma frase, lembrar pelo menos um equipamento ou pop marcante e compreender por que a próxima compra importava. A conclusão deve soar como uma vitória, não como o ponto em que a progressão finalmente começaria.

## Definition of Done for the Game Design

Este documento estará cumprido quando outro desenvolvedor conseguir responder, sem consultar o briefing original:

- o que é POP Balloon e qual é sua plataforma;
- qual é o objetivo do jogador;
- como funciona o loop de balão, dano, pop e recompensa;
- como clique, críticos, combo e equipamentos se relacionam;
- como Coins, Diamonds, especiais e buffs apoiam a progressão;
- quais tiers existem e como levam ao Balloon King;
- como a vitória e o Endless funcionam como experiência;
- que tipo de UI, feedback, arte e áudio a experiência requer;
- que conteúdo pertence à versão 1.0;
- o que explicitamente não deve ser implementado.

O documento é intencionalmente agnóstico de implementação: não define scripts, scenes, Resources, Autoloads, estrutura de nós ou APIs da Godot. Ele fornece direção suficiente para que o próximo design de balanceamento e o design técnico possam ser criados sem inventar o objetivo do jogo.
