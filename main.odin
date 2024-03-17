package main

import "core:fmt"
import rl "vendor:raylib"
import "core:mem"
import "core:os"
import "core:strings"


W :: 400
H :: 300
CW :: 160
CH :: 205

width : int = W
height : int = H
zoom : int = 1

Cart :: struct {
	image : rl.Image,
	texture : rl.Texture,
	loaded : bool,
}

WrongSizeErrorTimer : i32 = 0
IsConverted : bool = false

main :: proc() {
	rl.SetTraceLogLevel(.FATAL)
	when ODIN_DEBUG {
		track : mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}
	args := os.args[1:]
	if len(args) == 0 {
		GraphicsMode()
		return
	}
	if len(args) != 3 {
		fmt.eprintln(
			"  PicoRepico cmdline usage:",
			"repico <input.p8.png> <shell.png> <output.p8.png>",
			"Use only 160x205 png images with PICO-8 palette",
			sep = "\n",
		)
		return 
	}
	CmdMode(args)
} 

CartLoadError :: enum {
	None,
	Wrong_Size,
	Allocation_Error,
}

loadCart :: proc(target: ^Cart, filename: cstring) -> CartLoadError {
	unloadCart(target)
	target.image = rl.LoadImage(filename)
	if target.image.width != CW || target.image.height != CH {
		return CartLoadError.Wrong_Size
	}
	target.texture = rl.LoadTextureFromImage(target.image)
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


GraphicsMode :: proc() {
	cart := Cart{}
	target := Cart{}
	
	rl.InitWindow(W, H, "PicoRepico")
	rl.SetTargetFPS(60)

	hw : f32 = auto_cast width / 2
	hh : f32 = auto_cast height / 2
	buttonCartRect := rl.Rectangle{
		x = hw - CW - 20,
		y = 8,
		width = CW,
		height = CH,
	}
	buttonTargetRect := rl.Rectangle{
		x = hw + 20,
		y = 8,
		width = CW,
		height = CH,
	}
	convertButtonRect := rl.Rectangle{
		x = hw - 40,
		y = auto_cast height - 38,
		width = 80,
		height = 30,
	}

	for !rl.WindowShouldClose() {
		if WrongSizeErrorTimer > 0 {
			WrongSizeErrorTimer -= 1
		}

		mouse := rl.GetMousePosition()
		if rl.IsFileDropped() {
			droppedFiles := rl.LoadDroppedFiles()
			defer rl.UnloadDroppedFiles(droppedFiles)

			if droppedFiles.count == 1 {
				f := droppedFiles.paths[0]
				if mouse.x <= hw {
					fmt.eprintln("Got cart file: ", f)
					if loadCart(&cart, f) == .Wrong_Size {
						WrongSizeErrorTimer = 180
					}
				}
				if mouse.x > hw {
					fmt.eprintln("Got target file: ", f)
					if loadCart(&target, f) == .Wrong_Size {
						WrongSizeErrorTimer = 180
					}
				}
			}
		}

		rl.BeginDrawing()
		rl.GuiDummyRec(rl.Rectangle{0, 0, auto_cast width, auto_cast height}, "")

		rl.GuiButton(buttonCartRect, "Place here cart")
		rl.GuiButton(buttonTargetRect, "Place here target")
		
		if WrongSizeErrorTimer > 0 {
			rl.GuiLabel(rl.Rectangle{8, auto_cast height - 38, 100, 30}, "WRONG IMAGE SIZE")
		}

		if cart.loaded {
			rl.DrawTexture(cart.texture, auto_cast buttonCartRect.x, auto_cast buttonCartRect.y, rl.WHITE)
		}
		if target.loaded {
			rl.DrawTexture(target.texture, auto_cast buttonTargetRect.x, auto_cast buttonTargetRect.y, rl.WHITE)
		}

		if rl.GuiButton(convertButtonRect, "CONVERT!") {
			newCart := convertCart(cart.image, target.image)
			rl.ExportImage(newCart, "output.p8.png")
		}
		rl.EndDrawing()
	}

	unloadCart(&cart)
	unloadCart(&target)
}


CmdMode :: proc(args: []string) {
	argnames := []string {
		"input file",
		"shell file",
	}
	images := [2]rl.Image{}
	for i := 0; i < 2; i+=1 {
		if !strings.has_suffix(args[i], ".png") {
			fmt.eprintf("%v is not a .png file", argnames[i])
			return
		}

		images[i] = rl.LoadImage(strings.unsafe_string_to_cstring(args[i]))
		if !rl.IsImageReady(images[i]) {
			fmt.eprintf("can't load %v", argnames[i])
			return
		}
	}
	defer {
		for img in images {
			rl.UnloadImage(img)
		}
	}
	
	newCart := convertCart(images[0], images[1])
	defer rl.UnloadImage(newCart)

	if args[2] != "--" {
		rl.ExportImage(newCart, strings.unsafe_string_to_cstring(args[2]))
	} else {
		filesize : i32 = 0
		ptr := rl.ExportImageToMemory(newCart, ".png", &filesize)
		defer rl.MemFree(ptr)
		os.write_ptr(os.stdout, ptr, auto_cast filesize)
	}
	fmt.eprintln("done!")
}
