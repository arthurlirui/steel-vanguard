extends ParallaxBackground
## ParallaxBG — multi-layer scrolling background for depth illusion.
## This script auto-generates parallax layers with placeholder shapes.

const NUM_LAYERS: int = 4
const LEVEL_WIDTH: float = 6000.0
const VIEWPORT_HEIGHT: float = 1920.0

var layer_colors: Array[Color] = [
	Color(0.10, 0.08, 0.20),  # Far sky
	Color(0.18, 0.12, 0.28),  # Distant mountains
	Color(0.25, 0.18, 0.22),  # Mid buildings
	Color(0.30, 0.22, 0.15),  # Near foreground
]
var layer_speeds: Array[float] = [0.1, 0.3, 0.5, 0.8]
var layer_heights: Array[float] = [1920.0, 600.0, 400.0, 200.0]
var layer_y_offsets: Array[float] = [0.0, 400.0, 800.0, 1200.0]

func _ready() -> void:
	for i in range(NUM_LAYERS):
		_create_layer(i)

func _create_layer(index: int) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(layer_speeds[index], 0.0)
	layer.motion_mirroring = Vector2(LEVEL_WIDTH, 0)
	add_child(layer)
	# Background rect
	var bg := ColorRect.new()
	bg.color = layer_colors[index]
	bg.size = Vector2(LEVEL_WIDTH, layer_heights[index])
	bg.position = Vector2(0, layer_y_offsets[index])
	layer.add_child(bg)
	# Add some decorative shapes for visual interest
	if index == 1:
		# Mountains (triangles using colored rects as approximation)
		for x in range(0, int(LEVEL_WIDTH), 400):
			var peak := ColorRect.new()
			peak.color = Color(0.22, 0.15, 0.32)
			peak.size = Vector2(200, 300)
			peak.position = Vector2(x, 100)
			layer.add_child(peak)
	elif index == 2:
		# Buildings
		for x in range(0, int(LEVEL_WIDTH), 300):
			var bldg := ColorRect.new()
			bldg.color = Color(0.28, 0.20, 0.25)
			var h := randf_range(150, 350)
			bldg.size = Vector2(120, h)
			bldg.position = Vector2(x, 400 - h + 200)
			layer.add_child(bldg)
			# Windows
			for wy in range(20, int(h - 20), 40):
				for wx in range(15, 105, 35):
					var win := ColorRect.new()
					win.color = Color(0.5, 0.4, 0.2, 0.6)
					win.size = Vector2(12, 18)
					win.position = Vector2(x + wx, 400 - h + 200 + wy)
					layer.add_child(win)
	elif index == 3:
		# Foreground details (rocks, debris)
		for x in range(0, int(LEVEL_WIDTH), 500):
			var rock := ColorRect.new()
			rock.color = Color(0.25, 0.20, 0.12)
			rock.size = Vector2(randf_range(30, 60), randf_range(20, 40))
			rock.position = Vector2(x + randf_range(-50, 50), 1200 + randf_range(-20, 20))
			layer.add_child(rock)
