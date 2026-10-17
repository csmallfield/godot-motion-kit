extends MotionComposition
# Visual check: one letter at six draw-on stages, big.
func _ready() -> void:
	var bg := ColorRect.new(); bg.color = Color("#1b6393"); bg.size = size; add_child(bg)
	var data := MotionSvgData.from_file("res://demo/assets/logos/mh_logoFull_standard.svg")
	var letters := data.sorted_by_x(PackedInt32Array(range(3, 16)))
	var n := letters[11]   # "n" of humans? pick by order
	for k in 6:
		var s := MotionSvg.new(); s.data = data; s.width = 6000
		var b: Rect2 = data.parts[n].bbox
		s.position = Vector2(60 + (k % 3) * 620, 40 + (k / 3) * 520) - s.logo_to_local(b.position)
		s.only = PackedInt32Array([n])
		var amt := (k + 1) / 6.0
		s.apply(func(i): return {draw = amt, fill = Color("#ece5da"), stroke = Color("#f4af3f"), draw_width = 8.0, fill_o = 0.25})
		add_child(s)
	duration = 3
	super._ready()
