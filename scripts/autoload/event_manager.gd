extends Node

## EVENT MANAGER - Bus de eventos genérico (autoload "EventManager").
## Permite que sistemas desacoplados (UI, efectos, audio) reaccionen a
## eventos del juego sin depender directamente unos de otros.

var _listeners: Dictionary = {}  # event_name -> Array[Callable]

func subscribe(event_name: String, callback: Callable) -> void:
	if not _listeners.has(event_name):
		_listeners[event_name] = []
	if not _listeners[event_name].has(callback):
		_listeners[event_name].append(callback)

func unsubscribe(event_name: String, callback: Callable) -> void:
	if _listeners.has(event_name):
		_listeners[event_name].erase(callback)

func emit_event(event_name: String, args: Array = []) -> void:
	if not _listeners.has(event_name):
		return
	for callback in _listeners[event_name].duplicate():
		if callback.is_valid():
			callback.callv(args)
