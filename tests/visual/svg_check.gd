extends MotionComposition
# Visual check: MH wordmark at three draw-on stages, the SCF lockup recoloured and transformed.
var mh: MotionSvg
var scf: MotionSvg
func _ready() -> void:
	var bg := ColorRect.new(); bg.color = Color("#1b6393"); bg.size = size; add_child(bg)
	mh = MotionSvg.new(); mh.data = MotionSvgData.from_file("res://demo/assets/logos/mh_logoFull_standard.svg"); mh.width = 1500; mh.position = Vector2(210, 80); add_child(mh)
	scf = MotionSvg.new(); scf.data = MotionSvgData.from_file("res://demo/assets/logos/scf_logoFull_white.svg"); scf.width = 1200; scf.position = Vector2(300, 560); add_child(scf)
	duration = 3
	super._ready()
func _frame(f: float) -> void:
	mh.apply(func(i):
		if i < 3: return {s = 1.0, tx = (2 - i) * 4.0, ty = (2 - i) * 4.0}
		var k := float(i - 3) / 12.0
		return {fill = Color("#ece5da")} if i % 2 == 0 else {draw = clampf(k * 1.5, 0.0, 1.0), fill = Color("#ece5da"), stroke = Color("#f4af3f"), draw_width = 5.0, fill_o = 0.0})
	scf.apply(func(i):
		if i == 0: return {fill = Color("#ece5da")}
		if i >= 26 and i <= 37: return {s = 1.4, rot = 20.0}
		return null)
