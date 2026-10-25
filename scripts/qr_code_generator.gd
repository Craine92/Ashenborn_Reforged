class_name QRCodeGenerator
extends RefCounted

# QR Code Model 2, Version 2-L. This holds up to 32 UTF-8 bytes in byte mode,
# enough for every IPv4 controller URL used by the local server.
const VERSION := 2
const MODULE_COUNT := 25
const DATA_CODEWORDS := 34
const ECC_CODEWORDS := 10
const QUIET_ZONE := 4
const MODULE_SCALE := 10


static func make_texture(text: String) -> Texture2D:
	var matrix := make_matrix(text)
	if matrix.is_empty():
		return null
	var image_size := (MODULE_COUNT + QUIET_ZONE * 2) * MODULE_SCALE
	var image := Image.create(image_size, image_size, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	for y in MODULE_COUNT:
		for x in MODULE_COUNT:
			if matrix[y][x]:
				var position := Vector2i((x + QUIET_ZONE) * MODULE_SCALE, (y + QUIET_ZONE) * MODULE_SCALE)
				image.fill_rect(Rect2i(position, Vector2i(MODULE_SCALE, MODULE_SCALE)), Color.BLACK)
	return ImageTexture.create_from_image(image)


static func make_matrix(text: String) -> Array:
	var data := text.to_utf8_buffer()
	if data.is_empty() or data.size() > 32:
		return []
	var codewords := _make_codewords(data)
	var modules: Array = []
	var functions: Array = []
	for _y in MODULE_COUNT:
		var module_row: Array[bool] = []
		module_row.resize(MODULE_COUNT)
		module_row.fill(false)
		modules.append(module_row)
		var function_row: Array[bool] = []
		function_row.resize(MODULE_COUNT)
		function_row.fill(false)
		functions.append(function_row)
	_draw_function_patterns(modules, functions)
	_draw_codewords(modules, functions, codewords)
	_draw_format_bits(modules, functions, 0)
	return modules


static func _make_codewords(data: PackedByteArray) -> PackedByteArray:
	var bits: Array[int] = []
	_append_bits(bits, 0x4, 4)
	_append_bits(bits, data.size(), 8)
	for value in data:
		_append_bits(bits, value, 8)
	var capacity := DATA_CODEWORDS * 8
	_append_bits(bits, 0, mini(4, capacity - bits.size()))
	while bits.size() % 8 != 0:
		bits.append(0)

	var result := PackedByteArray()
	for offset in range(0, bits.size(), 8):
		var value := 0
		for bit in 8:
			value = (value << 1) | bits[offset + bit]
		result.append(value)
	var pad := 0xEC
	while result.size() < DATA_CODEWORDS:
		result.append(pad)
		pad = 0x11 if pad == 0xEC else 0xEC
	result.append_array(_reed_solomon_remainder(result, ECC_CODEWORDS))
	return result


static func _append_bits(target: Array[int], value: int, length: int) -> void:
	for index in range(length - 1, -1, -1):
		target.append((value >> index) & 1)


static func _reed_solomon_remainder(data: PackedByteArray, degree: int) -> PackedByteArray:
	var divisor := PackedByteArray()
	divisor.resize(degree)
	divisor[degree - 1] = 1
	var root := 1
	for _index in degree:
		for position in degree:
			divisor[position] = _finite_multiply(divisor[position], root)
			if position + 1 < degree:
				divisor[position] ^= divisor[position + 1]
		root = _finite_multiply(root, 0x02)

	var remainder := PackedByteArray()
	remainder.resize(degree)
	for value in data:
		var factor := value ^ remainder[0]
		for index in range(degree - 1):
			remainder[index] = remainder[index + 1]
		remainder[degree - 1] = 0
		for index in degree:
			remainder[index] ^= _finite_multiply(divisor[index], factor)
	return remainder


static func _finite_multiply(left: int, right: int) -> int:
	var result := 0
	var value := left
	var factor := right
	while factor > 0:
		if factor & 1:
			result ^= value
		factor >>= 1
		value <<= 1
		if value & 0x100:
			value ^= 0x11D
	return result


static func _draw_function_patterns(modules: Array, functions: Array) -> void:
	for index in MODULE_COUNT:
		_set_function(modules, functions, 6, index, index % 2 == 0)
		_set_function(modules, functions, index, 6, index % 2 == 0)
	_draw_finder(modules, functions, 3, 3)
	_draw_finder(modules, functions, MODULE_COUNT - 4, 3)
	_draw_finder(modules, functions, 3, MODULE_COUNT - 4)
	_draw_alignment(modules, functions, 18, 18)
	_draw_format_bits(modules, functions, 0)


static func _draw_finder(modules: Array, functions: Array, center_x: int, center_y: int) -> void:
	for offset_y in range(-4, 5):
		for offset_x in range(-4, 5):
			var x := center_x + offset_x
			var y := center_y + offset_y
			if x < 0 or y < 0 or x >= MODULE_COUNT or y >= MODULE_COUNT:
				continue
			var distance := maxi(absi(offset_x), absi(offset_y))
			_set_function(modules, functions, x, y, distance != 2 and distance != 4)


static func _draw_alignment(modules: Array, functions: Array, center_x: int, center_y: int) -> void:
	for offset_y in range(-2, 3):
		for offset_x in range(-2, 3):
			var distance := maxi(absi(offset_x), absi(offset_y))
			_set_function(modules, functions, center_x + offset_x, center_y + offset_y, distance != 1)


static func _draw_format_bits(modules: Array, functions: Array, mask: int) -> void:
	# Error correction level L has format value 1.
	var data := (1 << 3) | mask
	var remainder := data
	for _index in 10:
		remainder = (remainder << 1) ^ ((remainder >> 9) * 0x537)
	var bits := ((data << 10) | remainder) ^ 0x5412
	for index in 6:
		_set_function(modules, functions, 8, index, _bit(bits, index))
	_set_function(modules, functions, 8, 7, _bit(bits, 6))
	_set_function(modules, functions, 8, 8, _bit(bits, 7))
	_set_function(modules, functions, 7, 8, _bit(bits, 8))
	for index in range(9, 15):
		_set_function(modules, functions, 14 - index, 8, _bit(bits, index))
	for index in 8:
		_set_function(modules, functions, MODULE_COUNT - 1 - index, 8, _bit(bits, index))
	for index in range(8, 15):
		_set_function(modules, functions, 8, MODULE_COUNT - 15 + index, _bit(bits, index))
	_set_function(modules, functions, 8, MODULE_COUNT - 8, true)


static func _draw_codewords(modules: Array, functions: Array, codewords: PackedByteArray) -> void:
	var bit_index := 0
	var right := MODULE_COUNT - 1
	while right >= 1:
		if right == 6:
			right = 5
		for vertical in MODULE_COUNT:
			var upward := ((right + 1) & 2) == 0
			var y := MODULE_COUNT - 1 - vertical if upward else vertical
			for column in 2:
				var x := right - column
				if functions[y][x]:
					continue
				var dark := false
				if bit_index < codewords.size() * 8:
					dark = _bit(codewords[bit_index >> 3], 7 - (bit_index & 7))
				# Mask pattern 0 is valid for every QR version.
				if (x + y) % 2 == 0:
					dark = not dark
				modules[y][x] = dark
				bit_index += 1
		right -= 2


static func _set_function(modules: Array, functions: Array, x: int, y: int, dark: bool) -> void:
	modules[y][x] = dark
	functions[y][x] = true


static func _bit(value: int, index: int) -> bool:
	return ((value >> index) & 1) != 0
