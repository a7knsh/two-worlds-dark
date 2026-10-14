class_name Hud
extends CanvasLayer
## All 2D UI: bars, prompts, ground messages, area titles, boss bar, banners,
## cutscene letterbox + subtitles, fades, pause menu and the title screen.

signal pause_choice(choice: String)
signal pause_pressed

var serif: SystemFont
var hp_bar: ProgressBar
var hp_lag: ProgressBar
var st_bar: ProgressBar
var vial_label: Label
var weapon_label: Label
var mode_label: Label
var prompt_label: Label
var msg_panel: PanelContainer
var msg_label: Label
var hint_label: Label
var area_label: Label
var area_line_a: ColorRect
var area_line_b: ColorRect
var boss_box: Control
var boss_name: Label
var boss_bar: ProgressBar
var boss_lag: ProgressBar
var banner: Label
var banner_band: ColorRect
var bar_top: ColorRect
var bar_bot: ColorRect
var sub_speaker: Label
var sub_text: Label
var skip_label: Label
var fade: ColorRect
var flash_rect: ColorRect
var pause_panel: PanelContainer
var title_root: Control
var title_press: Label
var gameplay_root: Control
var ending_label: Label

func _init() -> void:
    layer = 30
    process_mode = Node.PROCESS_MODE_ALWAYS
    serif = SystemFont.new()
    serif.font_names = PackedStringArray(["Cinzel", "Trajan Pro", "EB Garamond", "Garamond", "Cormorant Garamond",
        "Times New Roman", "Liberation Serif", "DejaVu Serif", "Noto Serif", "serif"])

func _label(text: String, size: int, color := Color(0.88, 0.85, 0.78), font: Font = null) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
    l.add_theme_constant_override("shadow_offset_x", 2)
    l.add_theme_constant_override("shadow_offset_y", 2)
    l.add_theme_font_override("font", font if font != null else serif)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

func _bar(color: Color, w: float, h: float, bg := true) -> ProgressBar:
    var b := ProgressBar.new()
    b.custom_minimum_size = Vector2(w, h)
    b.size = Vector2(w, h)
    b.show_percentage = false
    b.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_theme_font_size_override("font_size", 1)
    var fg := StyleBoxFlat.new()
    fg.bg_color = color
    var back := StyleBoxFlat.new()
    back.bg_color = Color(0.03, 0.03, 0.03, 0.85) if bg else Color(0, 0, 0, 0)
    if bg:
        back.border_color = Color(0.45, 0.4, 0.32, 0.9)
        back.set_border_width_all(1)
    b.add_theme_stylebox_override("fill", fg)
    b.add_theme_stylebox_override("background", back)
    return b

func _full(c: Control) -> void:
    c.set_anchors_preset(Control.PRESET_FULL_RECT)
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
    gameplay_root = Control.new()
    _full(gameplay_root)
    add_child(gameplay_root)
    # --- vitals
    hp_lag = _bar(Color(0.85, 0.7, 0.3), 330, 14)
    hp_lag.position = Vector2(28, 24)
    gameplay_root.add_child(hp_lag)
    hp_bar = _bar(Color(0.62, 0.06, 0.05), 330, 14, false)
    hp_bar.position = Vector2(28, 24)
    gameplay_root.add_child(hp_bar)
    st_bar = _bar(Color(0.22, 0.55, 0.28), 250, 9)
    st_bar.position = Vector2(28, 44)
    gameplay_root.add_child(st_bar)
    vial_label = _label("", 20, Color(0.95, 0.55, 0.45))
    vial_label.position = Vector2(28, 640)
    gameplay_root.add_child(vial_label)
    weapon_label = _label("", 16, Color(0.75, 0.72, 0.65))
    weapon_label.position = Vector2(28, 668)
    gameplay_root.add_child(weapon_label)
    mode_label = _label("", 14, Color(0.7, 0.72, 0.8, 0.7))
    mode_label.position = Vector2(28, 60)
    gameplay_root.add_child(mode_label)
    # --- prompt + hint
    prompt_label = _label("", 22)
    prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt_label.position = Vector2(340, 520)
    prompt_label.size = Vector2(600, 30)
    gameplay_root.add_child(prompt_label)
    hint_label = _label("", 18, Color(0.92, 0.85, 0.7))
    hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint_label.position = Vector2(240, 90)
    hint_label.size = Vector2(800, 30)
    hint_label.modulate.a = 0.0
    gameplay_root.add_child(hint_label)
    # --- boss bar
    boss_box = Control.new()
    boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    boss_box.visible = false
    gameplay_root.add_child(boss_box)
    boss_name = _label("", 20, Color(0.9, 0.86, 0.78))
    boss_name.position = Vector2(240, 566)
    boss_box.add_child(boss_name)
    boss_lag = _bar(Color(0.85, 0.7, 0.3), 800, 12)
    boss_lag.position = Vector2(240, 596)
    boss_box.add_child(boss_lag)
    boss_bar = _bar(Color(0.55, 0.05, 0.04), 800, 12, false)
    boss_bar.position = Vector2(240, 596)
    boss_box.add_child(boss_bar)
    # --- ground message panel
    msg_panel = PanelContainer.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.0, 0.0, 0.0, 0.82)
    sb.border_color = Color(0.6, 0.45, 0.25, 0.8)
    sb.border_width_top = 1
    sb.border_width_bottom = 1
    sb.content_margin_left = 40
    sb.content_margin_right = 40
    sb.content_margin_top = 26
    sb.content_margin_bottom = 26
    msg_panel.add_theme_stylebox_override("panel", sb)
    msg_panel.position = Vector2(0, 250)
    msg_panel.size = Vector2(1280, 200)
    msg_panel.custom_minimum_size = Vector2(1280, 200)
    msg_panel.visible = false
    msg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(msg_panel)
    msg_label = _label("", 24, Color(0.95, 0.88, 0.72))
    msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    msg_panel.add_child(msg_label)
    # --- area title
    area_label = _label("", 40, Color(0.92, 0.9, 0.84))
    area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    area_label.position = Vector2(0, 300)
    area_label.size = Vector2(1280, 60)
    area_label.modulate.a = 0.0
    add_child(area_label)
    area_line_a = ColorRect.new()
    area_line_a.color = Color(0.85, 0.8, 0.65, 0.7)
    area_line_a.position = Vector2(390, 296)
    area_line_a.size = Vector2(500, 1)
    area_line_a.modulate.a = 0.0
    add_child(area_line_a)
    area_line_b = area_line_a.duplicate() as ColorRect
    area_line_b.position = Vector2(390, 366)
    add_child(area_line_b)
    # --- banner (YOU DIED / WARDEN FELLED / LANTERN LIT)
    banner_band = ColorRect.new()
    banner_band.color = Color(0, 0, 0, 0.7)
    banner_band.position = Vector2(0, 290)
    banner_band.size = Vector2(1280, 130)
    banner_band.modulate.a = 0.0
    banner_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(banner_band)
    banner = _label("", 78)
    banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    banner.position = Vector2(0, 290)
    banner.size = Vector2(1280, 130)
    banner.modulate.a = 0.0
    add_child(banner)
    # --- cutscene letterbox + subtitles
    bar_top = ColorRect.new()
    bar_top.color = Color.BLACK
    bar_top.position = Vector2(0, -90)
    bar_top.size = Vector2(1280, 90)
    bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bar_top)
    bar_bot = ColorRect.new()
    bar_bot.color = Color.BLACK
    bar_bot.position = Vector2(0, 720)
    bar_bot.size = Vector2(1280, 90)
    bar_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bar_bot)
    sub_speaker = _label("", 18, Color(0.75, 0.68, 0.55))
    sub_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub_speaker.position = Vector2(0, 628)
    sub_speaker.size = Vector2(1280, 24)
    add_child(sub_speaker)
    sub_text = _label("", 25, Color(0.95, 0.93, 0.88))
    sub_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sub_text.position = Vector2(140, 652)
    sub_text.size = Vector2(1000, 60)
    add_child(sub_text)
    skip_label = _label("", 14, Color(0.7, 0.7, 0.7, 0.7))
    skip_label.position = Vector2(1050, 20)
    add_child(skip_label)
    # --- ending text
    ending_label = _label("", 32, Color(0.9, 0.88, 0.82))
    ending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ending_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    ending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    ending_label.position = Vector2(140, 160)
    ending_label.size = Vector2(1000, 400)
    ending_label.modulate.a = 0.0
    # --- fades
    flash_rect = ColorRect.new()
    _full(flash_rect)
    flash_rect.color = Color(1, 1, 1, 0)
    add_child(flash_rect)
    fade = ColorRect.new()
    _full(fade)
    fade.color = Color(0, 0, 0, 1)
    add_child(fade)
    add_child(ending_label)
    _build_pause()
    _build_title()

# ------------------------------------------------------------------ vitals

func set_hp(v: float, m: float) -> void:
    hp_bar.max_value = m
    hp_lag.max_value = m
    hp_bar.value = v
    if v > hp_lag.value:
        hp_lag.value = v

func set_stamina(v: float, m: float) -> void:
    st_bar.max_value = m
    st_bar.value = v

func set_vials(n: int) -> void:
    vial_label.text = "Blood Vials  x%d" % n

func set_weapon(wname: String) -> void:
    weapon_label.text = wname

func set_boss(bname: String, v: float, m: float) -> void:
    boss_box.visible = bname != ""
    boss_name.text = bname
    boss_bar.max_value = m
    boss_lag.max_value = m
    boss_bar.value = v
    if v > boss_lag.value or bname == "":
        boss_lag.value = v

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("pause") and not event.is_echo():
        pause_pressed.emit()

func _process(delta: float) -> void:
    # the yellow "recent damage" bars drain slowly behind the real value
    if hp_lag.value > hp_bar.value:
        hp_lag.value = maxf(hp_bar.value, hp_lag.value - 40.0 * delta)
    if boss_lag.value > boss_bar.value:
        boss_lag.value = maxf(boss_bar.value, boss_lag.value - 120.0 * delta)
    if title_root.visible:
        title_press.modulate.a = 0.45 + 0.4 * sin(Time.get_ticks_msec() * 0.003)

func show_gameplay(on: bool) -> void:
    gameplay_root.visible = on

func set_prompt(text: String) -> void:
    prompt_label.text = ("[E]  " + text) if text != "" else ""

# ------------------------------------------------------------------ messages, titles, banners

func show_message(text: String) -> void:
    msg_label.text = text + "\n\n[E] close"
    msg_panel.visible = true

func hide_message() -> void:
    msg_panel.visible = false

func message_open() -> bool:
    return msg_panel.visible

func hint(text: String, dur := 4.0) -> void:
    hint_label.text = text
    var tw := create_tween()
    tw.tween_property(hint_label, "modulate:a", 1.0, 0.4)
    tw.tween_interval(dur)
    tw.tween_property(hint_label, "modulate:a", 0.0, 0.8)

func area_title(text: String) -> void:
    area_label.text = text
    var tw := create_tween().set_parallel(true)
    for c: CanvasItem in [area_label, area_line_a, area_line_b]:
        tw.tween_property(c, "modulate:a", 1.0, 1.0)
    tw.chain().tween_interval(2.4)
    var tw2 := tw.chain().set_parallel(true)
    for c: CanvasItem in [area_label, area_line_a, area_line_b]:
        tw2.tween_property(c, "modulate:a", 0.0, 1.4)

func show_banner(text: String, color: Color, hold := 2.5, size := 78) -> void:
    banner.text = text
    banner.add_theme_color_override("font_color", color)
    banner.add_theme_font_size_override("font_size", size)
    banner.scale = Vector2.ONE
    banner.pivot_offset = banner.size * 0.5
    var tw := create_tween().set_parallel(true)
    tw.tween_property(banner, "modulate:a", 1.0, 1.0)
    tw.tween_property(banner_band, "modulate:a", 1.0, 1.0)
    tw.tween_property(banner, "scale", Vector2(1.06, 1.06), hold + 1.0)
    tw.chain().tween_interval(maxf(hold - 1.0, 0.1))
    var tw2 := tw.chain().set_parallel(true)
    tw2.tween_property(banner, "modulate:a", 0.0, 1.2)
    tw2.tween_property(banner_band, "modulate:a", 0.0, 1.2)

func fade_to(alpha: float, dur: float) -> Tween:
    var tw := create_tween()
    tw.tween_property(fade, "color:a", alpha, dur)
    return tw

func flash(c: Color, dur := 0.6) -> void:
    flash_rect.color = c
    var tw := create_tween()
    tw.tween_property(flash_rect, "color:a", 0.0, dur)

# ------------------------------------------------------------------ cutscenes

func letterbox(on: bool, dur := 0.8) -> void:
    var tw := create_tween().set_parallel(true)
    tw.tween_property(bar_top, "position:y", 0.0 if on else -90.0, dur)
    tw.tween_property(bar_bot, "position:y", 630.0 if on else 720.0, dur)
    show_gameplay(not on)
    if not on:
        subtitle("", "")
        skip_label.text = ""

func subtitle(speaker: String, text: String) -> void:
    sub_speaker.text = speaker
    sub_text.text = text
    sub_text.modulate.a = 0.0
    sub_speaker.modulate.a = 0.0
    if text != "":
        var tw := create_tween().set_parallel(true)
        tw.tween_property(sub_text, "modulate:a", 1.0, 0.5)
        tw.tween_property(sub_speaker, "modulate:a", 1.0, 0.5)

func narration(text: String, dur: float) -> void:
    ending_label.text = text
    var tw := create_tween()
    tw.tween_property(ending_label, "modulate:a", 1.0, minf(1.2, dur * 0.3))
    tw.tween_interval(maxf(dur - 2.2, 0.2))
    tw.tween_property(ending_label, "modulate:a", 0.0, minf(1.0, dur * 0.25))

func clear_narration() -> void:
    ending_label.modulate.a = 0.0

# ------------------------------------------------------------------ pause

func _build_pause() -> void:
    pause_panel = PanelContainer.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.02, 0.02, 0.03, 0.92)
    sb.border_color = Color(0.5, 0.42, 0.3)
    sb.set_border_width_all(1)
    sb.set_content_margin_all(30)
    pause_panel.add_theme_stylebox_override("panel", sb)
    pause_panel.position = Vector2(390, 140)
    pause_panel.custom_minimum_size = Vector2(500, 0)
    pause_panel.visible = false
    add_child(pause_panel)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 12)
    pause_panel.add_child(vb)
    var t := _label("PAUSED", 34)
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vb.add_child(t)
    for pair: Array in [["Resume", "resume"], ["Quit to Title", "title"], ["Quit Game", "quit"]]:
        var b := Button.new()
        b.text = pair[0]
        b.add_theme_font_override("font", serif)
        b.add_theme_font_size_override("font_size", 22)
        b.pressed.connect(func() -> void: pause_choice.emit(pair[1]))
        vb.add_child(b)
    var help := _label("WASD move   Mouse / arrow keys / right stick: rotate + tilt camera   Wheel or +/-: zoom\nSPACE roll   J / LMB light   K / RMB heavy\nQ lock-on   F drink Blood Vial   E interact   ESC pause\n\nGamepad: B roll, X light, Y heavy, R3 lock-on, LB heal, A interact", 15, Color(0.75, 0.72, 0.66))
    help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vb.add_child(help)

func show_pause(on: bool) -> void:
    pause_panel.visible = on
    if on:
        (pause_panel.get_child(0).get_child(1) as Button).grab_focus()

# ------------------------------------------------------------------ title

func _build_title() -> void:
    title_root = Control.new()
    _full(title_root)
    title_root.visible = false
    add_child(title_root)
    var shade := ColorRect.new()
    _full(shade)
    shade.color = Color(0, 0, 0, 0.45)
    title_root.add_child(shade)
    var t := _label("TWO WORLDS DARK", 84, Color(0.9, 0.88, 0.82))
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    t.position = Vector2(0, 200)
    t.size = Vector2(1280, 110)
    title_root.add_child(t)
    var sub := _label("~  a tale of the Veil and the Flesh  ~", 22, Color(0.7, 0.62, 0.52))
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.position = Vector2(0, 310)
    sub.size = Vector2(1280, 30)
    title_root.add_child(sub)
    title_press = _label("Press any key", 24, Color(0.9, 0.86, 0.75))
    title_press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_press.position = Vector2(0, 470)
    title_press.size = Vector2(1280, 30)
    title_root.add_child(title_press)
    var ver := _label("Prototype v1.1", 14, Color(0.6, 0.6, 0.6))
    ver.position = Vector2(1140, 690)
    title_root.add_child(ver)

func show_title(on: bool) -> void:
    title_root.visible = on
    show_gameplay(not on)
