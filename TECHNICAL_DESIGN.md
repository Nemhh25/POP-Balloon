# POP Balloon — Technical Design

**Status:** arquitetura Godot 4.7 para a campanha Red → Dark → Rainbow → Balloon King e Endless.

## Estrutura

```text
Resources → GameState/services → GameSession → BalloonController → Balloon/UI
```

`GameState` mantém economia, níveis, unlocks, estatísticas e o estado persistente do balão normal atual. `GameSession` coordena regras e sinais. `BalloonController` controla exclusivamente uma instância visível central. A UI apenas apresenta estado.

## Discovery e reveal requirements

```text
RevealRuleData (dados) → RevealService (avaliação) → GameSession (sinais) → MainHUD (visibilidade)
```

`RevealRuleData` cobre nível de Click Damage, nível de Critical Chance, tier normal desbloqueado, nível de equipamento, pops de um balão específico e Diamonds obtidos. Todos os campos configurados são requisitos cumulativos; não há rule engine genérico.

`RevealService` mantém os estados HIDDEN, REVEALED_LOCKED, AVAILABLE e OWNED e recalcula reveals a partir de `GameState` e catálogo. `GameSession` o atualiza após compra, pop ou unlock e emite `content_revealed`/`reveal_states_changed`. `MainHUD` não contém regras de progressão: apenas oculta HIDDEN, apresenta REVEALED_LOCKED e faz highlight breve de uma descoberta.

## BalloonController

```text
BalloonController
├── current Balloon
├── BalloonContainer (Control centralizado)
└── respawn único após pop
```

Responsabilidades:

- instanciar um único `Balloon` para `current_normal_balloon_id`;
- restaurar ou reiniciar HP com a variação determinística atual;
- aplicar clique e Auto DPS ao mesmo alvo;
- encaminhar dano e pop para `GameSession`;
- depois do pop, incrementar a variação e criar o próximo balão do tier atual.

`Balloon` conhece somente HP, clique e feedback. Ele não entrega Coins, não escolhe tier e não grava save. `BalloonController` pode substituir temporariamente o normal por um special e restaurar o HP normal persistido ao fim; não há pool, slots ou seleção de múltiplos alvos.

## Midgame systems

`SpecialBalloonScheduler` usa o total de pops normais para a rotação Electric/Frenzy e para Golden Special, mantém um timer exclusivo data-driven para o evento Diamond/Crystal e um timer one-shot de duração. Electric e Frenzy são revelados juntos ao desbloquear Blue; no marco compartilhado o sorteio evita repetição imediata. O upgrade Diamond Event Frequency altera somente o timer Crystal. Se o Crystal vencer enquanto outro especial ocupa o slot, ele entra em estado pendente e inicia assim que esse slot é liberado, sem perder o ciclo. Pops especiais permanecem separados de pops normais, evitando progresso ou recompensa duplicados.

`EconomyService` centraliza Coins e Diamonds. `GlobalUpgradeData` e `GlobalUpgradeService` mantêm investimentos em Diamonds, com níveis persistidos; seus multiplicadores são consumidos por `GameSession`. `BuffService` mantém apenas buffs ativos em memória, agenda o vencimento mais próximo e renova a duração da mesma chave sem stack ilimitado. Auto DPS e clique consultam esses multiplicadores no momento do dano.

## Diamond Progression Expansion

`BalanceService` deriva `floor(level/25)` e aplica `base * (1 + count * 0.10)`. Base linear e níveis ilimitados permanecem; não há contador persistido nem marcos enumerados. `GameSession.purchase_completed` indica milestone e reutiliza o SFX de compra especial. `UpgradeCard` exibe a barra módulo 25 e conclusão por 0,9 s, inclusive ao atravessar marcos em lote.

Oito cards Global: Coin/Auto DPS Multiplier, Buff Duration/Power, Special Balloon Frequency, Diamond Event Frequency, Critical/Combo Mastery. Os sete recursos globais usam `GlobalUpgradeData.cost_at_level` com curva única (1,2,3,5,8,12,18,25,35,50), usada tanto pela compra quanto pela cotação ×1/×10/MAX. Dados definem cap, tier de reveal e necessidade de buff conhecido. O passe atual reduz os reveals para Green (Duration/Frequency), Purple (Power/Combo) e Dark (Critical Mastery). A GameSession bloqueia compras de conteúdo oculto. Diamond Event Frequency mantém seu campo, serviço, curva 2/4/7/11/16 e botão anteriores, movido para Global; não há estado duplicado.

Coin Gain aplica-se também a Coins especiais; Golden usa 3× normal sem duplicar o global. Auto DPS global vem após soma dos equipamentos. Buff Power e Combo Power ampliam somente `(multiplicador_base - 1)` e recolocam o neutro 1. Duration/Power são lidos ao ativar/renovar buff. Critical Mastery aplica bônus separado apenas ao ataque crítico, preservando cap base. Special Frequency usa somente o contador Electric/Frenzy: `ceil(45 / (1+bônus))` pops normais; a seleção é aleatória e evita repetir o último buff quando ambos estão revelados. Crystal usa seu timer próprio e Golden mantém sua cadência de 5 pops.

Novos níveis vivem no dicionário existente `global_upgrade_levels`, com default zero em saves anteriores. IDs `coin_magnet`, `auto_dps_core`, `critical_core` são conservados com nomes/efeitos novos. `click_core` continua reconhecido para carregar níveis/benefício legado, mas marcado `legacy_only` e indisponível para compras. Versão do save e preferências permanecem iguais. A descoberta Global considera Diamonds já obtidos, mesmo depois de gastar todos.

Cards dinâmicos usam o Theme e ícones existentes, nível/cap, bônus atual → próximo, custo Diamond explícito, MAX desativado e tooltip da área completa com custo. Tooltip só é atualizado quando muda, preservando hover. Textos novos usam `tr()` onde aplicável; o projeto não possui catálogo de traduções configurado e mantém o idioma inglês atual. Valores econômicos/reveal e limitações de pacing estão no BALANCE.md.

## Dano

```text
Clique em Balloon → GameSession calcula AttackResult → BalloonController aplica no alvo atual
AutoDamageTimer (0,25 s) → DPS total × intervalo → mesmo alvo atual
```

O clique aumenta um Combo transitório até 20 stacks; um `Timer` único o zera após 1,5 s sem clique. `CombatResolver` aplica o multiplicador de Combo e então sorteia Critical Hits a partir dos níveis persistentes de Critical Chance/Damage. `AttackResult` carrega dano, flag crítica e multiplicador de combo para feedback e estatísticas.

Ao desbloquear um tier normal, `GameSession` troca `current_normal_balloon_id` e o controlador cria um alvo cheio do novo tier. A arquitetura futura de especiais pode substituir temporariamente esse alvo, salvando e restaurando o normal, sem introduzir alvos simultâneos.

## Estado e save

O JSON permanece em `user://pop_balloon_save.json` e usa `save_version: 10`.

```text
currency, upgrades (incluindo Reward Upgrades e Buff Frequency), equipment_levels, global_upgrade_levels
progression:
  current_normal_balloon_id
  current_balloon_health
  normal_variation_index
  unlocked_balloon_ids, balloon_pops_by_id, flags de campanha
statistics, settings
```

Saves v1–v9 mantêm migrações compatíveis. A v10 adiciona `campaign_completion_presented`, contagem do Balloon King, Hold to Click persistente e nível de Diamond Event Frequency. O ID técnico legado `golden_balloon` é preservado, mas sua apresentação é Dark Balloon, evitando perda de unlocks, pops ou tier atual. Buffs e eventos em andamento continuam transitórios.

Autosave ocorre em compras/unlocks, no máximo a cada 60 s enquanto dirty e ao sair. HP alterado também marca o save como dirty.

Reveals atuais são determinísticos e não precisam de campo extra no save: o estado é reconstituído de níveis, equipamento, pops e tiers já persistidos. Isso mantém saves existentes compatíveis e impede duplicação de estado.

## Dados e extensões

`GameBalanceData` contém fórmulas de dano, críticos, combo, custo, tick de automação, frequência/duração de specials e buffs. A curva de Click Damage possui uma tabela data-driven de custos iniciais e uma fórmula exponencial somente após esse estágio; o dano permanece linear. `BalloonData` contém dados de tier, HP, recompensa, requisitos, cor e efeito de special. `EquipmentData` contém requisitos de tier, níveis e milestones; `EquipmentService` calcula seus multiplicadores sem envolver o `Balloon`.

Click Damage é ilimitado (`click_upgrade_max_level = 0`). `BalanceService` centraliza dano, custo e milestones, e `UpgradeService` interpreta zero como ausência de teto; a UI apenas consulta esses resultados. Saves preservam qualquer nível existente sem migração adicional.

Críticos, combo, buffs, globais, Diamonds, especiais, equipamentos posteriores e boss são extensões planejadas. O boss continua um único alvo e pode reutilizar `Balloon` ou uma scene específica compatível com o mesmo fluxo de dano/recompensa.

## Performance

Há um único `Balloon` Control, um timer de Auto DPS, dois timers centralizados de specials e timers de save/playtime/buff. Nenhum sistema de gameplay roda em `_process()`. Eventos usam sinais e referências locais, sem buscas repetidas na SceneTree.

## Áudio — Milestone 8

`AudioManager` é um Autoload independente de gameplay. Ele cria os buses `Music`, `SFX` e `UI` além do `Master` da engine, mantém pools de seis vozes SFX, três vozes UI e dois players de música para crossfade. Eventos de apresentação são emitidos somente após ações válidas: clique manual, crítico, pop, compra, milestone, reveal, tier, special, buff, boss e vitória. Auto DPS não emite hit SFX.

O recorte usa streams procedurais originais somente nos feedbacks ainda sem asset final (`hit`, `critical`, `purchase`, `diamond`, `boss_pop`, `victory` etc.). Os pops normais e as músicas de menu, gameplay e boss usam OGGs organizados em `assets/audio`. Nenhuma regra ou respawn aguarda áudio.

Hit, pop, compra e UI possuem cooldown e pitch controlado; o pool não instancia players por ação e descarta uma voz se todas estiverem ocupadas. Isso preserva legibilidade sonora em Auto DPS alto. `GameState.settings` já persiste `master_volume`, `music_volume` e `sfx_volume`; o HUD aplica sliders de 0–100%, salva pela `GameSession` e aplica os buses imediatamente.

As faixas licenciadas do jogo ficam em `assets/audio/music/`: `menu_theme.ogg` alimenta o estado `menu`, `gameplay_theme.ogg` o estado `gameplay` e `balloon_king_theme.ogg` o estado `boss`. Todas são `AudioStreamOggVorbis` em loop no mesmo pool de dois players e bus `Music`; `play_menu_music()`, `play_gameplay_music()` e `start_boss_music()` usam crossfade de 0,55 s e não reiniciam o estado já ativo. A vitória conserva seu estado existente.

O pop normal escolhe uniformemente `balloon_pop_01`, `balloon_pop_02` ou `balloon_pop_03` em `assets/audio/sfx/`, usando o pool SFX existente, pitch de 0,96–1,04 e cooldown de 45 ms. A chamada continua conectada somente ao sinal de pop confirmado do `BalloonController`, portanto cliques e ticks de Auto DPS não emitem pop antes de o HP chegar a zero; Auto DPS ainda dispara o mesmo sinal ao concluir o estouro. O antigo stream procedural `pop` não é mais usado. Ataques manuais — inclusive os ticks do Hold to Click — emitem o feedback de hit por um único sinal da `GameSession`, sujeito ao cooldown normal do SFX.

## Entrada e Main Menu

`main_menu.tscn` é a cena inicial. Ela consulta `SaveManager.has_valid_save(catalog)` antes de apresentar Continue; save malformado não é carregado nem habilita o fluxo de campanha. `GameFlow` é um Autoload transitório que transporta somente o modo de entrada (`Continue`, `New Game` ou `Endless`) através da troca de cena. Ele não persiste progressão e o `SaveManager` continua sendo a fonte de verdade para a existência, conclusão e disponibilidade de Endless.

New Game cria um `GameState` limpo e preserva apenas Master, Music e SFX do save válido anterior. A confirmação utiliza `SaveManager.reset_save_confirmed`, que também é o caminho de recuperação seguro para um save inválido. Endless só aparece se `endless_unlocked` estiver persistido e, ao entrar em `game.tscn`, solicita o modo Endless existente ao `GameSession` sem alterar suas fórmulas ou regras de campanha.

O menu aplica a `PopTheme`, usa painéis e transições de fade curtas, e mantém Settings e Credits como subpainéis. Settings aplica os mesmos buses de áudio imediatamente. `SaveManager` mantém um pequeno arquivo de preferências de áudio separado do save de campanha, mas continua espelhando os valores no estado para compatibilidade; portanto, abrir Settings antes de iniciar uma campanha não cria um save de progresso. `PopCredits` centraliza o texto usado tanto pelo menu quanto pela Victory Overlay. O menu não inicializa balões de gameplay; as formas decorativas e o fundo são exclusivamente de apresentação.

Durante gameplay, `MainHUD` fornece um Pause Overlay aberto por Escape ou pelo botão de pausa. O SceneTree pausa timers e gameplay, enquanto `Game` e `MainHUD` usam processamento `ALWAYS` para manter Resume, Settings, Main Menu e Quit interativos. Main Menu força um save imediato, retoma a árvore e usa o fade de cena antes de retornar a `main_menu.tscn`; o Victory Overlay não pode abrir pausa.

## Preferências e build de playtest

`SaveManager` mantém preferências fora da campanha em `user://pop_balloon_settings.json`. Além dos volumes de áudio espelhados para compatibilidade em `GameState`, o arquivo contém `fullscreen` e `vsync`; essas opções são aplicadas no boot e podem ser alteradas tanto no menu quanto nas Settings da pausa. Preferências válidas sobrevivem a save de campanha ausente ou malformado. Um save inválido não é sobrescrito automaticamente: a sessão informa a recuperação e somente New Game confirmado pode substituí-lo.

O metadata de release vem de `project.godot` (`0.9.0-playtest`) e o preset Windows Desktop exporta para `build/windows/POP Balloon.exe` com PCK embutido. Créditos, proveniência de terceiros, checklist de playtest e limitações verificadas ficam respectivamente em `THIRD_PARTY_ASSETS.md`, `PLAYTEST_CHECKLIST.md` e `KNOWN_ISSUES.md`.

## Recorte implementado

Red, Blue, Green, Purple, Dark e Rainbow funcionam como tiers sequenciais. Diamonds são concedidos apenas pelo evento Crystal; a frequência desse evento possui upgrade próprio comprado com Diamonds.

## Late game

## Apresentação — Milestone 7

O HUD usa uma área de jogo separada da loja lateral com abas e rolagem. Cards reutilizam os botões e sinais de compra existentes; tema, formatação numérica e feedback visual são componentes de apresentação. Requisitos usam dados reais, conteúdo HIDDEN permanece ausente e vitória oculta o HUD. A documentação da direção visual, auditoria, limites e testes está em [UI_DESIGN.md](UI_DESIGN.md). Nenhuma fórmula de gameplay ou versão de save foi alterada por este redesign.

### Sistemas de late game existentes

Balloon Popping Machine, PopBot e Anti-Balloon Cannon usam `EquipmentData` e `EquipmentService` sem lógica exclusiva. Rainbow é outro `BalloonData.NORMAL`, com requisito data-driven de PopBot. `GameSession.is_ready_for_balloon_king()` exige Rainbow + Cannon Lv. 1. Balloon King reutiliza `BalloonController`, persiste HP/fase, suspende novos Specials e marca campanha/Endless ao pop. Victory/Credits só é apresentado pelo evento de vitória atual; carregar um save concluído entra no jogo normalmente. Endless preserva a lista completa de tiers desbloqueados e a navegação Previous/Next.

## External playtest feedback pass

`NumberFormat` centraliza inteiros, uma casa decimal, percentuais, multiplicadores e abreviações K/M/B/T/Q. A loja mantém BuyMode em sessão (`ONE`, `TEN`, `MAX`) e executa compras nível a nível, respeitando custo crescente, moeda e cap. `UpgradeCard` responde a hover em toda sua área sem interceptar o botão e oculta a barra ao atingir MAX. Statistics lê contadores reais do `GameState`. Hold to Click usa estado de botão e alvo válido, sendo cancelado por release, saída do balão, foco, pause, overlays, pop e troca de cena.
