# POP Balloon — Technical Design

**Status:** arquitetura técnica da versão 1.0  
**Fontes de verdade:** `GAME_DESIGN.md` define a experiência; `BALANCE.md` define números e ritmo; este documento define a implementação.  
**Projeto verificado:** Godot 4.7, renderer GL Compatibility, `canvas_items` + `expand` para stretch.

Este documento descreve a menor arquitetura capaz de suportar a campanha completa de POP Balloon. Não adiciona regras de game design ou valores de balanceamento; quaisquer números mencionados devem ser lidos de `BALANCE.md` e configurados em dados estáticos.

## 1. Stack and Constraints

- **Engine:** Godot 4.7 (Godot 4.x).
- **Linguagem:** GDScript 2.0 tipado.
- **Formato:** jogo 2D de interface e apresentação visual.
- **Plataforma inicial:** PC/desktop, single-player.
- **Persistência:** arquivo local em `user://`.
- **Renderização inicial:** GL Compatibility, conforme `project.godot`.
- **Fora da stack:** C#, C++, GDExtension, backend, contas online, cloud save, multiplayer e analytics remoto.

APIs e sintaxe devem ser compatíveis com Godot 4.x; não usar padrões de Godot 3.x.

## 2. Architectural Principles

- Um `GameSession` da scene de jogo coordena a partida; ele não é Autoload.
- `GameState` é a fonte de verdade do estado runtime e persistente; UI apenas o apresenta.
- Dados repetíveis vivem em Resources estáticos; níveis, moedas e HP atual vivem no estado runtime.
- Services pequenos cuidam de economia, upgrades, equipamentos, progressão, combate, buffs e estatísticas. Eles não precisam ser Nodes nem singletons por padrão.
- `Balloon` apresenta e recebe dano; não concede moedas, compra upgrades nem salva.
- A UI atualiza por signals e chamadas de apresentação explícitas, nunca por polling geral em `_process()`.
- Fórmulas de `BALANCE.md` ficam centralizadas em uma única camada de balanceamento.
- Efeitos visuais e áudio recebem resultados de gameplay; não determinam regras de gameplay.

## 3. Project Structure

```text
res://
├── autoload/
│   ├── save_manager.gd
│   └── audio_manager.gd
├── scenes/
│   ├── main/
│   │   ├── main_menu.tscn
│   │   └── game.tscn
│   ├── balloons/
│   │   └── balloon.tscn
│   ├── ui/
│   │   ├── main_hud.tscn
│   │   ├── upgrade_panel.tscn
│   │   ├── equipment_panel.tscn
│   │   ├── progression_panel.tscn
│   │   ├── notification_layer.tscn
│   │   ├── pause_menu.tscn
│   │   └── victory_overlay.tscn
│   └── effects/
│       ├── damage_number.tscn
│       └── pop_effect.tscn
├── scripts/
│   ├── game/
│   │   ├── game_session.gd
│   │   ├── game_state.gd
│   │   ├── balance_service.gd
│   │   ├── combat_resolver.gd
│   │   ├── buff_service.gd
│   │   └── statistics_service.gd
│   ├── balloons/
│   │   ├── balloon.gd
│   │   └── balloon_controller.gd
│   ├── services/
│   │   ├── economy_service.gd
│   │   ├── equipment_service.gd
│   │   ├── upgrade_service.gd
│   │   ├── progression_service.gd
│   │   └── achievement_service.gd
│   ├── resources/
│   │   ├── game_balance_data.gd
│   │   ├── content_catalog_data.gd
│   │   ├── balloon_data.gd
│   │   ├── equipment_data.gd
│   │   ├── buff_data.gd
│   │   └── achievement_data.gd
│   ├── ui/
│   ├── effects/
│   └── utils/
│       └── number_formatter.gd
├── data/
│   ├── balance/
│   ├── balloons/
│   ├── equipment/
│   ├── buffs/
│   └── achievements/
└── assets/
    ├── sprites/
    ├── audio/
    ├── fonts/
    └── particles/
```

`scripts/resources/` contém as classes de Resource; `data/` contém suas instâncias configuradas. Essa separação permite alterar conteúdo sem misturar as classes que leem os dados com os próprios dados. Nenhuma pasta deve ser criada antes de uma feature realmente precisar dela.

## 4. Scenes and Game Flow

### Entry and transition model

- **Entrada planejada:** `main_menu.tscn`.
- **Partida:** `game.tscn`, criada ao escolher Play/Continue ou New Game.
- **Vitória:** `victory_overlay.tscn` sobre a partida, não uma scene de jogo independente. Isso preserva estatísticas e permite abrir Endless sem recriar o estado.
- **Pausa:** `pause_menu.tscn` como overlay da partida.

Não é necessário um roteador global de scenes. O menu inicia a partida e a própria `Game` controla overlays locais. O menu futuro contém apenas Continue/Play, New Game/Reset com confirmação, Settings e Quit.

### Game scene composition

```text
Game (Control) [game.gd: apresentação e referências de alto nível]
├── GameSession (Node) [game_session.gd: coordenação runtime]
│   ├── AutoDamageTimer
│   ├── ComboGraceTimer
│   ├── ComboDecayTimer
│   ├── BuffTimer
│   ├── PlaytimeTimer
│   └── AutosaveTimer
├── GameView (Control)
│   ├── BalloonArea (Control)
│   │   ├── BalloonContainer (Control)
│   │   └── SpecialBalloonLayer (Control)
│   └── GameplayEffects (Control)
├── UI (Control)
│   ├── MainHUD
│   ├── UpgradePanel
│   ├── EquipmentPanel
│   ├── ProgressionPanel
│   └── BuffDisplay
└── OverlayLayer (CanvasLayer)
    ├── NotificationLayer
    ├── PauseMenu
    └── VictoryOverlay
```

`GameSession` é o controlador de fluxo da partida e proprietário dos serviços runtime. `Game.gd` não deve conter fórmulas, saldo ou regras de progressão; ele apenas liga scene, sessão e UI. `GameView` e UI são apresentação. Timers centralizados mantêm sistemas temporais fora de dezenas de Nodes individuais.

### Scene responsibilities

| Scene | Responsabilidade |
|---|---|
| `main_menu.tscn` | Iniciar/carregar sessão, abrir settings e pedir confirmação de reset |
| `game.tscn` | Compor sessão, área jogável, HUD e overlays |
| `balloon.tscn` | Apresentar um alvo clicável, HP local e feedback de dano/pop |
| `main_hud.tscn` | Coins, Diamonds, dano, Auto DPS, combo e HP atual |
| `upgrade_panel.tscn` | Mostrar e solicitar compras dos três upgrades |
| `equipment_panel.tscn` | Mostrar equipamentos, preço, nível e DPS |
| `progression_panel.tscn` | Próximo tier, requisitos e progresso |
| `notification_layer.tscn` | Unlocks, conquistas, compras e mensagens curtas |
| `victory_overlay.tscn` | Conclusão, estatísticas, créditos e acesso ao Endless |
| `damage_number.tscn` / `pop_effect.tscn` | Efeitos descartáveis, sem regra de economia ou progressão |

Não criar uma scene para cada label ou botão. Componentes são agrupados por responsabilidade visual.

## 5. Runtime State and Ownership

`GameState` é uma classe runtime simples, de propriedade de `GameSession`. Não é um singleton e não pertence à UI. Ela contém o estado autoritativo da sessão:

```text
currency
  coins
  diamonds

upgrades
  click_damage_level
  critical_chance_level
  critical_damage_level

equipment_levels
  { equipment_id: level }

progression
  current_normal_balloon_id
  current_balloon_health
  normal_variation_index
  unlocked_balloon_ids
  current_tier_id
  boss_unlocked
  campaign_completed
  endless_unlocked

statistics
  clicks
  balloons_popped
  special_balloons_popped
  coins_earned
  diamonds_earned
  total_damage
  largest_critical
  active_play_seconds

runtime_only
  combo_stacks
  active_buffs
  active_special_balloon
  pause_state
```

`current_balloon_health` é persistido para que sair no meio de um balão normal não reinicie a meta. Combo, buffs em andamento, especiais visíveis, tweens, partículas e efeitos de áudio não são persistidos: ao carregar, o balão normal é restaurado e estados temporários expiram de forma segura.

Os serviços recebem `GameState` por referência da sessão. Eles não armazenam uma segunda cópia de Coins, níveis ou estatísticas.

## 6. Autoloads

| Autoload | Decisão | Responsabilidade |
|---|---|---|
| `SaveManager` | Sim | Ler, validar, versionar, serializar, gravar e resetar snapshots de `GameState` |
| `AudioManager` | Sim | Persistir música/SFX entre menu e jogo, controlar buses e variações de som |
| `GameState` | Não | É exclusivo de uma sessão e deve ser fácil de recriar/testar |
| Economy/Equipment/Upgrade/Progression services | Não | São serviços da `GameSession`, sem necessidade global |
| BalloonController | Não | Controla somente a partida atual |

`SaveManager` é global porque precisa sobreviver a transições e lidar com o arquivo local. `AudioManager` justifica-se porque música, volumes e SFX passam por menu, jogo e vitória. Nenhum outro manager deve virar singleton sem uma necessidade global demonstrável.

## 7. Static Content Resources

### Content catalog

`ContentCatalogData` é um Resource único de composição, exportado para a `GameSession` ou scene `Game`. Ele referencia o balance global e as listas ordenadas de balões, equipamentos, buffs e conquistas. Isso evita caminhos de carregamento repetidos e centraliza a validação de IDs no início da sessão.

### Planned Resource classes

| Resource | Uso estático |
|---|---|
| `GameBalanceData` | Fórmulas e tabelas de `BALANCE.md`: custos, limites, combo, variação de HP, especiais e fases do boss |
| `BalloonData` | Dados de balões normais, especiais e boss: ID, categoria, nome, tier, HP/recompensa base, visual e configuração específica |
| `EquipmentData` | ID, nome, descrição, ícone, Base DPS, Base Cost, nível máximo e tier de unlock |
| `BuffData` | ID, alvo/modificador, duração, multiplicador e regra de renovação |
| `AchievementData` | ID, título, condição simples, recompensa e texto de notificação |
| `ContentCatalogData` | Referências às instâncias anteriores, em ordem de progressão |

`UpgradeData` não é necessário inicialmente. Existem apenas três upgrades fixos, com fórmulas e tabelas diferentes; seus IDs e valores pertencem ao `GameBalanceData`, e `UpgradeService` os trata explicitamente. Isso é mais claro que um framework genérico para três casos conhecidos.

### BalloonData fields

Um único `BalloonData` usa uma enum curta (`NORMAL`, `SPECIAL`, `BOSS`) para manter a mesma scene reutilizável, sem hierarquia de classes. Campos comuns e específicos devem ser validados conforme a categoria:

```text
id, display_name, category, texture, visual_variant
base_health, coin_reward, diamond_reward

normal: tier, unlock requirements
special: spawn_weight, health_ratio, display_duration, buff_id
boss: phase thresholds
```

O `GameBalanceData` permanece a fonte das fórmulas; `BalloonData` armazena apenas configuração de conteúdo. Golden Balloon normal e Golden Special Balloon possuem IDs e categorias distintos.

### Static data versus runtime state

| Static data | Runtime state |
|---|---|
| HP/recompensa base, fórmula de custo, Base DPS, limites, requisitos, textura | Coins, Diamonds, níveis comprados, HP atual, combo, buffs, estatísticas, unlocks |

Resources compartilhados nunca são alterados para registrar progresso de uma partida. Uma compra muda `GameState.equipment_levels`, não `EquipmentData`.

## 8. Core Runtime Services

| Serviço | Responsabilidade | Não deve fazer |
|---|---|---|
| `BalanceService` | Centralizar cálculo de dano, custo, DPS, reward, HP efetivo e formatação de valores de balanceamento | Atualizar UI ou salvar |
| `EconomyService` | Validar e adicionar/gastar Coins e Diamonds | Conhecer Labels ou Balloon visual |
| `UpgradeService` | Comprar níveis de Click Damage, Critical Chance e Critical Damage | Duplicar fórmulas |
| `EquipmentService` | Validar unlocks, comprar níveis e calcular Auto DPS total | Criar um script por equipamento |
| `ProgressionService` | Avaliar gates, tier atual, boss, campanha e Endless | Controlar efeitos visuais |
| `CombatResolver` | Produzir resultado de ataque manual/automático | Instanciar balões ou conceder recompensa |
| `BuffService` | Ativar, renovar, expirar e consultar poucos buffs ativos | Virar framework genérico de RPG |
| `StatisticsService` | Registrar contadores e marcos de sessão | Ser controlado pela UI |
| `AchievementService` | Avaliar poucas condições e conceder recompensa definida | Criar plataforma online de achievements |
| `BalloonController` | Escolher, configurar, substituir e observar balão normal/especial/boss | Ser o dono de moeda ou save |

Esses serviços podem ser classes `RefCounted` tipadas, criadas por `GameSession`. Timers e scenes ficam nos Nodes que os possuem; a lógica de cálculo deve permanecer testável sem depender de Controls.

## 9. Damage, Critical and Combo Flow

### Manual attack

```text
Balloon GUI click
  → GameSession registra click e atualiza Combo
  → CombatResolver calcula base Click Damage
  → aplica combo ativo
  → sorteia crítico com dados de GameBalanceData
  → retorna AttackResult { damage, was_critical, combo_multiplier }
  → Balloon.take_damage(damage)
  → UI/effects recebem AttackResult para feedback
```

`AttackResult` pode ser uma pequena classe tipada de transporte, com campos como `damage: float`, `was_critical: bool` e `combo_multiplier: float`. Ela evita recalcular crítico em UI e efeitos, sem introduzir uma camada genérica de eventos.

### Automatic attack

```text
AutoDamageTimer (0.25 s)
  → EquipmentService retorna total_auto_dps
  → CombatResolver converte para total_auto_dps × 0.25
  → Balloon.take_damage(damage)
```

O timer central aplica quatro ticks por segundo. Dano é `float` internamente; a UI pode exibir valores arredondados. Se um balão morrer no meio do tick, o `Balloon` encerra a transação com `is_popped`; qualquer overkill não passa para o próximo balão. O próximo alvo aparece pelo fluxo de pop antes do tick seguinte, eliminando duplicação e dano em alvo removido.

### Critical ownership

Critical Chance e Critical Damage são lidos pelo `CombatResolver` a partir de `GameState` e `BalanceService`. `Balloon` só recebe o dano final e o metadado necessário para reação visual. A UI nunca sorteia ou calcula crítico.

### Combo ownership and decay

Combo fica em `GameState.runtime_only.combo_stacks` e é alterado por `GameSession` ao receber clique válido. O fluxo segue os valores de `BALANCE.md`:

- a cada oito cliques válidos, aumentar uma stack, até dez;
- `ComboGraceTimer` inicia após 1.5 s sem clique válido;
- ao expirar, `ComboDecayTimer` remove uma stack por segundo até zero;
- cada mudança emite `combo_changed`, para a UI atualizar apenas quando necessário.

Não há `_process()` por balão ou widget para controlar combo.

## 10. Balloon Architecture

### Reusable balloon scene

```text
Balloon (Control) [balloon.gd]
├── Visual (TextureRect)
├── AnimationPlayer
├── FeedbackAnchor (Control)
└── LocalEffectAnchor (Control)
```

O HP principal é apresentado pelo `BalloonHUD` da HUD, para manter layout e leitura consistentes. O `Balloon` pode expor uma indicação local simplificada, mas não deve duplicar a lógica de HUD.

`Balloon.gd` é responsável por:

- receber `BalloonData` e HP efetivo;
- manter `current_health` e `is_popped`;
- aceitar dano uma única vez por ataque;
- emitir dano e pop;
- disparar squash, pop e hooks locais de feedback;
- bloquear novos cliques depois do pop.

Ele não adiciona Coins, avalia requisitos, compra upgrades, calcula DPS global ou grava save.

### Click handling choice

O root `Balloon` será um `Control` customizado e tratará `gui_input` de clique esquerdo. Essa opção é preferível a `Area2D` porque a experiência é uma interface 2D organizada por Containers e a área do balão precisa coexistir com HUD, overlays e controle de foco de UI. Um `Button` padrão não é necessário: o visual e a animação do balão são altamente customizados.

O Control deve usar `mouse_filter` apropriado, aceitar somente clique pressionado dentro da área visível e emitir um signal de intenção de ataque. Latência de input e feedback local devem ocorrer no mesmo evento, enquanto a regra de dano continua centralizada na sessão.

### BalloonController

`BalloonController` é um Node da `GameSession` que:

- resolve o `BalloonData` do tier atual pelo catálogo;
- aplica a sequência de variação de HP do `GameBalanceData`;
- instancia e configura o balão normal em `BalloonContainer`;
- apresenta especiais em `SpecialBalloonLayer`, sem substituir o balão normal;
- limpa referências após pop/despawn;
- inicia o Balloon King quando `ProgressionService` liberar a transição.

Ao receber `popped`, ele emite um evento de domínio ao `GameSession`. A sessão então chama Economy, Statistics, Progression, Achievement e feedback na ordem apropriada. Isso mantém `BalloonController` focado em ciclo de vida de alvo.

## 11. Equipment, Upgrades and Economy

### Equipment

`EquipmentService` usa `EquipmentData` + `GameState.equipment_levels`. Ele resolve disponibilidade, custo de próximo nível, compra validada e `total_auto_dps`. Todos os equipamentos compartilham a fórmula de `BALANCE.md`; adicionar um novo equipamento requer principalmente um novo Resource e entrada no catálogo, não um novo script de comportamento.

### Upgrades

`UpgradeService` mantém três caminhos explícitos por enum: `CLICK_DAMAGE`, `CRITICAL_CHANCE` e `CRITICAL_DAMAGE`. Essa escolha é intencionalmente simples: há somente três upgrades e cada um tem tabela/fórmula distinta. `BalanceService` calcula valor atual, máximo e próximo custo; o painel apenas solicita a compra pelo ID.

### Economy transaction flow

```text
UI solicita compra
  → Service consulta BalanceService
  → EconomyService.try_spend_coins(cost)
  → Service altera nível/estado somente após gasto bem-sucedido
  → signals de saldo e item alterado
  → UI atualiza e SaveManager é marcado como dirty
```

`try_spend_coins` falha sem alterar estado se o saldo for insuficiente. A compra deve ter uma trava curta de transação para que dois eventos de botão no mesmo frame não comprem duas vezes. Buttons nunca subtraem Coins diretamente.

## 12. Progression, Specials and Buffs

### Progression

`ProgressionService` consulta `GameState`, `BalloonData` e `GameBalanceData` para avaliar:

- pops e Coins exigidos por tier;
- próximo objetivo e progresso exibível;
- unlock de balões/equipamentos;
- elegibilidade do boss;
- conclusão de campanha e liberação do Endless.

Ele emite uma descrição de objetivo simples para `ProgressionPanel`, sem depender de Labels ou de detalhes visuais. A UI só apresenta progresso recebido.

### Special balloons

Especiais reutilizam `balloon.tscn` e `Balloon.gd`, configurados com `BalloonData.category == SPECIAL`. Não há subclasses nem scenes específicas por tipo.

Um scheduler central da `GameSession` controla a próxima oportunidade de especial. Ele usa o intervalo aleatório entre 150 e 210 s, a média de 180 s e os pesos definidos em `BALANCE.md`. Ao criar um especial:

- `BalloonController` calcula HP como fração do HP base normal atual;
- instancia o alvo em `SpecialBalloonLayer`;
- inicia um timer de duração de 10 s;
- se o alvo expirar, remove apenas o especial;
- se for estourado, a sessão concede reward e ativa o buff associado quando houver.

O balão normal fica visível e preserva HP durante todo o evento.

### Buffs

`BuffService` mantém somente os buffs ativos definidos em `BuffData`. Cada buff tem ID, multiplicador, duração e política de renovação. Para a versão 1.0:

- Electric: Auto DPS ×1.50 por 20 s;
- Frenzy: Click Damage ×1.35 e combo mínimo 1.25x por 15 s;
- nova obtenção do mesmo buff renova a duração em vez de acumular.

Um único `BuffTimer`, com intervalos curtos e previsíveis, atualiza expirações. `BuffService` expõe multiplicadores para `CombatResolver` e `EquipmentService`, emitindo signals apenas em início, mudança visual relevante e fim. Não há framework de buffs genérico nem um Timer por buff.

## 13. Boss and Endless Architecture

### Balloon King

O Balloon King reutiliza `Balloon.tscn`, `Balloon.gd`, dano e recompensa normais com `BalloonData.category == BOSS`. Somente a apresentação e a HUD recebem extensões necessárias:

- transição de `ProgressionService` troca o balão normal pelo boss;
- `BalloonHUD` usa estilo de barra especial;
- thresholds de HP vêm do dado de boss/balance e emitem eventos de fase;
- as fases são visuais, conforme `BALANCE.md`, sem penalidade de DPS nem mecânica inédita;
- ao pop, `GameSession` registra vitória, autosalva, mostra `VictoryOverlay` e libera Endless.

### Endless

Endless não cria outro loop ou outro conjunto de sistemas. Reutiliza `GameSession`, BalloonController, combat, economy, upgrades e equipamentos. Depois da vitória, `ProgressionService` troca a fonte de seleção de balão para uma progressão escalável de Endless. Prestige, nova moeda e regras específicas de Endless permanecem fora da primeira implementação de campanha.

## 14. UI Architecture and Signals

### UI responsibilities

| Componente | Observa | Ação permitida |
|---|---|---|
| TopBar/MainHUD | Coins, Diamonds, DPS, HP, combo | Apenas exibir |
| UpgradePanel | UpgradeService e EconomyService | Solicitar compra |
| EquipmentPanel | EquipmentService e EconomyService | Solicitar compra |
| ProgressionPanel | ProgressionService | Mostrar objetivo e requisito |
| BuffDisplay | BuffService | Mostrar duração/ícone |
| NotificationLayer | unlocks, conquistas, compras e especiais | Apresentar mensagem |
| VictoryOverlay | Statistics, completion | Mostrar resultado e ação de Endless |

Cada painel recebe referências públicas da sessão ou um adaptador pequeno de apresentação quando a scene é montada. Nenhum painel procura sistemas por caminhos longos pela árvore.

### Main signals

| Signal | Emissor | Ouvintes típicos |
|---|---|---|
| `balloon_damaged(current_health, max_health, attack_result)` | Balloon | BalloonHUD, effects |
| `balloon_popped(balloon_id, category)` | Balloon | GameSession/BalloonController |
| `coins_changed(value)` / `diamonds_changed(value)` | EconomyService | TopBar, lojas |
| `upgrade_changed(kind, level)` | UpgradeService | UpgradePanel, HUD |
| `equipment_changed(id, level, total_auto_dps)` | EquipmentService | EquipmentPanel, HUD |
| `objective_changed(objective)` | ProgressionService | ProgressionPanel |
| `tier_unlocked(id)` / `boss_unlocked()` | ProgressionService | NotificationLayer, GameSession |
| `combo_changed(stacks, multiplier)` | GameSession | HUD, effects |
| `buff_started(id)` / `buff_ended(id)` | BuffService | BuffDisplay, effects |
| `achievement_unlocked(id)` | AchievementService | NotificationLayer |
| `campaign_completed()` | ProgressionService | GameSession, VictoryOverlay |

Conexões são explícitas dentro da `GameSession` e da scene UI. Não usar event bus global: os emissores e ouvintes já têm relação de domínio clara.

### Event-driven update rule

Valores de UI mudam quando services emitem signals. Por exemplo, `coins_changed` atualiza o label de Coins; `balloon_damaged` atualiza a barra de HP. `_process()` não atualiza strings, custos ou barras em todos os frames. Apenas animações, Tweens ou o indicador de duração de buff podem ter atualização visual limitada e centralizada.

## 15. Save System

### Format and location

`SaveManager` usa um Dictionary serializável em JSON, salvo em:

```text
user://pop_balloon_save.json
```

JSON é suficiente para o escopo: é portátil, legível durante debug e fácil de versionar. O save armazena snapshot de dados, nunca Nodes, Resources compartilhados, caminhos de scene ou referências de UI.

### Save schema (version 1)

```text
save_version: 1

currency:
  coins
  diamonds

upgrades:
  click_damage_level
  critical_chance_level
  critical_damage_level

equipment_levels:
  { equipment_id: level }

progression:
  current_normal_balloon_id
  current_balloon_health
  normal_variation_index
  unlocked_balloon_ids
  boss_unlocked
  campaign_completed
  endless_unlocked

statistics:
  clicks
  balloons_popped
  special_balloons_popped
  coins_earned
  diamonds_earned
  total_damage
  largest_critical
  active_play_seconds

settings:
  master_volume
  music_volume
  sfx_volume
```

Não salvar combo, buffs, especial em tela, Timer, Tween, partículas, referências de Nodes, estado de animação ou pause. Esses itens são transitórios e são recriados/expirados ao carregar.

### Versioning, corruption and reset

- `save_version` é validado antes de aplicar dados.
- Uma versão antiga é detectada e encaminhada a uma função de migração simples, por versão, quando necessária no futuro.
- Save inexistente cria `GameState` padrão a partir do catálogo.
- Save malformado, tipo inválido ou ID de conteúdo ausente gera log claro e não é apagado automaticamente. A UX futura deve oferecer recuperação/reset com confirmação; uma cópia de segurança pode ser criada antes de qualquer substituição.
- New Game/Reset exige confirmação explícita e somente então grava um snapshot novo. Não há slots múltiplos na 1.0.

### Autosave policy

- Salvar imediatamente após compra, unlock, vitória, reset confirmado e alteração de settings.
- Marcar o estado como dirty após pop/recompensa; o `AutosaveTimer` grava no máximo a cada 60 s enquanto dirty.
- Tentar um último save dirty no encerramento da aplicação.
- Nunca salvar a cada clique, tick de Auto DPS ou frame.

Essa política protege progressão importante sem escrita contínua em disco.

## 16. Statistics, Achievements, Time and Debug

`StatisticsService` é o único ponto que incrementa contadores de gameplay. Outros sistemas informam eventos; UI apenas lê o estado. `PlaytimeTimer` avança uma vez por segundo somente enquanto gameplay não está pausado, sem usar relógio do sistema como duração ativa.

`AchievementService` consulta `AchievementData` e marcos explícitos de Statistics/Progression. Ele precisa suportar somente as conquistas da versão 1.0 e recompensas pequenas de Diamonds; não há integração de plataforma online.

### Development-only balance support

Depois que o loop existir, uma `DebugPanel` discreta pode ser incluída apenas em builds de desenvolvimento. Ela chama métodos públicos controlados da `GameSession` para:

- adicionar Coins ou Diamonds;
- definir tier ou poder;
- spawnar especial;
- iniciar boss;
- mostrar Click DPS, Auto DPS, combo, economia e HP;
- resetar save com confirmação.

Não é necessário console, cheat menu de release ou framework de comandos.

### Local balance trace

Em builds de debug, `StatisticsService`/GameSession pode manter e exportar um log local de marcos: timestamp de tier, TTK, renda/min, DPS manual/auto, compras, início/fim do boss e conclusão. Não há envio de dados a servidor.

## 17. Presentation, Audio and Input

### Visual effects

`GameplayEffects` instancia `damage_number.tscn` e `pop_effect.tscn` a partir de eventos com dados prontos, como `AttackResult`, posição e reward. Eles animam e se removem ao terminar. Efeitos não alteram HP, Coins, buffs ou progressão. Instanciação simples é suficiente para a escala 1.0; pooling só deve ser considerado após profiling real.

### Animation policy

| Ferramenta | Uso planejado |
|---|---|
| Tween | Squash do balão, microfeedback de compra, números flutuantes e movimentos pequenos |
| AnimationPlayer | Introdução do boss, sequência de vitória e apresentações de unlock maiores |
| Particles | Pop, crítico, moedas e momentos especiais |

Gameplay confirma dano, recompensa ou unlock antes do efeito. Nenhuma regra econômica ou de progressão depende do fim de uma animação frágil.

### Audio

`AudioManager` mantém players para música e SFX, e aplica settings persistidos. Os buses planejados são apenas:

```text
Master
Music
SFX
```

SFX de pop podem escolher uma variação de uma coleção curta; crítico, compra, unlock, especial, boss e vitória têm cues próprios. A assetização pode ser simples no início e não exige um framework de áudio.

### Input

- Clique principal: tratado diretamente pelo `Balloon` Control via evento GUI.
- Input Map planejado: somente `pause` para a pausa da partida.
- O botão de pause e `pause` ativam a mesma ação de sessão.

Pausar congela gameplay, AutoDamageTimer, Combo timers, BuffTimer e PlaytimeTimer; overlays de UI podem continuar responsivos. Não criar bindings extras sem feature que os justifique.

## 18. Resolution and Layout

A resolução base planejada é **1280×720**, adequada à apresentação horizontal de PC e à prioridade visual do balão central. O projeto já usa `canvas_items` + `expand`; quando a UI for implementada, configurar a base no Project Settings sem mudar a estratégia de stretch existente.

Todos os painéis usam anchors e Containers. `BalloonArea` recebe a maior área central; lojas e metas se organizam em painéis inferiores/laterais responsivos. Coordenadas absolutas só são aceitáveis para efeitos locais ancorados ao balão, nunca como mecanismo geral de layout.

## 19. Error Handling and Testability

### Error handling

- **Resource ausente ou ID inválido:** emitir erro útil em debug e impedir a criação daquele conteúdo; nunca substituir por números arbitrários silenciosamente.
- **BalloonData inválido:** validar HP, reward e categoria ao carregar o catálogo; usar assertions em debug para invariantes de desenvolvimento.
- **Saldo/custo inválido:** `EconomyService` recusa a transação e não altera estado.
- **Save ausente/corrompido:** aplicar as regras da seção de save, preservando o arquivo original até o usuário confirmar recuperação/reset.

### Testability

`BalanceService`, Economy, Equipment, Upgrade, Progression e CombatResolver devem aceitar dados e `GameState` sem depender de Controls. Isso permite validação futura de fórmula, TTK, gates e compra em testes de script ou simulação sem abrir a UI.

`GameSession` é o local de composição; ele não deve esconder regras de cálculo em callbacks de scene. Essa separação torna possível criar um estado conhecido, executar uma ação e verificar resultado de forma determinística, exceto pela semente/resultado de crítico que deve poder ser controlado em debug.

## 20. GDScript Conventions and Dependency Rules

### Conventions

- `PascalCase` para classes, `snake_case` para variáveis, funções, arquivos e signals.
- GDScript tipado para propriedades, parâmetros, retornos e collections quando aplicável.
- `class_name` em classes reutilizáveis de Resource, state e services.
- `@export` para configuração de scene/catalog; `@onready` para referências de Nodes da própria scene.
- Enums curtas para categoria de balão, tipo de upgrade e estado de campanha quando trouxerem clareza.
- Signals descritivos, como `coins_changed`, `balloon_popped` e `campaign_completed`.
- Comentários explicam decisão ou limitação, não a próxima linha.

Exemplo de estilo, apenas como convenção:

```gdscript
class_name Balloon
extends Control

signal popped(balloon_id: StringName)

var current_health: float

func take_damage(amount: float) -> void:
    pass
```

### Dependencies

```text
Resources → services/state → GameSession → scenes/UI/effects
```

- UI pode depender de interfaces públicas de sessão/services, nunca de Labels como estado.
- Gameplay não depende de widgets específicos.
- Resources não dependem de UI ou runtime state.
- SaveManager serializa `GameState`; ele não decide pop, compra ou progressão.
- Balloon não conhece Economy ou SaveManager.
- Economy não conhece arte, partículas ou animações.
- BalanceService é a única origem de cálculos de `BALANCE.md` no código.

## 21. Anti-Patterns

Não fazer durante implementação:

- concentrar o jogo inteiro em `Main.gd` ou `Game.gd`;
- atualizar toda a UI em `_process()`;
- espalhar caminhos profundos de Nodes;
- criar Autoload para cada sistema;
- hardcodar tiers em `if/elif` ou escrever um script por equipamento;
- alterar Coins diretamente em Buttons;
- usar Labels como fonte de verdade;
- salvar Nodes, Tweens ou efeitos visuais;
- misturar efeitos de pop com economia ou progression;
- criar árvore de herança grande para quatro especiais e um boss;
- duplicar fórmulas de custo/dano em UI;
- preparar sistemas para multiplayer, Prestige, backend ou features fora do design;
- adicionar Timer por equipamento quando existe Auto DPS central.

## 22. Implementation Roadmap

### Phase 0 — Foundation

- Criar estrutura mínima necessária, classes de Resource e catálogo.
- Criar `GameState`, `BalanceService` e `GameSession` sem conteúdo extra.
- Validar catálogo, IDs e valores de `BALANCE.md` no início da sessão.

### Phase 1 — Core Vertical Slice

- Red Balloon visível e clicável.
- HP, dano manual, pop, Coins e próximo balão.
- Click Damage, UI mínima e Needle com Auto DPS central.
- Blue Balloon como primeiro unlock/prova de progressão.

**Resultado:** já existe um jogo mínimo clicável que valida a arquitetura de estado, dano, recompensa, compra e ciclo de balão.

### Phase 2 — Persistence and Base UI

- Estabilizar o formato de `GameState` usado pelo slice.
- Implementar SaveManager, load, autosave, reset confirmado e settings de áudio.
- Consolidar MainHUD, UpgradePanel, EquipmentPanel e ProgressionPanel event-driven.

Save entra aqui, assim que o estado do loop principal estiver estável e antes de expandir muito conteúdo persistente.

### Phase 3 — Campaign Progression

- Adicionar todos os BalloonData normais, gates e ProgressionPanel.
- Adicionar todos os EquipmentData e completar a loja.
- Validar checkpoints e fórmulas de `BALANCE.md` com dados reais.

### Phase 4 — Player Power

- Critical Chance, Critical Damage e feedback de crítico.
- Combo, timers centralizados e UI de combo.

### Phase 5 — Special Content

- Scheduler de especiais, Golden/Crystal/Electric/Frenzy.
- Diamonds, BuffService e BuffDisplay.

### Phase 6 — Boss and Victory

- Balloon King, barra especial, fases visuais, vitória e crédito/estatísticas.
- Liberação de Endless sem duplicar loop principal.

### Phase 7 — Meta and Debug

- Estatísticas, conquistas, DebugPanel de desenvolvimento e balance trace local.
- Endless básico após confirmação de que a campanha fecha corretamente.

### Phase 8 — Polish and Release

- Animações, partículas, áudio, números flutuantes e feedback de compra/unlock.
- Playtests de duração, TTK, dead zones, save e resolução.
- Profiling apenas de gargalos reais, exportação e limpeza final.

## 23. Vertical Slice Definition

O primeiro vertical slice está pronto quando contém, em uma única partida funcional:

- balão visível com HP;
- clique de baixa latência;
- dano e pop;
- Coins autoritativas no `GameState`;
- upgrade de Click Damage;
- Needle como primeiro equipamento com Auto DPS por tick central;
- HUD mínima para Coins, HP, Click Damage e Auto DPS;
- Red Balloon e Blue Balloon, com unlock e spawn do próximo alvo.

Ele prova o fluxo essencial:

```text
UI/input → GameSession/combat → Balloon → reward/progression → state → UI
```

Críticos, combo, especiais, boss, save completo e polish não devem bloquear a prova inicial do loop.

## 24. Consistency Notes and Definition of Done

### Consistency review

Não há conflito material entre `GAME_DESIGN.md` e `BALANCE.md`. A arquitetura preserva os pontos importantes dos dois documentos:

- balão especial é alvo separado e opcional, sem substituir o balão normal;
- Golden Balloon de campanha e Golden Special Balloon têm dados/IDs distintos;
- Diamonds são opcionais e não entram em gates de campanha;
- o boss reutiliza o loop de clique + automação + upgrades e tem fases somente visuais;
- a escala de milhões baixos/dezenas de milhões usa `float` e formatação K/M, sem biblioteca de big numbers;
- a campanha termina no boss; Endless apenas reutiliza sistemas existentes.

### Definition of done

Este documento está completo quando outro desenvolvedor consegue identificar:

- scenes, componentes e diretórios a criar;
- Resources estáticos e estado runtime;
- os dois Autoloads justificados;
- responsabilidades e limites de cada serviço;
- fluxo de dano, crítico, combo, Auto DPS, economia e progressão;
- estratégia de especiais, buffs, boss, UI e efeitos;
- formato, versionamento e pontos de autosave;
- ordem de implementação e critério do primeiro vertical slice.

Nenhuma parte desta arquitetura exige gameplay, scenes, scripts, Resources, Autoloads, Input Map ou configuração já implementados nesta tarefa.
