class_name Game
extends Control

@export var content_catalog: ContentCatalogData
@export var balloon_scene: PackedScene

@onready var _game_session: GameSession = %GameSession
@onready var _balloon_container: Control = %BalloonContainer
@onready var _main_hud: MainHud = %MainHUD

func _ready() -> void:
	_game_session.initialize(content_catalog, balloon_scene, _balloon_container)
	_main_hud.bind(_game_session)
	_game_session.refresh_presentation()
