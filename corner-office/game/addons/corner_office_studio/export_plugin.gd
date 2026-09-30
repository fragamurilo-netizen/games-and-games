@tool
extends EditorPlugin
var exporter: EditorExportPlugin
func _enter_tree() -> void:
	exporter=StudioExport.new();add_export_plugin(exporter)
func _exit_tree() -> void:remove_export_plugin(exporter)
class StudioExport extends EditorExportPlugin:
	func _get_name() -> String:return "CornerOfficeStudio"
	func _supports_platform(platform: EditorExportPlatform) -> bool:return platform is EditorExportPlatformAndroid
	func _get_android_libraries(_platform: EditorExportPlatform,debug: bool) -> PackedStringArray:
		return PackedStringArray(["res://addons/corner_office_studio/bin/plugin-%s.aar"%["debug" if debug else "release"]])
