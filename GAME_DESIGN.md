# POP Balloon — Game Design Document

**Status:** direção definitiva para a campanha 1.0.

POP Balloon é um active incremental de PC sobre estourar **um único balão principal central**. O jogador combina clique, automação, compras e desbloqueios para avançar pelos tiers até o Balloon King. A primeira campanha principal visa **4–6 horas de jogo ativo típico**.

## Core loop

```text
Balão principal → clique e Auto DPS → HP diminui → pop → recompensa → próximo balão
```

Existe apenas um alvo normal durante o jogo. O balão é o foco visual e interativo da tela. Após um pop, o próximo balão do tier atual ocupa o mesmo lugar; o jogador não escolhe entre alvos concorrentes.

## Tiers

O tier normal mais recente desbloqueado substitui o anterior como alvo principal:

1. Red Balloon
2. Blue Balloon
3. Green Balloon
4. Purple Balloon
5. Dark Balloon
6. Rainbow Balloon
7. Balloon King

Cada tier representa um salto reconhecível de HP, Coins, aparência e ritmo. A progressão completa segue Red → Blue → Green → Purple → Dark → Rainbow → Balloon King. Especiais são eventos breves que preservam o loop de alvo único e nunca criam um campo simultâneo.

## Poder e decisões

- **Click Damage** mantém o jogo ativo e recebe upgrades ao longo de toda a campanha.
- **Critical Chance, Critical Damage e Combo** entram gradualmente para tornar o clique uma estratégia de pico.
- **Needle, Dart, Dart Launcher, Pressure Gun, Balloon Popping Machine, PopBot e Anti-Balloon Cannon** são produtores automáticos de DPS com compra inicial, níveis, custos crescentes e milestones de nível 10, 25, 50 e 100.
- Milestones concedem multiplicadores claros de DPS por equipamento, não uma skill tree.
- Oito escolhas na aba Global usam Diamonds: Coin Multiplier, Auto DPS Multiplier, Buff Duration, Buff Power, Special Balloon Frequency, Diamond Event Frequency, Critical Mastery e Combo Mastery. Cada efeito é distinto e limitado; não há novo multiplicador direto de clique.

## Discovery e onboarding

Opções novas não aparecem todas no início. Cada conteúdo usa um estado de descoberta: **HIDDEN**, **REVEALED_LOCKED**, **AVAILABLE** ou **OWNED**. A interface mostra somente conteúdos revelados, sem reservar espaço para itens futuros.

Click Damage inicia visível. Needle aparece no nível 5 de Click Damage. Blue revela Critical Chance e Golden Special; Critical Damage espera Critical Chance nível 3; Dart espera Needle nível 10; Combo aparece após Green. Crystal aparece após 20 pops Green, antes do Purple, e revela Diamond Reward quando estourado. Purple, Dart nível 10 e Click Damage nível 12 revelam Dart Launcher e Coin Reward. Electric ou Frenzy revelam Buff Frequency depois que o jogador já viu um buff funcionar. O primeiro Diamond revela Global Upgrades; Dart Launcher nível 10, Click Damage nível 16 e um Diamond revelam Pressure Gun. Uma descoberta produz uma mensagem curta e destaque dourado, sem popup que interrompa a partida.

## Economia e ritmo

Coins são a moeda principal. Diamonds vêm somente de eventos Crystal e financiam escolhas permanentes limitadas na aba Global. A duração cresce por profundidade de upgrades, equipamentos, tiers, milestones e decisões de compra — nunca por espera vazia.

Red é um onboarding rápido; Blue introduz resistência sem exigir Critical; Green é o primeiro tier que pede investimento deliberado em automação. Click Damage cresce linearmente em +1 por nível; sua curva de custos é suave no início e se torna progressivamente cara somente depois da base de jogo estar estabelecida.

Click Damage mantém base `1 + (nível - 1)`, sem teto. A cada 25 níveis recebe +10% aditivo sobre a base: `base × (1 + floor(nível / 25) × 0,10)`. O card mostra dano atual/próximo, próximo marco e progresso módulo 25; atingir um marco produz destaque breve e SFX de milestone existente. Equipamentos continuam sustentando a escala maior da campanha.

## Diamond Progression Expansion

Coin Multiplier e Auto DPS Multiplier aparecem após o primeiro Diamond; Buff Duration e Special Balloon Frequency após Green e o primeiro buff; Buff Power e Combo Mastery em Purple (Power requer buff conhecido); Critical Mastery em Dark. Diamond Event Frequency mantém seu unlock e estado anteriores, agora na aba Global. Gastar o último Diamond não esconde a aba. Diamond Reward permanece na aba de upgrades existente.

Coins e Auto DPS recebem +5%/nível, 10 níveis; Buff Duration +5%, 8 níveis; Buff Power +4%, 10 níveis; Special Frequency +5% relativo, 8 níveis; Critical Mastery e Combo Mastery +3%, 8 níveis. Os custos compartilhados são 1/2/3/5/8/12/18/25/35/50 Diamonds, truncados no cap. Diamond Event Frequency preserva 2/4/7/11/16. Buff Power e Combo Mastery ampliam somente a parcela de bônus, preservando o valor neutro de ×1.

Electric e Frenzy entram pelo contador de balões normais: a cada 45 pops no nível base, um dos buffs revelados aparece aleatoriamente, sem repetir o evento imediatamente quando ambos estiverem disponíveis. Special Frequency reduz o limiar para `ceil(45 / (1 + bônus))` pops. Golden continua a cada 5 pops; Crystal continua exclusivo de Diamond Event Frequency. Buff Duration/Power valem na próxima ativação/renovação; não alteram buffs já ativos. Equipment Efficiency e Pop Reward não foram adicionados porque duplicariam Auto DPS e Coins. Os IDs antigos Coin Magnet/Auto DPS Core/Critical Core preservam seus níveis sob os novos nomes e efeitos. Click Core é somente legado: preserva níveis e benefício existentes, sem novas compras. Novas campanhas não o recebem.

## Especiais e boss

Golden Special, Crystal, Electric e Frenzy são substituições temporárias do alvo central. Após ser revelado, Golden Special aparece a cada 5 balões normais estourados, tem o HP do alvo normal atual e entrega 3× sua recompensa de Coins. Crystal é o único evento que entrega Diamonds; Electric renova um buff de Auto DPS; Frenzy renova um buff de Click Damage. Diamond Event Frequency reduz somente o intervalo do Crystal, sem afetar os demais eventos. Perder um evento não bloqueia a campanha.

## Escopo atual

O jogo inclui Red, Blue, Green, Purple, Dark e Rainbow, Click Damage, Critical Chance, Critical Damage, Combo, equipamentos automáticos, Coins, Diamonds por evento, upgrades globais, especiais, buffs, save, boss, Endless e discovery gradual.

## UX de playtest

A loja oferece compra ×1, ×10 e MAX para upgrades repetíveis, somando custos progressivos nível a nível. Cards exibem valor atual → próximo, tooltips em toda a área e estado MAX sem barra inútil. Statistics usa os contadores persistidos por tier. Hold to Click fica em Settings, persiste e é cancelado ao soltar, sair do alvo, perder foco, pausar ou trocar de cena.

## Entrada

O jogo abre em um Main Menu consistente com a apresentação cartoon. Continue só aparece para um save válido; New Game pede confirmação quando há progresso e preserva as preferências de áudio; Endless só aparece após a vitória. Settings, Credits e Quit pertencem ao fluxo de entrada, sem alterar o loop de campanha.
