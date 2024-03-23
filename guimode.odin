package main


import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:slice"
import "core:os"


W :: 400
H :: 300

width : int = W
height : int = H
zoom : int = 1

WrongSizeErrorTimer : i32 = 0
IsConverted : bool = false

FILENAME_MAX :: 255
fileNameBuffer : [FILENAME_MAX]byte
fileNameString := cstring(&fileNameBuffer[0])
editMode := false


State :: enum {
	CartsInput,
	Export,
	GotError,
	Exported
}

GraphicsMode :: proc() {
	cart := Cart{}
	target := Cart{}

	errorMessages := map[CartLoadError]cstring {
		.None = "",
		.Wrong_Size = "The image has wrong dimensions!\n160x205 PNG file expected",
		.Wrong_Type = "The image is not a PNG file!\n160x205 PNG file expected",
		.Allocation_Error = "Allocation error!",
	}
	defer delete(errorMessages)
	currentError := CartLoadError.None
	
	rl.SetConfigFlags({rl.ConfigFlag.WINDOW_RESIZABLE})
	rl.InitWindow(W, H, "PicoRepico")
	rl.SetTargetFPS(60)

	//fontData := #load("font.ttf")
	//font := rl.LoadFontFromMemory(".ttf", raw_data(fontData), auto_cast len(fontData), 8, nil, 0)
	font := rl.LoadFontEx("font.ttf", 32, nil, 0)
	rl.GuiSetFont(font)
	rl.GuiSetStyle(auto_cast rl.GuiControl.DEFAULT, auto_cast rl.GuiControlProperty.BORDER_COLOR_NORMAL, i32(rl.ColorToInt(rl.Color{211, 2, 255, 255})))

	hw : f32 = auto_cast width / 2
	hh : f32 = auto_cast height / 2
	state := State.CartsInput

	for !rl.WindowShouldClose() {
		if WrongSizeErrorTimer > 0 {
			WrongSizeErrorTimer -= 1
		}
		width = auto_cast rl.GetScreenWidth()
		height = auto_cast rl.GetScreenHeight()
		hw = auto_cast width / 2
		hh = auto_cast height / 2

		#partial switch state {
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

			buttonCartRect := rl.Rectangle{
				x = hw - CART_WIDTH - 20,
				y = 8,
				width = CART_WIDTH,
				height = CART_HEIGHT,
			}
			buttonTargetRect := rl.Rectangle{
				x = hw + 20,
				y = 8,
				width = CART_WIDTH,
				height = CART_HEIGHT,
			}
			convertButtonRect := rl.Rectangle{
				x = hw - 40,
				y = auto_cast height - 38,
				width = 80,
				height = 30,
			}

			rl.BeginDrawing()
			rl.GuiDummyRec(rl.Rectangle{0, 0, auto_cast width, auto_cast height}, "")
			rl.GuiButton(buttonCartRect, "Place here cart")
			rl.GuiButton(buttonTargetRect, "Place here target")
			
			if cart.loaded {
				rl.DrawTexture(cart.texture, auto_cast buttonCartRect.x, auto_cast buttonCartRect.y, rl.WHITE)
			}
			if target.loaded {
				rl.DrawTexture(target.texture, auto_cast buttonTargetRect.x, auto_cast buttonTargetRect.y, rl.WHITE)
			}
			if !(cart.loaded && target.loaded) { rl.GuiDisable() }
			if rl.GuiButton(convertButtonRect, "CONVERT!") {
				state = .Export
			}
			rl.GuiEnable()
		}
		case .Export: {
			res := rl.GuiTextInputBox(rl.Rectangle{hw - 100, 60, 200, 100}, "Input filename for result", "", "ok;cancel", fileNameString, FILENAME_MAX, nil)
			if res == 0 || res == 2 {
				state = .CartsInput
				slice.fill(fileNameBuffer[:], 0)
			}
			if res == 1 {
				newCart := convertCart(cart.image, target.image)
				rl.ExportImage(newCart, fileNameString)
				state = .Exported
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

