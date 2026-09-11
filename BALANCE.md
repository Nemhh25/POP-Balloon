# POP Balloon — Balance Document

**Status:** plano de campanha de 4–6 horas. O vertical slice continua com valores pequenos; a tabela de campanha orienta os próximos passes e deve ser validada por simulação e playtests antes de virar dados finais.

## Princípios

- Um tier troca o balão principal e aumenta HP, recompensa e produção esperada juntos.
- Compras frequentes e metas visíveis evitam dead zones; espera não é ferramenta de duração.
- Click Damage tem pico maior em jogo ativo; Auto DPS garante progresso e ganha milestones perceptíveis.
- Coins são a economia regular; Diamonds são raros e não sustentam gastos repetitivos.

## Vertical slice atual

| Balão | HP base | Coins/pop | Estado |
|---|---:|---:|---|
| Red | 12 | 5 | Inicial |
| Blue | 240 | 60 | Desbloqueia com 220 Red pops e 300 Coins |
| Green | 3.200 | 500 | Desbloqueia com 180 Blue pops e 2.000 Coins |
| Purple | 12.000 | 7.000 | Desbloqueia com 150 Green pops e 20.000 Coins |
| Dark | 1.800.000 | 100.000 | Desbloqueia com 120 Purple pops, 250.000 Coins e Pressure Gun Lv. 1 |
| Rainbow | 25.000.000 | 1.200.000 | Desbloqueia com 120 Dark pops, 2.000.000 Coins e PopBot Lv. 1 |

Fórmulas implementadas e ainda úteis:

```text
Base Click Damage(level) = 1.00 + (level - 1) × 1.00
Milestone count = floor(level / 25)
Click Damage(level) = Base Click Damage(level) × (1 + Milestone count × 0.10)
Next Click Upgrade Cost(level 1–14) = [5, 5, 10, 10, 15, 20, 25, 30, 40, 50, 60, 75, 90, 110]
Next Click Upgrade Cost(level 15+) = round_to_nearest_5(180 × 1.22 ^ (level - 15))
Equipment DPS(level) = Base DPS × level
Equipment Level Cost(level) = round_to_nearest_5(Base Cost × 1.12 ^ level)
```

Needle: DPS base 1, primeira compra 25 Coins, máximo atual 40 e tick de Auto DPS a cada 0,25 s. Seus primeiros níveis preservam o crescimento de custo 1,12 para sustentar compras frequentes no início.

## Early Game Rebalance Patch

Red é o tutorial: 12 HP e 5 Coins mantêm o primeiro pop curto. Os quatro upgrades que levam Click Damage do Lv. 1 ao Lv. 5 custam 30 Coins no total; isso revela Needle sem grind. Needle não foi alterada: a compra inicial de 25 Coins e 1 DPS já é adequada para o primeiro passo de automação.

Blue foi reduzido de **800 para 240 HP** e sua recompensa subiu de **45 para 60 Coins**. Green recebe a subida de ritmo: foi reduzido de 8.000 para **3.200 HP** para evitar uma parede absoluta, mas permanece 13,3× mais resistente que Blue e paga **500 Coins** em vez de 400. Purple e os tiers posteriores permanecem inalterados.

Referência de TTK, usando 6 cliques/s, sem críticos e ignorando buffs: Red inicial = ~2,0 s (12 HP / 6 DPS); Blue com Click Lv. 10 e Needle Lv. 8 = ~1,9 s (240 HP / ~128 DPS); Green com Click Lv. 15, Needle Lv. 10 e Dart Lv. 10 = ~8,9 s (3.200 HP / ~360 DPS). Green ainda pode levar ~16 s sem Dart, tornando automação e compras uma decisão clara em vez de exigir Critical.

| Tempo ativo estimado | Build/tier | Coins/min estimados | Próximas compras |
|---|---|---:|---|
| 0 min | Red, Click Lv. 1 | ~150 | Click Lv. 2 em poucos pops |
| 5 min | Blue, Click Lv. 9–10, Needle Lv. 6–8 | ~700–1.100 | Needle, Click e Dart inicial |
| 10 min | Blue tardio, Click Lv. 11–13, Needle Lv. 10, Dart inicial | ~1.200–1.800 | Dart e progresso para Green |
| 20 min | Green, Click Lv. 14–16, Needle Lv. 10+, Dart Lv. 8–10 | ~1.500–2.500 | automação e objetivo de Purple |

As estimativas incluem a cadência de Golden Special e assumem jogo ativo. As primeiras compras ocorrem em segundos; Needle normalmente é comprada no primeiro minuto; Blue é atingido em torno de 4–6 minutos. Mid e late game preservam seus HP, recompensas, equipamentos e preços atuais.

Dart: DPS base 8, primeira compra 500 Coins, máximo atual 40 e disponibilidade após Blue + Click Damage nível 6. Needle e Dart recebem ×2 no nível 10 e outro ×2 no nível 25; esses multiplicadores acumulam com os níveis normais.

Dart Launcher: DPS base 40, primeira compra 15.000 Coins, máximo 40; reveal em Purple + Dart Lv. 10 + Click Damage Lv. 12. Pressure Gun: DPS base 180, primeira compra 120.000 Coins, máximo 40; reveal em Purple + Dart Launcher Lv. 10 + Click Damage Lv. 16. Ambos usam os mesmos marcos acumulativos ×2 no nível 10 e ×2 no nível 25.

Specials usam um scheduler central e duram 10 s. Depois de Blue ser desbloqueado, Golden Special aparece a cada 5 balões normais estourados, tem o mesmo HP do balão normal atual e concede exatamente 3× a recompensa de Coins desse balão, incluindo bônus de Coins ativos. Crystal (3.200 HP, 15K Coins + 1 Diamond) aparece após 20 pops Green, antes do Purple. Electric (3.200 HP, 20K Coins, buff ×2 Auto DPS por 12 s) e Frenzy (4.000 HP, 20K Coins, buff ×2 Click Damage por 12 s) entram juntos na rotação ao desbloquear Blue. A cada 45 balões normais, o scheduler sorteia um deles sem repetir o anterior. Repetir um buff renova sua duração, sem acumular multiplicadores.

Diamonds vêm somente do evento Crystal; balões normais não concedem mais Diamond por contagem de pops. Após ser revelado em Green, Crystal possui timer próprio de **18 s**, dura 10 s e concede 1 Diamond ao ser estourado. Se outro especial estiver ativo quando seu timer vencer, o Crystal fica pendente e aparece assim que o slot for liberado. Diamond Reward pode conceder **um Diamond adicional** nesse evento.

**Diamond Event Frequency** custa 2/4/7/11/16 Diamonds, tem 5 níveis e reduz em 6% por nível somente o intervalo do Crystal: 18,0 → 16,9 → 15,8 → 14,8 → 13,7 → 12,6 s. A duração do evento permanece 10 s; portanto, mesmo no máximo ele não fica constante e não altera Golden Special, Electric ou Frenzy.

## Economy Depth & Upgrade Choice Polish

**Coin Reward** é revelado em Purple. Tem 10 níveis, concede +5% de Coins normais por nível (máximo +50%) e custa `max(1.000, recompensa do maior tier desbloqueado × 2,0 × 1,65^nível)`. O custo usa o maior tier desbloqueado, impedindo que retornar a um balão anterior barateie o investimento. A referência de retorno é 3–7 minutos: em Purple inicial, o primeiro nível custa 14K Coins e adiciona +5% de income; em Dark inicial, custa 200K e mantém a mesma janela relativa. É um investimento econômico, não um pico instantâneo de poder.

**Diamond Reward** só aparece depois do primeiro Crystal estourado. Tem 3 níveis, custa 2/4/6 Diamonds e acrescenta +15% de chance por nível de receber 1 Diamond extra no evento Crystal (máximo +45%). O retorno é intencionalmente lento e complementar.

**Buff Frequency** só aparece após o primeiro Electric ou Frenzy Balloon, para que o jogador tenha visto um buff real. Mantém 25 níveis, +0,2 ponto percentual por nível, máximo +5% e exatamente 500 cliques manuais válidos por nível. O botão mostra `Lv./25`, bônus atual, `Clicks: atual / 500` e `MAX`; cada nível concluído salva imediatamente, enquanto os cliques intermediários não acionam save.

### Global Upgrades

| Upgrade | Reveal | Efeito | Custos (Diamonds) | Papel |
|---|---|---|---|---|
| Auto DPS Multiplier | 1º Diamond | +5% por nível, 10 níveis (+50%) | Curva compartilhada | Após soma do DPS dos equipamentos |
| Coin Multiplier | 1º Diamond | +5% por nível, 10 níveis (+50%) | Curva compartilhada | Todas as recompensas de Coins |
| Buff Duration | Green + buff conhecido | +5% por nível, 8 níveis (+40%) | Curva compartilhada | Próximos buffs: 12 → 16,8 s |
| Buff Power | Purple + buff conhecido | +4% por nível, 10 níveis (+40% do bônus) | Curva compartilhada | Próximos buffs: ×2 → ×2,4 |
| Special Balloon Frequency | Green + buff conhecido | +5% relativo, 8 níveis (+40%) | Curva compartilhada | Electric/Frenzy: 45 → 33 pops normais |
| Diamond Event Frequency | Diamond introduzido | −6% intervalo, 5 níveis (−30%) | 2/4/7/11/16 | Crystal: 18 → 12,6 s |
| Critical Mastery | Dark | +3% dano crítico final, 8 níveis (+24%) | Curva compartilhada | Base crítica continua ×2,5 |
| Combo Mastery | Purple | +3% do bônus Combo, 8 níveis (+24%) | Curva compartilhada | 25 stacks: ×2,68 → ×3,0832 |

A curva compartilhada, centralizada em GlobalUpgradeData, é **1/2/3/5/8/12/18/25/35/50 Diamonds**. Custa 159 para 10 níveis ou 74 para 8; o conjunto Global custa 813 Diamonds. Coin Magnet, Auto DPS Core e Critical Core conservam seus IDs e níveis, agora sob os nomes/efeitos acima. O rebalanceamento desses multiplicadores aplica-se também a saves antigos. Click Core permanece apenas como benefício legado já comprado, sem venda; não há novo buff Diamond direto de clique. Equipment Efficiency e Pop Reward foram omitidos por redundância. Diamond Reward continua seu investimento separado existente.

Sanity check: Red/Blue sem Diamonds não mudam; primeiros Diamonds liberam duas escolhas de custo 1. Em Green, Duration/Frequency requerem um buff visto; Purple adiciona Power/Combo; Dark adiciona Critical Mastery. Não existem novos requisitos de unlock por Diamonds. Auto DPS sem buff é no máximo ×1,5; com Electric máximo ×3,6. Combo máximo sobe de ×2,68 a ×3,0832; crítico final de ×2,5 a ×3,1. Buffs não acumulam consigo mesmos. Golden mantém 5 pops; Crystal não recebe o multiplicador de especiais. Endless usa os mesmos caps.

813 Diamonds correspondem a cerca de 2,85–4,07 horas no limite ideal de um Crystal perfeito a cada 12,6–18 s, antes de Diamond Reward, conflitos de eventos e tempo para estourá-los. Essa é uma referência de orçamento, não uma medição de campanha. Diamond Reward e jogo eficiente reduzem o tempo; validar a curva em playtest completo continua necessário.

### ROI, cadence e checkpoints

| Checkpoint | Income/min estimado | Opções principais | Cadência de decisão |
|---|---:|---|---|
| Purple early | 45K–70K | Coin Reward, Dart Launcher, primeiro Global | compra útil a cada 1–3 min |
| Purple late | 90K–180K | Pressure Gun, Diamond Reward após Crystal, buffs | 2–4 min |
| Dark early | 0,8M–1,8M | Coin Reward, Popping Machine, Auto DPS Multiplier | 2–5 min |
| Dark late | 3M–8M | PopBot, Buff Power, Combo Mastery | 3–6 min |
| Rainbow early | 25M–80M | Cannon, Critical Mastery, caps restantes | 4–8 min |

Ativo: Click, Critical, Combo, Buff Frequency e Coin Reward convertem atenção em maior ritmo. Idle: Equipment, milestones e Auto DPS Core estabilizam DPS sem clique. Coin Reward é a ponte econômica entre os dois; Diamond Reward e Globals são escolhas de longo prazo. Nenhuma dessas categorias precisa ser maximizada para liberar o próximo tier.

Click Damage não tem nível máximo. Marcos infinitos a cada 25 níveis adicionam 10% da base por marco, sem composição exponencial. Valores: Lv.24=24; 25=27,5; 26=28,6; 49=53,9; 50=60; 75=97,5; 100=140; 250=500. O exemplo Lv.47 correto é 51,7 → 52,8 no nível 48. A barra usa `nível % 25`, mostra conclusão por 0,9 s e segue para o próximo marco. Nenhuma contagem de milestone é salva. Os caps existentes permanecem: Critical Chance Lv.117, 0,3 ponto percentual/nível (35,1% real); Critical Damage Lv.5, ×2,5 base. Combo mantém 1,5 s e 25 stacks, +7% por stack após o primeiro.

## Reveal progression

| Conteúdo | Reveal requirement | Compra/uso após reveal | Momento esperado |
|---|---|---|---|
| Click Damage | Inicial | Coins | Imediato |
| Needle | Click Damage Lv. 5 | 25 Coins, depois níveis | Red, primeiro grande unlock |
| Blue Balloon | 220 Red pops + 300 Coins | Unlock normal | Fim de Red |
| Critical Chance | Blue desbloqueado | 100 Coins inicial | Início de Blue |
| Critical Damage | Critical Chance Lv. 3 | 250 Coins inicial | Durante Blue |
| Dart | Needle Lv. 10 | Blue + Click Damage Lv. 6 + 500 Coins | Blue tardio |
| Green Balloon | 180 Blue pops + 2.000 Coins | Unlock normal | Fim de Blue |
| Combo | Green desbloqueado | Uso automático no clique | Início de Green |
| Dart Launcher | Purple + Dart Lv. 10 + Click Damage Lv. 12 | 15.000 Coins, depois níveis | Início de Purple |
| Purple Balloon | 150 Green pops + 20.000 Coins | Unlock normal | Próximo tier |
| Golden Special | Blue desbloqueado | Evento temporário | Blue inicial |
| Crystal | 20 Green pops | Evento temporário, 1 Diamond | Green final |
| Coin Reward | Purple desbloqueado | +5% Coins por nível, 10 níveis | Purple inicial |
| Diamond Reward | Primeiro Crystal estourado | +15% chance de Diamond extra por nível, 3 níveis | Purple médio |
| Buff Frequency | Primeiro Electric ou Frenzy estourado | 500 cliques manuais por nível, 25 níveis | Purple médio |
| Global Upgrades | Primeiro Diamond | Diamonds | Assim que a moeda for obtida |
| Electric / Frenzy | Blue desbloqueado | Buff temporário sorteado a cada 45 pops normais | Blue em diante |
| Pressure Gun | Launcher Lv. 10 + Click Lv. 16 | 120.000 Coins, depois níveis | Purple médio |
| Dark Balloon | 120 Purple pops + 250.000 Coins + Pressure Gun Lv. 1 | Unlock normal | Fim de Purple |

Conteúdo HIDDEN não ocupa espaço. REVEALED_LOCKED mostra requisitos pendentes; AVAILABLE espera apenas a compra; OWNED evolui normalmente.

## Curva de campanha proposta

| Checkpoint ativo | Tier | HP típico | Coins/pop | Dano total esperado |
|---|---|---:|---:|---:|
| 0–20 min | Red | 12–60 | 5–20 | 1–15 |
| 20–50 min | Blue | 160–1.2K | 45–260 | 20–150 |
| 50–100 min | Green | 8K–60K | 1.5K–12K | 200–2K |
| 100–160 min | Purple | 400K–3M | 80K–600K | 5K–60K |
| 160–230 min | Dark | 20M–150M | 4M–30M | 150K–2M |
| 230–300 min | Rainbow | 1B–8B | 200M–1.5B | 5M–100M |
| 300–360 min | Balloon King | 30B+ | campanha | 100M+ |

Faixas, e não números fixos por pop, permitem variação de upgrades e de ritmo. A recompensa média de cada tier deve manter sua compra relevante em aproximadamente 1–3 minutos de jogo ativo; unlocks maiores podem demandar 5–10 minutos, desde que exibam o progresso claramente.

## Equipamentos e milestones

Needle e Dart implementam os dois primeiros marcos: nível 10 (×2) e nível 25 (×2 adicional). Os marcos 50 e 100 continuam planejados para equipamentos futuros, após novo passe de dados e playtest. Custos e DPS devem ser calculados juntos para que o próximo equipamento complemente — e não invalide — os anteriores.

| Faixa | Equipamento desbloqueado | Papel |
|---|---|---|
| Red | Needle | primeira automação |
| Blue | Dart | DPS rápido |
| Green | Dart Launcher / Pressure Gun | crescimento médio |
| Purple | Popping Machine | produção pesada |
| Dark | PopBot | escala alta |
| Rainbow | Anti-Balloon Cannon | produção final |

## Métricas de validação

Registrar tempo de tier, pops/min, Coins/min, dano manual/automático, tempo entre compras e tempo até o próximo objetivo. Corrigir uma dead zone por recompensa, desconto, milestone ou unlock adicional — nunca apenas elevando custos ou HP.

## Late game implementado

Balloon Popping Machine: 2.500 DPS base, 250K Coins, reveal em Dark com Pressure Gun Lv. 3, Click Lv. 18 e 10 pops Dark. PopBot: 16K DPS base, 2M Coins, reveal em Machine Lv. 10, Click Lv. 22 e 60 pops Dark. Anti-Balloon Cannon permanece o objetivo de Rainbow. Os três têm 100 níveis e milestones ×2 nos níveis 10/25, ×3 nos níveis 50/100.

Rainbow exige 120 Dark pops, 2M Coins e PopBot Lv. 1. Durante Dark, o alvo de pacing é uma compra útil a cada 1–3 minutos de atividade; caso a próxima compra significativa leve mais que isso sem Click, equipamento, crítico ou Global Upgrade acessível, o trecho é uma dead zone e deve ser reduzido no próximo passe.

Buff Power, Combo Mastery e Critical Mastery compõem os investimentos finais opcionais. Buffs e specials continuam relativos e relevantes em Rainbow. Prontidão interna para Balloon King exige Rainbow desbloqueado e Anti-Balloon Cannon Lv. 1.

Balloon King usa 30M HP. A referência é uma luta ativa de poucos minutos com uma build Rainbow razoável; fases ocorrem em 70% e 30%. Specials novos ficam suspensos durante o boss; buffs já ativos continuam. Após a vitória, Endless reutiliza Rainbow e a economia existente.
