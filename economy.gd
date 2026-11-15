# economy.gd
class_name PlayerEconomy
extends Node

signal gold_changed(amount: int)

var gold: int = 0

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
