package square_packing

import "core:fmt"
import "core:math"
import "vendor:raylib"
import "vendor:raylib/rlgl"

SQUARE_COUNT :: 2
UNIT :: 8
FULL_CIRCLE :: 8

U32x2 :: [2]u32

make_edges :: proc "contextless" () -> [FULL_CIRCLE]U32x2 {
	edges: [FULL_CIRCLE]U32x2
	for angle in 0 ..< FULL_CIRCLE {
		rad := cast(f64)angle * (2 * math.PI) / FULL_CIRCLE
		x := cast(i32)(math.cos(rad) * UNIT)
		y := cast(i32)(math.sin(rad) * UNIT)
		edges[angle] = {cast(u32)x, cast(u32)y}
	}
	return edges
}

EDGES := make_edges()

Square :: struct {
	pos:   U32x2,
	angle: u32,
}
Squares :: [SQUARE_COUNT]Square

square_corners :: proc "contextless" (square: Square) -> [4]U32x2 {
	edge1 := EDGES[square.angle]
	edge2: U32x2 = {-edge1.y, edge1.x}
	return {square.pos, square.pos + edge1, square.pos + edge1 + edge2, square.pos + edge2}
}

Line :: [2]U32x2

lines_cross :: proc(a: Line, b: Line) -> b32 {
	if a == b || a == {b[1], b[0]} {
		return false
	}
	diff0 := cast([2]i64)b[0] - cast([2]i64)a[0]
	diff1 := cast([2]i64)b[1] - cast([2]i64)a[1]
	dot0 := diff0.x * diff1.x + diff0.y * diff1.y
	diff2 := cast([2]i64)b[0] - cast([2]i64)a[1]
	diff3 := cast([2]i64)b[1] - cast([2]i64)a[0]
	dot1 := diff2.x * diff3.x + diff2.y * diff3.y
	return dot0 < 0 || dot1 < 0
}

check_collision :: proc(a: Square, b: Square) -> b32 {
	corners_a := square_corners(a)
	corners_b := square_corners(b)
	for i in 0 ..< 4 {
		for j in 0 ..< 4 {
			if lines_cross(
				{corners_a[i], corners_a[(i + 1) % 4]},
				{corners_b[j], corners_b[(j + 1) % 4]},
			) {
				return true
			}
		}
	}
	return corners_a == corners_b
}

check_collisions :: proc(squares: Squares) -> b32 {
	for i in 0 ..< SQUARE_COUNT {
		for j in i + 1 ..< SQUARE_COUNT {
			if (check_collision(squares[i], squares[j])) {
				return true
			}
		}
	}
	return false
}

Borders :: struct {
	pos:  U32x2,
	size: U32x2,
}

get_box_borders :: proc(squares: Squares) -> Borders {
	min_x := squares[0].pos.x
	max_x := squares[0].pos.x
	min_y := squares[0].pos.y
	max_y := squares[0].pos.y

	for square in squares {
		corners := square_corners(square)
		min_x = math.min(min_x, corners[0].x, corners[1].x, corners[2].x, corners[3].x)
		max_x = math.max(max_x, corners[0].x, corners[1].x, corners[2].x, corners[3].x)
		min_y = math.min(min_y, corners[0].y, corners[1].y, corners[2].y, corners[3].y)
		max_y = math.max(max_y, corners[0].y, corners[1].y, corners[2].y, corners[3].y)
	}

	return {pos = {min_x, min_y}, size = {max_x - min_x, max_y - min_y}}
}

try_increment :: proc(value: ^u32, modulo: u32, offset: u32) -> b32 {
	value^ += 1
	if value^ == modulo + offset {
		value^ = offset
		return false
	}
	return true
}

CENTER_OFFSET :: UNIT * 2
SIZE :: UNIT * SQUARE_COUNT * 2

WINDOW_SIZE :: 800
WINDOW_PADDING :: WINDOW_SIZE / 8
WINDOW_SIZE_PADDED :: WINDOW_SIZE - WINDOW_PADDING * 2

main :: proc() {
	squares: Squares = {}

	for &square in squares {
		square.pos = {CENTER_OFFSET, CENTER_OFFSET}
	}

	min_size: u32 = CENTER_OFFSET + SIZE
	min_borders: Borders
	min_squares: Squares

	for exit := false; !exit; {
		if !check_collisions(squares) {
			borders := get_box_borders(squares)
			size := math.max(borders.size.x, borders.size.y)
			if size < min_size ||
			   (size == min_size &&
					   (borders.size.x < min_borders.size.x ||
							   borders.size.y < min_borders.size.y)) {
				min_size = size
				min_borders = borders
				min_squares = squares
			}
		}

		i := 0
		for !try_increment(&squares[i].pos.x, modulo = SIZE, offset = CENTER_OFFSET) &&
		    !try_increment(&squares[i].pos.y, modulo = SIZE, offset = CENTER_OFFSET) &&
		    !try_increment(&squares[i].angle, modulo = FULL_CIRCLE / 4, offset = 0) {
			i += 1
			if i == SQUARE_COUNT {
				exit = true
				break
			}

			if i > 0 {
				fmt.println(squares)
			}
		}
	}

	title := fmt.caprintf(
		"best %v-square packing (%v units wide/long)",
		SQUARE_COUNT,
		f32(min_size) / UNIT,
	)
	raylib.InitWindow(WINDOW_SIZE, WINDOW_SIZE, title)

	rlgl.DisableBackfaceCulling()

	raylib.BeginDrawing()

	for square in min_squares {
		corners := square_corners(square)

		positions: [5][2]f32
		for i in 0 ..< 4 {
			positions[i] =
				WINDOW_PADDING +
				cast([2]f32)(corners[i] - min_borders.pos) / cast(f32)min_size * WINDOW_SIZE_PADDED
			positions[i].y = WINDOW_SIZE - positions[i].y
		}
		positions[4] = positions[0]

		raylib.DrawLineStrip(&positions[0], 5, {255, 255, 255, 255})
	}

	raylib.EndDrawing()

	for !raylib.WindowShouldClose() {
		raylib.PollInputEvents()
	}
	raylib.CloseWindow()
}
