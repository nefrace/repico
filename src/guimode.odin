package main

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:slice"
import "core:bytes"
import "core:os"

import tfd "./tinyfiledialogs"

W :: 640
H :: 480

width : int = W
height : int = H
zoom : int = 1

IsConverted : bool = false

lastFilePathBuffer : [2048]byte
lastFilePath := cstring(&lastFilePathBuffer[0])


State :: enum {
	CartsInput,
	GotError,
	Exported,
}

GraphicsMode :: proc() {
	cart := Cart{}
	target := Cart{}

	copy(lastFilePathBuffer[:], "./")
	
	errorMessages := map[CartLoadError]cstring {
		.None = "",
		.Wrong_Size = "The image has wrong dimensions!\n160x205 PNG file expected",
		.Wrong_Type = "The image is not a PNG file!\n160x205 PNG file expected",
		.Allocation_Error = "Allocation error!",
	}
	defer delete(errorMessages)
	currentError := CartLoadError.None
	
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .INTERLACED_HINT})
	rl.InitWindow(W, H, "PicoRepico")
	rl.SetTargetFPS(60)

	hw : f32 = auto_cast width / 2
	hh : f32 = auto_cast height / 2
	state := State.CartsInput

	for !rl.WindowShouldClose() {
		width = auto_cast rl.GetScreenWidth()
		height = auto_cast rl.GetScreenHeight()
		hw = auto_cast width / 2
		hh = auto_cast height / 2

		switch state {
		case .CartsInput: {
			mouse := rl.GetMousePosition()
			if rl.IsFileDropped() {
				droppedFiles := rl.LoadDroppedFiles()
				defer rl.UnloadDroppedFiles(droppedFiles)

				if droppedFiles.count == 1 {
					f := droppedFiles.paths[0]
					if mouse.x <= hw {
						fmt.eprintln("Got cart file: ", f)
						currentError = loadCart(&cart, f)
						if currentError != .None {
							state = .GotError
						}
					}
					if mouse.x > hw {
						fmt.eprintln("Got target file: ", f)
						currentError = loadCart(&target, f) 
						if currentError != .None {
							state = .GotError
						}
					}
				}
			}

			zoom = 1
			if width >= 640 && height > 450 {
				zoom = 2
			}

			buttonCartRect := rl.Rectangle{
				x = hw - CART_WIDTH * f32(zoom) - 5,
				y = 8,
				width = CART_WIDTH * f32(zoom),
				height = CART_HEIGHT * f32(zoom),
			}
			buttonTargetRect := rl.Rectangle{
				x = hw + 5,
				y = 8,
				width = CART_WIDTH * f32(zoom),
				height = CART_HEIGHT * f32(zoom),
			}
			cartRect := rl.Rectangle{0, 0, CART_WIDTH, CART_HEIGHT}
			convertButtonRect := rl.Rectangle{
				x = hw - 40,
				y = auto_cast height - 38,
				width = 80,
				height = 30,
			}

			rl.BeginDrawing()
			rl.GuiDummyRec(rl.Rectangle{0, 0, auto_cast width, auto_cast height}, "")
			
			if rl.GuiButton(buttonCartRect, "Drag original\ncart here") {
				currentError = openDialogAndLoadCart(&cart)
				if currentError != .None {
					state = .GotError
				}
			}
			if cart.loaded {
				rl.DrawTexturePro(cart.texture, cartRect, buttonCartRect, {0, 0}, 0, rl.WHITE)
			}
			if rl.GuiButton(buttonTargetRect, "Drag target\nshell here") {
				currentError = openDialogAndLoadCart(&target)
				if currentError != .None {
					state = .GotError
				}
			}
			if target.loaded {
				rl.DrawTexturePro(target.texture, cartRect, buttonTargetRect, {0, 0}, 0, rl.WHITE)
			}
			if !(cart.loaded && target.loaded) { rl.GuiDisable() }
			if rl.GuiButton(convertButtonRect, "CONVERT!") {
				result := tfd.saveFileDialog("Select path to out cart", lastFilePath, {"*.png"}, "PNG image")
				if result != "" {
					newCart := convertCart(cart.image, target.image)
					rl.ExportImage(newCart, result)
					state = .Exported
				}
			}
			rl.GuiEnable()

			if rl.GuiLabelButton(rl.Rectangle{auto_cast width-60, auto_cast height-20, 60, 20}, "by Nefrace") {
				rl.OpenURL("https://nefrace.itch.io")
			}
		}
		case .Exported: {
			if rl.GuiMessageBox(rl.Rectangle{hw-110, 80, 220, 120}, "Success!", "Cart was exported successfully", "CLOSE") != -1 {
				state = .CartsInput
			}
		}
		case .GotError: {
			if rl.GuiMessageBox(rl.Rectangle{hw-150, 30, 300, 200}, "ERROR", errorMessages[currentError], "CLOSE") != -1 {
				state = .CartsInput
			}
		}
		}
		
		rl.EndDrawing()
	}

	unloadCart(&cart)
	unloadCart(&target)
}

openDialogAndLoadCart :: proc(cart: ^Cart) -> CartLoadError {
	result := tfd.openFileDialog("Select PNG", lastFilePath, {"*.png"}, "PNG images", false)
	if result != "" {
		slice.fill(lastFilePathBuffer[:], 0)
		copy(lastFilePathBuffer[:], string(result))
		return loadCart(cart, result)
	}
	return .None
}
