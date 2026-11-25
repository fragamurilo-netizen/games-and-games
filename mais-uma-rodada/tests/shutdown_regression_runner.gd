extends Node
## Quit while a worker still needs the shared translation resources. The exit
## path must join it without calling a callback on the disappearing UI.

func _ready() -> void:
	I18n.apply("en")
	GameManager.run_work(func():
		OS.delay_msec(150)
		var ok := I18n.t("Salvar agora") == "Save now"
		if not ok:
			push_error("SHUTDOWN_REGRESSION_FAIL: translation resources released before worker")
		print("SHUTDOWN_WORKER_OK=", ok), func(_r):
			push_error("SHUTDOWN_REGRESSION_FAIL: UI callback invoked during shutdown"))
	get_tree().quit()
