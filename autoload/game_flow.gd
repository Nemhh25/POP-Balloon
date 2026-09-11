class_name PopGameFlow
extends Node

enum LaunchMode { CONTINUE_CAMPAIGN, NEW_GAME, ENDLESS }

var _launch_mode: LaunchMode = LaunchMode.CONTINUE_CAMPAIGN

func start_campaign() -> void:
	_launch_mode = LaunchMode.CONTINUE_CAMPAIGN

func start_new_game() -> void:
	_launch_mode = LaunchMode.NEW_GAME

func start_endless() -> void:
	_launch_mode = LaunchMode.ENDLESS

func consume_launch_mode() -> LaunchMode:
	var mode := _launch_mode
	_launch_mode = LaunchMode.CONTINUE_CAMPAIGN
	return mode
