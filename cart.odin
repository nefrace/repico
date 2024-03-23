package main

import rl "vendor:raylib"
import "core:strings"

CART_WIDTH :: 160
CART_HEIGHT :: 205

Cart :: struct {
	image : rl.Image,
	texture : rl.Texture,
	loaded : bool,
}

CartLoadError :: enum {
	None,
	Wrong_Size,
	Allocation_Error,
	Wrong_Type
}

loadCart :: proc(target: ^Cart, filename: cstring) -> CartLoadError {
	if !strings.has_suffix(string(filename), ".png") {
		return .Wrong_Type
	}
	unloadCart(target)
	target.image = rl.LoadImage(filename)
	if target.image.width != CART_WIDTH || target.image.height != CART_HEIGHT {
		return CartLoadError.Wrong_Size
	}
	target.texture = rl.LoadTextureFromImage(target.image)
	rl.SetTextureFilter(target.texture, .POINT)
	target.loaded = true
	return CartLoadError.None
}

unloadCart :: proc(target: ^Cart) {
	if target.loaded {
		rl.UnloadTexture(target.texture)
		rl.MemFree(target.image.data)
	}
	target.loaded = false
}

convertCart :: proc(cart: rl.Image, target: rl.Image) -> rl.Image {
	newCartImage := rl.ImageCopy(target)
	for x : i32 = 0; x < newCartImage.width; x += 1 {
		for y : i32 = 0; y < newCartImage.height; y += 1{
			targetCol := rl.GetImageColor(target, x, y)
			sourceCol := rl.GetImageColor(cart, x, y)
			newCol := rl.Color{
				targetCol.r & 0b11111100 | sourceCol.r & 0b00000011,
				targetCol.g & 0b11111100 | sourceCol.g & 0b00000011,
				targetCol.b & 0b11111100 | sourceCol.b & 0b00000011,
				targetCol.a & 0b11111100 | sourceCol.a & 0b00000011,
			}
			rl.ImageDrawPixel(&newCartImage, x, y, newCol)
		}
	}
	return newCartImage
}
