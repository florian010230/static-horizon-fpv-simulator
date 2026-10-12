class_name CutBox
extends StyleBox

## The race UI's panel shape as a StyleBox (menu buttons, the drone card):
## a dark panel with its top right corner cut off, a coloured stripe down
## the left and a thin edge round it. `bg` with alpha 0 draws only the
## stripe and edge (a focus overlay on top of a button's normal box).

var bg: Color = Color(0.082, 0.11, 0.149)
var edge: Color = Color(1, 1, 1, 0.12)
var stripe: Color = Color(0.231, 0.275, 0.337)
var stripe_w: float = 4.0
var cut: float = 16.0

static func make(p_bg: Color, p_stripe: Color, p_edge: Color, pad := Vector4(22, 10, 22, 10), p_cut: float = 16.0) -> CutBox:
	var b := CutBox.new()
	b.bg = p_bg
	b.stripe = p_stripe
	b.edge = p_edge
	b.cut = p_cut
	b.content_margin_left = pad.x
	b.content_margin_top = pad.y
	b.content_margin_right = pad.z
	b.content_margin_bottom = pad.w
	return b

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var c: float = minf(cut, minf(rect.size.x, rect.size.y) * 0.5)
	var p := rect.position
	var e := rect.end
	var poly := PackedVector2Array([p, Vector2(e.x - c, p.y), Vector2(e.x, p.y + c), e, Vector2(p.x, e.y)])
	if bg.a > 0.0:
		RenderingServer.canvas_item_add_polygon(to_canvas_item, poly, PackedColorArray([bg]))
	if edge.a > 0.0:
		var ring := poly.duplicate()
		ring.append(poly[0])
		RenderingServer.canvas_item_add_polyline(to_canvas_item, ring, PackedColorArray([edge]), 1.5, true)
	if stripe.a > 0.0 and stripe_w > 0.0:
		RenderingServer.canvas_item_add_rect(to_canvas_item, Rect2(p, Vector2(stripe_w, rect.size.y)), stripe)
