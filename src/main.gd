extends Control


const letter_count := 5
const guess_count := 6

const Letter := preload("res://src/letter.tscn")

@export var color_incorrect: Color = Color()
@export var color_misplaced: Color = Color()
@export var color_correct: Color = Color()

# An array of arrays of the letter nodes
var letters := []
var keyboard_buttons := {}

var target_word: String
var current_guess: int
var ended: bool
var input_guess: String

@onready var title: Label = %Title
@onready var letter_grid: GridContainer = %LetterGrid
@onready var info_text: Label = %InfoText

@onready var keyboard_vbox: VBoxContainer = %KeyboardVBox
@onready var guess_button: Button = %GuessButton
@onready var backspace_button: Button = %ButtonBksp

@onready var info_text_animation: AnimationPlayer = %InfoTextAnimation

@onready var error_text_color_default := info_text.label_settings.font_color


func _ready() -> void:
	letter_grid.columns = letter_count
	for _i in range(guess_count):
		var letter_array := []
		for _j in range(letter_count):
			var letter := Letter.instantiate()
			letter_array.append(letter)
			letter_grid.add_child(letter)
		letters.append(letter_array)

	var random_seed = null
	if Global.daily_mode:
		var current_time := Time.get_datetime_dict_from_system(true)
		current_time["hour"] = 0
		current_time["minute"] = 0
		current_time["second"] = 0
		random_seed = Time.get_unix_time_from_datetime_dict(current_time)

		title.text = "Daily " + title.text
	else:
		title.text = "Random " + title.text

	target_word = Global.generate_word(letter_count, random_seed)
	current_guess = 0
	ended = false

	for i in range(0, 26):
		var letter := char("A".unicode_at(0) + i)
		var keyboard_button: Button = keyboard_vbox.find_child("Button" + letter)
		keyboard_buttons[letter] = keyboard_button
		var error := keyboard_button.connect("pressed", Callable(self, "type_letter").bind(letter))
		assert(not error)


func type_letter(letter: String) -> void:
	if ended or input_guess.length() >= letter_count:
		return
	var index := input_guess.length()
	letter = letter[0]
	input_guess += letter
	var letter_instance := letters[current_guess][index] as ColorRect
	letter_instance.get_node("Label").text = letter


func backspace() -> void:
	if ended or input_guess.length() <= 0:
		return
	input_guess = input_guess.substr(0, input_guess.length() - 1)
	var index := input_guess.length()
	var letter_instance := letters[current_guess][index] as ColorRect
	letter_instance.get_node("Label").text = ""


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed():
		var keycode = event.get_keycode()
		if keycode >= KEY_A and keycode <= KEY_Z:
			var letter := OS.get_keycode_string(keycode)
			type_letter(letter)
			get_viewport().set_input_as_handled()
		elif keycode == KEY_BACKSPACE:
			backspace()
			get_viewport().set_input_as_handled()
		elif keycode == KEY_ENTER:
			guess_entered()
			get_viewport().set_input_as_handled()


func _on_GuessButton_pressed() -> void:
	guess_entered()


func guess_entered() -> void:
	if current_guess >= guess_count:
		return
	input_guess = input_guess.to_upper()
	if input_guess.length() != letter_count:
		show_error("Word must be five characters.")
		return
	if not Global.is_valid_word(input_guess):
		show_error("Not a recognized word.")
		return

	var letters_remaining = []
	for letter in target_word:
		letters_remaining.append(letter)

	hide_info()

	# Mark all greens
	for i in range(letter_count):
		var guess_letter := input_guess[i]
		var target_letter := target_word[i]

		var letter_instance := letters[current_guess][i] as ColorRect
		letter_instance.get_node("Label").text = guess_letter
		if guess_letter == target_letter:
			letter_instance.color = color_correct
			keyboard_buttons[target_letter].modulate = color_correct
			# Remove that one letter from remaining letters (is there a function for this?)
			for j in range(letters_remaining.size()):
				if letters_remaining[j] == guess_letter:
					letters_remaining.remove_at(j)
					break

	# Mark all yellows (and grays)
	for i in range(letter_count):
		var letter_instance := letters[current_guess][i] as ColorRect
		if letter_instance.color == color_correct:
			# Ignore things that are already green
			continue
		var guess_letter := input_guess[i]
		var found := false
		for j in range(letters_remaining.size()):
			if letters_remaining[j] == guess_letter:
				found = true
				letters_remaining.remove_at(j)
				break
		if found:
			letter_instance.color = color_misplaced
			if keyboard_buttons[guess_letter].modulate != color_correct:
				keyboard_buttons[guess_letter].modulate = color_misplaced
		else:
			letter_instance.color = color_incorrect
			keyboard_buttons[guess_letter].modulate = color_incorrect

	current_guess += 1

	var won := false

	if input_guess == target_word:
		ended = true
		won = true
	elif current_guess >= guess_count:
		ended = true

	input_guess = ""

	if ended:
		guess_button.disabled = true
		for letter in keyboard_buttons:
			keyboard_buttons[letter].disabled = true
		backspace_button.disabled = true
		if won:
			show_info("Congrats! You won!", Color(0.4, 0.9, 0.6))
		else:
			show_info("Game Over. The word was %s" % target_word, error_text_color_default)


func show_error(text: String):
	info_text.text = text
	info_text.label_settings.font_color = error_text_color_default
	info_text_animation.stop()
	info_text_animation.play("ErrorMessage")
	info_text.show()


func show_info(text: String, color: Color):
	info_text_animation.play("RESET")
	info_text.text = text
	info_text.label_settings.font_color = color
	info_text.show()


func hide_info():
	info_text_animation.play("RESET")
	info_text.hide()


func _on_MenuButton_pressed() -> void:
	# TODO check if game is in progress and show confirmation popup
	var error := get_tree().change_scene_to_file("res://src/menu.tscn")
	assert(not error)


func _on_ButtonBksp_pressed() -> void:
	backspace()