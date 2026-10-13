extends "res://tools/check_forced_immersion.gd"


func _run() -> void:
	_check(ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray()).has("res://localization/messages.ru.translation"), "Native Godot translation resource is registered in the project")
	_check(tr("OBJECT_NAME_PUSH_SCROLL") == "Свиток толчка", "Godot loads the imported CSV translation at startup without a custom text loader")
	var scene := await _fixture({})
	var state: int = scene.get("_rng").state
	var controls := ["ЛКМ", "ПКМ", "WASD", "Space", "Esc", "пробел", "прицел", "Нажмите", "Перетащите", "окно"]
	for definition: Dictionary in CATALOG.definitions():
		for field: String in ["name_key", "description_key", "encounter_text_key", "confirmation_key"]:
			if definition.has(field):
				_check(tr(definition[field]) != definition[field], "Every object text key resolves through Godot: " + definition.id + ":" + field)
		_check(not definition.has("name") and not definition.has("description"), "Gameplay definitions contain text keys, not localized prose: " + definition.id)
		if definition.category not in ["item", "currency"]:
			continue
		var tooltip: String = scene.call("_item_tooltip", definition.id)
		var item_name := tr(definition.name_key)
		_check(tooltip.begins_with(item_name) and tooltip.length() > item_name.length(), "Every item has a name and effect description: " + definition.id)
		_check(not controls.any(func(word: String): return tooltip.contains(word)) and not tooltip.contains("{"), "Descriptions have no UI instructions or unresolved formulas: " + definition.id)
	_check(scene.get("_rng").state == state and scene.get("_turn_queue").current_turn == 0, "Reading descriptions never rolls loot or changes game state")
	_add(scene, "push_scroll")
	var slot: int = scene.get("_inventory_item_ids").find("push_scroll")
	var node: Control = scene.get("_inventory_slot_icons")[slot].get_parent().get_parent()
	_check(node.tooltip_text.contains("до 5 клеток") and node.tooltip_text.contains("падает") and node.tooltip_text.contains("+1 магию") and node.tooltip_text == scene.call("_item_tooltip", "push_scroll"), "The real scroll slot shows its effect, range, falling and magic growth")
	var inventory_controls: Label = scene.find_child("InventoryControls", true, false)
	var weapon_controls: Label = scene.find_child("WeaponControls", true, false)
	var floor_controls: Label = scene.find_child("FloorControls", true, false)
	_check(inventory_controls.text.contains("ЛКМ") and inventory_controls.text.contains("ПКМ") and weapon_controls.text.contains("перетащите") and floor_controls.text.contains("подобрать"), "Inventory, weapon and floor input instructions have their own UI labels")
	_check(inventory_controls.mouse_filter == Control.MOUSE_FILTER_IGNORE and floor_controls.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Separate hints never consume item input")
	scene.call("_activate_inventory_slot", slot)
	var target_hint: Label = scene.get("_field_target").get("_hint")
	_check(target_hint.is_visible_in_tree() and target_hint.text.contains("WASD") and target_hint.text.contains("Space") and target_hint.text.contains("Esc"), "Direction and confirmation instructions are shown by the active targeting interface")
	_key(scene, KEY_ESCAPE)
	var item: Sprite2D = scene.call("_add_item", load(CATALOG.HEALTH_POTION_PATH), HERO, 1.0, 10, "health_potion")
	item.set_meta("auto_pickup", false)
	scene.call("_refresh_floor_panel")
	var floor_slot: Control = scene.get("_floor_grid").get_child(0)
	_check(floor_slot.tooltip_text == scene.call("_item_tooltip", "health_potion") and floor_slot.tooltip_text.contains("20"), "Floor loot uses the same live effect description")
	_add(scene, "strength_potion")
	scene.call("_activate_inventory_slot", scene.get("_inventory_item_ids").find("strength_potion"))
	scene.call("_finish_hero_move", false)
	floor_slot = scene.get("_floor_grid").get_child(0)
	_check(scene.get("_hero_magic") == 11 and floor_slot.tooltip_text.contains("22") and floor_slot.tooltip_text == scene.call("_item_tooltip", "health_potion"), "Magic growth refreshes potion formulas even on the same floor cell")
	_add(scene, "sword")
	scene.call("_equip_inventory_item", scene.get("_inventory_item_ids").find("sword"))
	scene.call("_finish_hero_move", false)
	_check(scene.get("_weapon_slot").tooltip_text == scene.call("_item_tooltip", "sword") and scene.get("_weapon_slot").tooltip_text.contains("5 силы"), "Equipped weapons use the same description instead of input instructions")
	var future_translation := Translation.new()
	future_translation.locale = TranslationServer.get_locale()
	future_translation.add_message("FIXTURE_NEW_SCROLL_NAME", "Новый свиток")
	future_translation.add_message("FIXTURE_NEW_SCROLL_DESCRIPTION", "Новый игровой эффект.")
	TranslationServer.add_translation(future_translation)
	var future := {"id": "fixture_description", "name_key": "FIXTURE_NEW_SCROLL_NAME", "category": "item", "path": CATALOG.PUSH_SCROLL_PATH, "description_key": "FIXTURE_NEW_SCROLL_DESCRIPTION", "loot_group": "scrolls"}
	CATALOG.definitions().append(future)
	_add(scene, future.id)
	var future_slot: Control = scene.get("_inventory_slot_icons")[scene.get("_inventory_item_ids").find(future.id)].get_parent().get_parent()
	_check(future_slot.tooltip_text.contains(tr(future.description_key)) and future_slot.tooltip_text.contains("+1 магию"), "A new object uses translation keys without a UI-specific item case")
	CATALOG.definitions().pop_back()
	TranslationServer.remove_translation(future_translation)
	var corpse_text := "Труп кокатриса сохраняет свойства окаменения. Лучше не трогать."
	_check(scene.call("_item_tooltip", "cockatrice_corpse") == "Труп кокатриса\n" + corpse_text, "Translated corpse description retains the minimal warning without tactical spoilers")
	var corpse: Sprite2D = scene.call("_add_item", load(CATALOG.definition("cockatrice_corpse").path), HERO, 1.0, 10, "cockatrice_corpse")
	corpse.set_meta("auto_pickup", false)
	_check(not scene.call("_can_handle_item", "cockatrice_corpse", true) and scene.get("_encounter_prompt").find_child("Description", true, false).text == corpse_text, "The actual corpse notice uses the same translated description")
	scene.get("_encounter_prompt").call("_accept")
	await _check_language_lookup(scene)
	scene.free()
	for folder in _folders:
		for filename in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(filename))
		DirAccess.remove_absolute(folder)
	if _errors.is_empty():
		print("ITEM DESCRIPTIONS OK: native CSV translations and fallback, text keys without cached prose, locale-sensitive inventory/floor/weapon/editor, formulas, new object translations, spoiler-free corpse notice, separate UI hints and no state/RNG changes")
		quit()
	else:
		for message in _errors:
			push_error(message)
		quit(1)


func _check_language_lookup(scene: Node) -> void:
	var original_locale := TranslationServer.get_locale()
	var translation := Translation.new()
	translation.locale = "en"
	translation.add_message("OBJECT_NAME_SWORD", "Fixture sword")
	translation.add_message("OBJECT_NAME_HEALTH_POTION", "Fixture healing potion")
	translation.add_message("ITEM_DESCRIPTION_HEALTH_POTION", "Restores {healing_amount} strength.")
	translation.add_message("OBJECT_NAME_WALL", "Fixture wall")
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("en")
	await process_frame
	scene.call("_refresh_inventory_panel")
	scene.call("_refresh_floor_panel")
	scene.call("_rebuild_editor_palette")
	_check(scene.get("_weapon_slot").tooltip_text.begins_with("Fixture sword"), "Equipped weapon resolves its name for the current locale after definitions were cached")
	_check(scene.get("_floor_grid").get_child(0).tooltip_text.begins_with("Fixture healing potion\nRestores 22 strength."), "Floor description changes locale on the same cell and preserves live formulas")
	var wall_button: Control
	for button: Control in scene.get("_editor_palette").get_children():
		if button.get_meta("object_type", "") == "wall":
			wall_button = button
	_check(wall_button != null and wall_button.tooltip_text == "Fixture wall", "Editor names use native translations too")
	_check(scene.call("_item_tooltip", "push_scroll").begins_with("Свиток толчка"), "Untranslated locale keys fall back to the registered Russian translation")
	TranslationServer.set_locale(original_locale)
	TranslationServer.remove_translation(translation)
	await process_frame
