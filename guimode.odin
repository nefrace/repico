package main


import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:slice"
import "core:bytes"
import "core:os"


W :: 640
H :: 480

width : int = W
height : int = H
zoom : int = 1

WrongSizeErrorTimer : i32 = 0
IsConverted : bool = false

FILENAME_MAX :: 255
fileNameBuffer : [FILENAME_MAX]byte
fileNameString := cstring(&fileNameBuffer[0])
editMode := false

fileListScrolling : i32 = 0
fileListActive : i32 = -1
fileListFocus : i32 = -1

fileList : rl.FilePathList


State :: enum {
	CartsInput,
	Export,
	GotError,
	Exported,
	FileSelect
}

GraphicsMode :: proc() {
	files = slice.into_dynamic(filesBuf[:])
	cart := Cart{}
	target := Cart{}
	fileListTarget : ^Cart

	DefaultName :string : "output.p8.png"
	for char, i in DefaultName {
		fileNameBuffer[i] = auto_cast char
	}

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

	//fontData := #load("font.ttf")
	//font := rl.LoadFontFromMemory(".ttf", raw_data(fontData), auto_cast len(fontData), 8, nil, 0)
	//font := rl.LoadFontEx("font.ttf", 32, nil, 0)
	//rl.GuiSetFont(font)
	//rl.GuiSetStyle(auto_cast rl.GuiControl.DEFAULT, auto_cast rl.GuiControlProperty.BORDER_COLOR_NORMAL, i32(rl.ColorToInt(rl.Color{211, 2, 255, 255})))

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
				fileListTarget = &cart
				cd(".")
				state = .FileSelect
			}
			if cart.loaded {
				rl.DrawTexturePro(cart.texture, cartRect, buttonCartRect, {0, 0}, 0, rl.WHITE)
			}
			if rl.GuiButton(buttonTargetRect, "Drag target\nshell here") {
				fileListTarget = &target
				cd(".")
				state = .FileSelect
			}
			if target.loaded {
				rl.DrawTexturePro(target.texture, cartRect, buttonTargetRect, {0, 0}, 0, rl.WHITE)
			}
			if !(cart.loaded && target.loaded) { rl.GuiDisable() }
			if rl.GuiButton(convertButtonRect, "CONVERT!") {
				state = .Export
			}
			rl.GuiEnable()

			if rl.GuiLabelButton(rl.Rectangle{auto_cast width-60, auto_cast height-20, 60, 20}, "by Nefrace") {
				rl.OpenURL("https://nefrace.itch.io")
			}
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
		case .FileSelect: {
			rl.GuiPanel(rl.Rectangle{4, 4, auto_cast width - 8, auto_cast height - 8}, "Select a file")
			if rl.GuiButton(rl.Rectangle{auto_cast width - 26, 8, 16, 16}, "#128#") {
				state = .CartsInput
			}
			if rl.GuiButton(rl.Rectangle{8, 30, 50, 22}, "Open") {
				if fileListActive == -1 {break}
				if rl.DirectoryExists(files[fileListActive]) {
					cd(files[fileListActive])
					break
				}
				if rl.GetFileExtension(files[fileListActive]) != ".png" {
					fmt.println("not a png")
					break
				}
				currentError = loadCart(fileListTarget, files[fileListActive])
				if currentError != .None {
					state = .GotError
				}
				state = .CartsInput

			}
			if rl.GuiButton(rl.Rectangle{60, 30, 50, 22}, "Up") {
				cd("..")
			}
			rl.GuiSetStyle(auto_cast rl.GuiControl.LISTVIEW, auto_cast rl.GuiControlProperty.TEXT_ALIGNMENT, auto_cast rl.GuiTextAlignment.TEXT_ALIGN_LEFT)
			res := rl.GuiListViewEx(rl.Rectangle{8, 54, auto_cast width - 16, auto_cast height - 62}, filesPtr, auto_cast filesCount, &fileListScrolling, &fileListActive, &fileListFocus)
		}
		}
		
		rl.EndDrawing()
	}

	unloadCart(&cart)
	unloadCart(&target)
}

filesBuf : [1024*8]cstring
files : [dynamic]cstring
filesPtr : [^]cstring
filesCount : i32 = 0

cd :: proc(dir: cstring) -> (result: bool) {
	result = rl.ChangeDirectory(dir)
	rl.UnloadDirectoryFiles(fileList)
	clear(&files)
	fileList = rl.LoadDirectoryFiles(".")

	for fname in fileList.paths[:fileList.count] {
		if rl.DirectoryExists(fname) || rl.GetFileExtension(fname) == ".png" {
			append(&files, fname)
		}
	}

	slice.sort_by(files[:], proc(i,j:cstring) -> bool {
		a := string(i)
		b := string(j)
		adir := rl.DirectoryExists(i)
		bdir := rl.DirectoryExists(j)
		if (adir && bdir) || (!adir && !bdir) {
			return strings.compare(a, b) == -1
		}
		return adir && !bdir
	})

	filesPtr = raw_data(files)
	filesCount = auto_cast len(files)


//	slice.sort_by_cmp(fileList.paths[:fileList.count], strings.compare())
	fileListScrolling = 0
	fileListActive = -1
	fileListFocus = -1
	return
}
