extends Control

const FADE_DELAY: float = 5.0
const FADE_DURATION: float = 1.0

@onready var chat_log: RichTextLabel = $PanelContainer/VBoxContainer/ChatLog
@onready var input_line: LineEdit = $PanelContainer/VBoxContainer/InputLine
@onready var panel: PanelContainer = $PanelContainer

var _fade_timer: float = 0.0
var _chat_service: Node = null


func _ready() -> void:
	# Get ChatService from GameCore
	_chat_service = GameManager.get_core_system("chat")

	if _chat_service and _chat_service.has_signal("message_received"):
		_chat_service.message_received.connect(_on_message_received)

	input_line.text_submitted.connect(_on_text_submitted)
	input_line.focus_entered.connect(_on_focus_entered)
	input_line.focus_exited.connect(_on_focus_exited)

	# Initial state
	input_line.release_focus()
	input_line.hide()
	panel.modulate.a = 0.0  # Start hidden


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("chat_toggle"):
		# Don't trigger chat if the dev console or any other text input has focus
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused is LineEdit or focused is TextEdit:
			return  # Some other input field has focus, let it handle the input

		if input_line.visible:
			_close_chat()
		else:
			_open_chat()
		# Don't propagate to prevent other handlers
		get_viewport().set_input_as_handled()

	# Close on ESC if chat is open
	if event.is_action_pressed("ui_cancel") and input_line.visible:
		_close_chat()
		get_viewport().set_input_as_handled()


func _open_chat() -> void:
	input_line.show()
	input_line.grab_focus()
	panel.modulate.a = 1.0  # Show full opacity
	_fade_timer = 0.0  # Reset fade


func _close_chat() -> void:
	input_line.clear()
	input_line.hide()
	input_line.release_focus()


func _on_text_submitted(text: String) -> void:
	if _chat_service:
		_chat_service.send_message(text)

	_close_chat()


func _on_message_received(sender: String, message: String) -> void:
	chat_log.append_text("[b]%s:[/b] %s\n" % [sender, message])

	# Show chat briefly
	panel.modulate.a = 1.0
	_fade_timer = FADE_DELAY


func _process(delta: float) -> void:
	if not input_line.visible and panel.modulate.a > 0.0:
		if _fade_timer > 0:
			_fade_timer -= delta
		else:
			panel.modulate.a = max(0.0, panel.modulate.a - delta / FADE_DURATION)


func _on_focus_entered() -> void:
	panel.modulate.a = 1.0


func _on_focus_exited() -> void:
	pass  # Handle elsewhere
