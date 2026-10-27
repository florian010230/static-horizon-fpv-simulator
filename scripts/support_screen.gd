# (No class_name: an in-game update pack can't add global classes -
# users preload this file. 2026-10-27, 0.11.1.)
extends RefCounted

## "Support me" (small button in the main menu corner, user 2026-10-27): a
## short why in the first person, the Ko-fi button (the website's support
## page has the same text and link) and one line on the free ways to help.
## Opened only by the player - never a prompt after a race or on start.
## ("Support" alone read like a help desk - user.)

const KOFI_URL: String = "https://ko-fi.com/B8M429G0RW"

var screen: Control

func build(root: Control, on_back: Callable) -> Control:
	var parts: Array = UIKit.screen_card(root, "Support me", "", 520, on_back, 760)
	screen = parts[0]
	var c: VBoxContainer = parts[1]
	var why := Label.new()
	why.text = "I make Static Horizon FPV on my own, in my free time. It is free, and I want to keep it free - no ads, no paid extras. If you enjoy it and want to give something back for the time it takes, a small donation means a lot to me."
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(why)
	var kofi := UIKit.button("Buy me a coffee on Ko-fi", "PrimaryButton", 58)
	kofi.set_meta("default_focus", true)
	kofi.pressed.connect(func(): OS.shell_open(KOFI_URL))
	c.add_child(kofi)
	UIKit.gap(c, 6)
	var free := Label.new()
	free.text = "If you want to support the project in another way: share it with other pilots, or report a bug when you find one and help me improve it."
	free.theme_type_variation = "Muted"
	free.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(free)
	var thanks := Label.new()
	thanks.text = "Thank you, and happy flying!"
	c.add_child(thanks)
	return screen
