# POP Balloon — Balance Document

**Status:** balanceamento-base da campanha 1.0  
**Fonte de verdade de experiência:** `GAME_DESIGN.md`  
**Duração-alvo:** jogador ativo típico conclui entre 1h45 e 2h15; alvo central de aproximadamente 2h

Este documento transforma o game design em valores, fórmulas e checkpoints reproduzíveis. Ele não define implementação, estrutura de cenas, scripts ou APIs. Os valores foram calibrados para um jogador presente, que compra melhorias de forma razoável, clica com conforto, usa equipamentos e aproveita eventos quando os vê — não para autoclicker, macro, speedrun ou jogo completamente idle.

## 1. Balance Goals

- Entregar uma compra, meta ou mudança observável com frequência.
- Manter balões comuns em uma faixa de poucos segundos de combate, nunca como mini-bosses.
- Preservar o clique como contribuição importante até o fim por meio de crítico, combo e buffs.
- Fazer a automação crescer de apoio inicial para principal fonte de dano, sem transformar o jogador em espectador.
- Permitir uma campanha completa sem depender de Diamonds ou de capturar balões especiais.
- Manter a escala final em milhões baixos/dezenas de milhões, e não em números incompreensíveis.

## 2. Target Completion Time

| Fase | Janela acumulada | Foco de progressão |
|---|---:|---|
| Red Balloon | 0–10 min | Aprender o pop, primeiro Click Damage e Needle |
| Blue Balloon | 10–25 min | Dart e primeiro crítico |
| Green Balloon | 25–45 min | Dart Launcher, combo e automação relevante |
| Purple Balloon | 45–70 min | Pressure Gun e decisões de gasto |
| Golden Balloon | 70–95 min | Balloon Popping Machine e economia em milhões |
| Rainbow Balloon | 95–110 min | PopBot, últimos críticos e desbloqueio do boss |
| Preparação final | 110–115 min | Anti-Balloon Cannon e compras finais |
| Balloon King | 115–120 min | Luta de aproximadamente 3 min e 20 s |

Essas janelas são metas de teste, não cronômetros obrigatórios. Jogadores mais eficientes podem terminar antes; jogadores que exploram menos ou clicam com menor frequência podem terminar depois.

## 3. Player Model and Core Assumptions

### Modelo ativo usado nos cálculos

| Parâmetro | Valor de modelagem | Regra |
|---|---:|---|
| Cliques ativos | 4 por segundo | Faixa humana confortável esperada: 3–5 CPS |
| Combo médio | 1.20–1.35x | Depende do estágio e de períodos ativos |
| Eventos especiais | 1 a cada 3 min em média | Não são necessários para cumprir metas principais |
| Especial durante boss | Desativado | O boss é balanceado pelo poder permanente já obtido |
| Diamonds | Opcionais | Nenhum desbloqueio de campanha os exige |

### Fórmulas de referência

```text
Expected Manual DPS = Click Damage × 4 CPS × Expected Critical Factor × Expected Combo

Expected Critical Factor = 1 + Critical Chance × (Critical Multiplier - 1)

Expected Total DPS = Expected Manual DPS + Auto DPS

Expected TTK = Balloon HP / Expected Total DPS

Expected Income/min = Expected Pops/min × Coins per Pop
```

Os TTKs da tabela usam o poder esperado ao entrar no tier. Durante cada fase, compras reduzem esse tempo; o ritmo de pop também inclui pequenas pausas naturais de compra e leitura da interface.

## 4. Balloon Stats and Progression

### Variação dentro de um tier

Balões comuns usam uma sequência previsível de HP, em vez de aleatoriedade pura:

```text
95% → 98% → 100% → 102% → 105% do HP base → repetir
```

Coins por pop não variam. A variação é pequena, legível e evita que a rotina pareça mecânica sem introduzir picos aleatórios de dificuldade. O Balloon King não usa variação.

| Balão | HP base | Coins/pop | Diamonds | Pops esperados na fase | Desbloqueio | Requisito | Poder total esperado na entrada | TTK de entrada |
|---|---:|---:|---:|---|---|---|---:|---:|
| Red Balloon | 12 | 5 | — | 300 | Inicial | — | 4 DPS | 3.0 s no primeiro pop; cai rapidamente |
| Blue Balloon | 160 | 45 | — | 210 | ~10 min | 220 Red pops + 300 Coins | 31 DPS | 5.1 s |
| Green Balloon | 700 | 400 | — | 200 | ~25 min | 180 Blue pops + 2,000 Coins | 117 DPS | 6.0 s |
| Purple Balloon | 2,800 | 2,000 | — | 200 | ~45 min | 170 Green pops + 15,000 Coins | 438 DPS | 6.4 s |
| Golden Balloon | 12,000 | 12,000 | — | 175 | ~70 min | 160 Purple pops + 100,000 Coins | 1,531 DPS | 7.8 s |
| Rainbow Balloon | 30,000 | 90,000 | — | 105 | ~95 min | 130 Golden pops + 600,000 Coins | 5,284 DPS | 5.7 s |
| Balloon King | 4,200,000 | 1,000,000* | — | 1 | ~115 min | 80 Rainbow pops + 750,000 Coins + Anti-Balloon Cannon | 21,248 DPS | 197.7 s |

\* A recompensa do Balloon King é uma bonificação de vitória para Endless e não é necessária para concluir a campanha.

### Balloon unlock rules

Cada unlock combina Pops e Coins para criar uma meta visível e uma decisão de gasto. A barra de progresso mostra os dois requisitos; contar tempo não é um requisito.

- A quantidade de pops impede que uma compra isolada pule um tier cedo demais.
- A exigência de Coins pede que o jogador escolha entre investir imediatamente em poder ou guardar para progredir.
- Os requisitos ficam levemente abaixo do total típico de pops do estágio para permitir estilos de compra diferentes sem atrasar a campanha.

## 5. Click Damage

O jogador começa no **nível 1**, com **1 de dano por clique**. Há **45 níveis** na campanha principal.

```text
Click Damage(level) = round(1.155 ^ (level - 1))

Next Click Upgrade Cost(level) = round_to_nearest_5(10 × 1.24 ^ (level - 1))
```

O custo do nível indicado compra a passagem daquele nível para o próximo. `round_to_nearest_5` arredonda para o múltiplo de 5 mais próximo.

| Nível | Click Damage | Próximo custo | Coins totais gastos para chegar ao nível |
|---:|---:|---:|---:|
| 1 | 1 | 10 | 0 |
| 12 | 5 | 105 | 400 |
| 19 | 13 | 480 | 1,950 |
| 26 | 37 | 2,165 | 8,970 |
| 33 | 101 | 9,760 | 40,620 |
| 40 | 276 | 44,000 | 183,280 |
| 42 | 368 | 67,655 | 281,840 |
| 43 | 425 | 83,890 | 349,495 |
| 45 (máximo) | 567 | — | 537,410 |

A curva aumenta de forma multiplicativa moderada: os primeiros upgrades são frequentes e fáceis de perceber; os últimos exigem planejamento, mas não anulam a importância dos equipamentos.

## 6. Critical Hits

### Critical Chance

O jogador começa com 0%. Cada compra aumenta a chance em 5 pontos percentuais; o máximo de campanha é 30%, portanto nunca há crítico garantido.

| Chance após compra | Custo | Estágio esperado |
|---:|---:|---|
| 5% | 150 | Red/Blue |
| 10% | 1,200 | Blue/Green |
| 15% | 8,000 | Green/Purple |
| 20% | 55,000 | Purple/Golden |
| 25% | 350,000 | Golden/Rainbow |
| 30% (máximo) | 2,000,000 | Rainbow/preparação final |

### Critical Damage

O multiplicador inicial é **2.00x**. Há cinco upgrades, com máximo de **3.25x**.

| Multiplicador após compra | Custo | Estágio esperado |
|---:|---:|---|
| 2.25x | 300 | Blue/Green |
| 2.50x | 2,400 | Green/Purple |
| 2.75x | 16,000 | Purple/Golden |
| 3.00x | 110,000 | Golden/Rainbow |
| 3.25x (máximo) | 750,000 | Rainbow/preparação final |

O crítico melhora apenas a ação manual. O modelo de DPS usa o fator esperado, não picos de sorte, para que um jogador sem uma sequência excepcional continue no ritmo da campanha.

## 7. Combo

O combo modifica somente o dano manual, para manter o clique relevante sem inflar a economia automática.

```text
Combo stacks = floor(consecutive valid clicks / 8)
Combo multiplier = 1.00 + (0.05 × combo stacks)
Maximum = 10 stacks = 1.50x Click Damage
```

- Um clique é válido enquanto o jogador mantém uma cadência natural, sem intervalo superior a 0.75 s entre cliques.
- A 4 CPS, cada stack é ganho em cerca de 2 s; o máximo é alcançado em cerca de 20 s de atividade contínua.
- Após 1.5 s sem clique válido, o combo perde um stack por segundo até voltar a 1.00x.
- Abrir a loja não zera o combo instantaneamente; a janela inicial dá tempo para uma compra curta.
- Os multiplicadores médios usados nos checkpoints são 1.20x, 1.25x, 1.30x e 1.35x. O máximo de 1.50x recompensa uma sequência boa sem ser necessário para concluir o jogo.

## 8. Automatic Equipment

Cada compra concede um nível. Não há milestones adicionais na campanha: isso mantém a curva transparente e os equipamentos antigos naturalmente relevantes pelo custo inicial baixo e pelo DPS acumulado.

```text
Equipment DPS(level) = Base DPS × level

Equipment Level Cost(level) = round_to_nearest_5(Base Cost × 1.12 ^ (level - 1))
```

O custo do nível 1 é o `Base Cost`. Limites existem apenas para evitar que a campanha se concentre em um item infinito; o Endless pode receber regras próprias futuramente.

| Equipamento | Desbloqueio | Base DPS | Base cost | Máx. campanha | Papel |
|---|---|---:|---:|---:|---|
| Needle | Red, após primeiro upgrade de clique | 1 | 25 | 40 | Primeira presença automática, barata de continuar melhorando |
| Dart | Blue | 3 | 120 | 40 | Primeiro salto de automação e cadência visual |
| Dart Launcher | Green | 10 | 600 | 40 | Máquina inicial; consolida o DPS automático |
| Pressure Gun | Purple | 35 | 2,000 | 35 | Núcleo de dano do midgame |
| Balloon Popping Machine | Golden | 150 | 12,000 | 30 | Principal máquina de late game |
| PopBot | Rainbow | 600 | 55,000 | 25 | Salto tecnológico do endgame |
| Anti-Balloon Cannon | Preparação final | 2,500 | 300,000 | 15 | Compra de destaque antes do boss |

### Planned equipment levels and auto DPS

| Tempo | Needle | Dart | Launcher | Pressure Gun | Popping Machine | PopBot | Cannon | Auto DPS |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 10 min | 6 | — | — | — | — | — | — | 6 |
| 25 min | 14 | 10 | — | — | — | — | — | 44 |
| 45 min | 22 | 20 | 12 | — | — | — | — | 202 |
| 70 min | 28 | 28 | 22 | 14 | — | — | — | 822 |
| 95 min | 32 | 32 | 28 | 24 | 12 | — | — | 3,048 |
| 110 min | 35 | 35 | 32 | 30 | 20 | 8 | — | 9,310 |
| 115 min | 36 | 36 | 34 | 32 | 24 | 12 | 2 | 17,404 |

### Cost checks at planned end levels

| Equipamento | Nível planejado | Coins gastos até esse nível | Próximo custo aproximado |
|---|---:|---:|---:|
| Needle | 36 | 12,110 | 1,480 |
| Dart | 36 | 58,130 | 7,095 |
| Dart Launcher | 34 | 230,720 | 28,285 |
| Pressure Gun | 32 | 914,540 | 112,745 |
| Balloon Popping Machine | 24 | 1,417,865 | 182,145 |
| PopBot | 12 | 1,327,320 | 214,280 |
| Anti-Balloon Cannon | 2 | 636,000 | 376,320 |

Um equipamento recém-comprado deve elevar o Auto DPS atual em aproximadamente 15–25% no estágio em que chega. Se, em teste, o primeiro nível representar menos de 10% ou mais de 35% do DPS total, seu Base DPS ou Base Cost deve ser revisado.

## 9. Manual vs Auto Damage Targets

| Fase | Manual esperado | Auto esperado | Razão de design |
|---|---:|---:|---|
| Red/Blue | ~80% | ~20% | Ensinar que clicar é a fonte dominante |
| Green/Purple | ~50–55% | ~45–50% | Combinar atividade e máquinas |
| Golden/Rainbow inicial | ~35–45% | ~55–65% | Automação acelera, mas críticos e combo ainda importam |
| Balloon King | ~18% | ~82% | A fábrica sustenta a luta; o clique encurta e celebra momentos-chave |

No boss, o clique permanece importante como fonte de pico, crítico e combo, apesar de a automação responder pela maior parte do DPS sustentado.

## 10. Coins Economy

### Renda bruta por fase

| Fase | Pops típicos/min | Coins/pop | Renda bruta/min | Renda bruta aproximada da fase |
|---|---:|---:|---:|---:|
| Red | 30 | 5 | 150 | 1,500 |
| Blue | 14 | 45 | 630 | 9,450 |
| Green | 10 | 400 | 4,000 | 80,000 |
| Purple | 8 | 2,000 | 16,000 | 400,000 |
| Golden | 7 | 12,000 | 84,000 | 2,100,000 |
| Rainbow | 7 | 90,000 | 630,000 | 9,450,000 |
| **Campanha antes do boss** | — | — | — | **12,040,950** |

Essa renda é deliberadamente conservadora: ela não conta Coins extras de especiais, recompensas de conquistas ou escolhas de Diamonds. O núcleo da campanha deve funcionar sem eles.

### Principais sinks esperados

- Click Damage até o nível 43: aproximadamente 349,495 Coins.
- Critical Chance até 30%: 2,414,350 Coins.
- Critical Damage até 3.25x: 878,700 Coins.
- Equipamentos nos níveis planejados da tabela: aproximadamente 4,596,685 Coins.
- Desbloqueios de progressão: 1,467,300 Coins.

O total planejado é próximo de 9.7M Coins. A diferença para a renda bruta esperada é uma margem intencional para decisões não ideais, upgrades extras em equipamentos, compras antes/depois de um gate e variação de desempenho. Não deve ser usada para pular todo o estágio seguinte de uma vez.

### Purchase frequency targets

- **0–10 min:** nova compra ou melhoria a cada poucos segundos/dezenas de segundos; alerta se a próxima opção levar mais de 60 s.
- **10–45 min:** compras relevantes normalmente em até 90 s; alerta se houver mais de 2 min sem compra ou meta próxima.
- **45–95 min:** decisões maiores podem pedir até 2 min; alerta acima de 3 min sem ação econômica disponível.
- **95–115 min:** guardar para um upgrade grande pode levar até 3 min; alerta acima de 4 min sem decisão, evento ou progresso visível.

## 11. Number Scaling and Display

| Trecho | Escala dominante |
|---|---|
| Early | unidades, dezenas, centenas e milhares |
| Mid | milhares e centenas de milhares |
| Late | milhões baixos e dezenas de milhões |
| Boss | HP em milhões baixos |

A maior ordem de grandeza esperada na campanha é **dezenas de milhões de Coins acumuladas**, com o maior HP comum em dezenas de milhares e o Balloon King em milhões baixos. Não há necessidade de bilhões ou notação científica na versão 1.0.

Estratégia futura de exibição:

```text
1,250
12.5K
1.25M
10.0M
```

Usar até duas casas decimais só quando elas acrescentarem leitura; valores de dano pequenos podem permanecer inteiros.

## 12. Diamonds Economy

Diamonds são opcionais e não participam de unlocks, HP ou custos de campanha. A expectativa é de **aproximadamente 11–13 Diamonds** antes da vitória para um jogador que interage com eventos, sem garantia de todos.

### Fontes

- Conquistas de campanha: 6 Diamonds distribuídos entre primeiro pop, primeiro equipamento, primeiro crítico, primeiro especial, desbloqueio importante e Rainbow.
- Crystal Balloons: média de 5–6 Diamonds por campanha.
- Vitória do Balloon King: 2 Diamonds extras, voltados ao pós-game.

### Melhorias especiais

| Melhoria | Custo | Efeito | Regra |
|---|---:|---|---|
| Coin Magnet | 3 Diamonds | +5% Coins recebidas | Compra única, opcional |
| Steady Hand | 4 Diamonds | +0.05 ao limite de combo | Compra única, opcional |
| Workshop Polish | 5 Diamonds | +5% Auto DPS | Compra única, opcional |

Os checkpoints e o Balloon King são viáveis sem nenhuma dessas melhorias. Elas enriquecem a campanha, mas perder um Crystal Balloon nunca bloqueia a vitória.

## 13. Special Balloons and Buffs

### Frequência

Depois do desbloqueio do Blue Balloon, um especial elegível aparece em média a cada **180 s**. Para distribuição real, cada intervalo é escolhido entre 150 e 210 s; a média de simulação continua sendo 180 s. Não há especial durante o Balloon King e apenas um pode estar ativo por vez.

Em aproximadamente 105 minutos elegíveis, a expectativa é de **35 eventos**:

| Tipo | Peso | Eventos esperados | Início |
|---|---:|---:|---|
| Golden Special Balloon | 50% | ~18 | Blue |
| Crystal Balloon | 15% | ~5 | Green |
| Electric Balloon | 20% | ~7 | Green |
| Frenzy Balloon | 15% | ~5 | Purple |

Todos ficam visíveis por **10 s** e usam:

```text
Special HP = round(current normal balloon base HP × 0.40)
```

Essa proporção é estourável em poucos segundos pelo poder esperado do estágio, mas ainda pede atenção. Se o especial expirar, o balão normal de progressão permanece intacto e o jogador não perde uma condição necessária.

### Rewards and buffs

| Especial | Recompensa | Buff | Duração | Stacking |
|---|---|---|---:|---|
| Golden Special Balloon | Coins iguais a 2 pops normais do tier atual | — | — | — |
| Crystal Balloon | 1 Diamond + Coins de 1 pop normal | — | — | — |
| Electric Balloon | Coins de 1 pop normal | Auto DPS ×1.50 | 20 s | Não acumula; novo evento renova duração |
| Frenzy Balloon | Coins de 1 pop normal | Click Damage ×1.35; combo mínimo 1.25x | 15 s | Não acumula; novo evento renova duração |

Os bônus de especiais são excluídos da renda e DPS-base usados nos checkpoints. Eles devem transformar um bom momento em um momento excelente, não compensar uma economia quebrada.

## 14. Progression Checkpoints

| Tempo | Tier atual | Click Damage | Critical Chance | Critical Multiplier | Combo médio | Manual DPS | Auto DPS | Total DPS | Renda/min | Patrimônio disponível típico* | Marco principal |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 10 min | Blue | 5 | 5% | 2.00x | 1.20x | 25 | 6 | 31 | 630 | ~400 | Dart e primeiro crítico |
| 25 min | Green | 13 | 10% | 2.25x | 1.25x | 73 | 44 | 117 | 4,000 | ~2,000 | Dart Launcher e combo |
| 45 min | Purple | 37 | 15% | 2.50x | 1.30x | 236 | 202 | 438 | 16,000 | ~25,000 | Pressure Gun |
| 70 min | Golden | 101 | 20% | 2.75x | 1.30x | 709 | 822 | 1,531 | 84,000 | ~100,000 | Popping Machine |
| 95 min | Rainbow | 276 | 25% | 3.00x | 1.35x | 2,236 | 3,048 | 5,284 | 630,000 | ~600,000 | PopBot |
| 110 min | Rainbow/prep | 368 | 30% | 3.25x | 1.35x | 3,329 | 9,310 | 12,639 | 630,000 | ~1,000,000 | Boss desbloqueado |
| 115 min | Balloon King | 425 | 30% | 3.25x | 1.35x | 3,844 | 17,404 | 21,248 | — | compras convertidas em poder | Anti-Balloon Cannon |

\* Patrimônio disponível é uma faixa de liquidez após compras típicas, não a renda total. Jogadores podem guardar mais ou menos conforme suas escolhas.

### Checkpoint calculations

Exemplos que devem continuar verdadeiros em uma futura simulação:

```text
At 45 min:
Manual DPS = 37 × 4 × [1 + 0.15 × (2.50 - 1)] × 1.30 ≈ 236
Total DPS = 236 + 202 = 438
Purple TTK = 2,800 / 438 ≈ 6.4 s

At 115 min:
Manual DPS = 425 × 4 × [1 + 0.30 × (3.25 - 1)] × 1.35 ≈ 3,844
Total DPS = 3,844 + 17,404 = 21,248
Balloon King baseline duration = 4,200,000 / 21,248 ≈ 197.7 s
```

## 15. Balloon King

### Entry requirements and duration

- Requer 80 Rainbow pops, 750,000 Coins e a compra do Anti-Balloon Cannon.
- HP: **4,200,000**.
- Poder de entrada modelado: 3,844 Manual DPS + 17,404 Auto DPS = 21,248 Total DPS.
- Duração-base: aproximadamente **3 min e 18 s**; a meta aceitável em playtest é 3–4 min.
- Críticos e combo encurtam a luta quando o jogador permanece ativo; a automação impede que uma pausa curta torne a luta impossível.

### Boss phases

| HP restante | Fase | Alteração de balanceamento |
|---|---|---|
| 100–70% | Royal Arrival | Sem modificador; estabelece a leitura da luta |
| 70–30% | Cracked Crown | Intensifica arte, som e reação visual; sem nova mecânica ou penalidade numérica |
| 30–0% | Final Frenzy | Intensifica efeitos e música; sem nova mecânica ou penalidade numérica |

As fases são visuais e de feedback. Não reduzem DPS do jogador, não exigem reflexos de action game e não introduzem sistemas não ensinados. Isso preserva o TTK calculado e mantém o boss como ápice do loop já conhecido.

## 16. Victory Conditions

A única condição necessária para vencer é derrotar o Balloon King após desbloqueá-lo. Não há requisito de maximizar upgrades, completar conquistas, capturar especiais, comprar Diamonds ou entrar no Endless.

A recompensa de 1,000,000 Coins e 2 Diamonds ocorre após a vitória, portanto não pode ser necessária para atingir o próprio boss. Ela serve para a celebração e para iniciar o pós-game com liberdade.

## 17. Achievement Rewards

As recompensas são deliberadamente pequenas e não entram nos gates de Coins.

| Marco | Recompensa |
|---|---|
| Primeiro pop | 1 Diamond |
| Primeiro equipamento | 1 Diamond |
| Primeiro crítico | 1 Diamond |
| Primeiro especial | 1 Diamond |
| Desbloqueio de Purple | 1 Diamond |
| Desbloqueio de Rainbow | 1 Diamond |
| Vitória contra Balloon King | 2 Diamonds |

Se a taxa de Diamonds se mostrar alta demais, reduzir a fonte de Crystal Balloons é preferível a aumentar o custo de upgrades especiais, pois o jogador deve continuar entendendo seus valores.

## 18. Anti-Dead-Zone and Anti-Snowball Rules

### Dead zones

Uma dead zone é suspeita se, no período abaixo, o jogador não puder comprar, guardar com progresso claro, perseguir unlock ou aproveitar uma ação relevante:

| Faixa | Limite tolerável sem decisão | Ação de ajuste |
|---|---:|---|
| 0–10 min | 60 s | Reduzir custo inicial ou aumentar recompensa de Red |
| 10–45 min | 2 min | Rever custo do próximo upgrade/equipamento ou HP do tier |
| 45–95 min | 3 min | Rever gate, renda por pop e primeiro nível do novo equipamento |
| 95–115 min | 4 min | Rever custo do boss, PopBot/Cannon ou recompensa de Rainbow |

### Snowball

- Um novo equipamento não deve permitir comprar imediatamente todo o próximo estágio.
- Um primeiro nível novo deve elevar o Auto DPS em aproximadamente 15–25%, nunca eliminar o tier atual sozinho.
- O próximo tier deve começar com TTK de cerca de 5–8 s; se começar abaixo de 2 s, a recompensa ou HP do novo tier está baixa demais.
- Se o jogador ultrapassar o checkpoint de tier em mais de 25% de DPS antes de cumprir seus pops requeridos, aumentar requisito de pops ou revisar o ganho do equipamento anterior antes de aumentar apenas o HP.

## 19. Balance Risks

### Clicking becomes irrelevant

O risco principal de uma curva automática forte é o clique virar decoração. Medir a proporção Manual/Auto nos checkpoints, manter críticos limitados e preservar combo no dano manual evita que isso aconteça.

### Economy walls

Se a renda real ficar abaixo da tabela por causa de menus, tempo de animação ou decisões, os custos devem cair antes de aumentar o DPS do jogador. O objetivo é recuperar frequência de decisão, não acelerar tudo indiscriminadamente.

### Special balloons dominate the economy

Se mais de 10% das Coins de uma campanha típica vierem de Golden Specials, reduzir sua recompensa de 2 pops para 1 pop antes de reduzir a frequência. A economia-base não pode depender de eventos.

### Late-game overspend

Há liquidez planejada no Rainbow para acomodar escolhas diferentes. Se ela permitir que um jogador compre todos os níveis restantes muito antes do boss, subir apenas os custos tardios de Popping Machine, PopBot e Cannon; não mexer nos custos iniciais que sustentam o onboarding.

## 20. Validation Metrics and Tuning Guidelines

Quando o jogo existir, registrar localmente em debug ou telemetria de desenvolvimento:

- tempo total de sessão e tempo de conclusão;
- tempo de desbloqueio de cada tier;
- quantidade de pops por tier e TTK médio;
- total de cliques e CPS médio durante períodos ativos;
- DPS manual, Auto DPS e proporção entre ambos;
- compras, custo, nível e ordem de compra;
- Coins/min, Coins guardadas e tempo entre compras relevantes;
- especiais vistos, capturados e expirados;
- Diamonds obtidos e gastos;
- duração e taxa de vitória do Balloon King.

### Acceptance ranges for the first balance pass

| Métrica | Faixa desejada |
|---|---|
| Primeira vitória de jogador ativo típico | 105–135 min |
| TTK comum após entrada de tier | 5–8 s, caindo com compras |
| Balloon King | 3–4 min |
| Manual DPS no Rainbow inicial | 35–45% do Total DPS |
| Manual DPS no boss | 15–25% do Total DPS |
| Especiais vistos antes do boss | ~30–40 |
| Diamonds antes da vitória | ~11–13 |

### Tuning order

1. Validar tempo e TTK dos tiers sem especiais nem Diamonds.
2. Ajustar recompensa e custos para eliminar dead zones.
3. Ajustar primeiro nível de equipamentos para garantir salto perceptível sem snowball.
4. Ajustar Combo/Critical apenas se o clique estiver fraco ou dominante demais.
5. Ajustar especiais como bônus; nunca usá-los para consertar a economia-base.
6. Ajustar HP do Balloon King por último, após confirmar o poder real do checkpoint de 115 min.

As fórmulas deste documento são determinísticas, centralizadas e reproduzíveis por uma futura simulação. Qualquer alteração de HP, recompensa, custo ou DPS deve ser comparada com os checkpoints, TTK, renda por minuto e duração de campanha acima antes de entrar no jogo.
