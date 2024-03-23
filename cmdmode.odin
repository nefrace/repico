package main

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:os"


CmdMode :: proc(args: []string) {
	if len(args) < 2 || len(args) > 3 {
		fmt.eprintln(
			"  PicoRepico cmdline usage:",
			"repico <input.p8.png> <shell.png> <output.p8.png>",
			"Use only 160x205 png images with PICO-8 palette",
			sep = "\n",
		)
		return 
	}
	outToStd := false
	if len(args) == 2 {
		outToStd = true
	}

	argnames := []string {
		"Input file",
		"Shell file",
	}
	images := [2]rl.Image{}
	for i := 0; i < 2; i+=1 {
		if !strings.has_suffix(args[i], ".png") {
			fmt.eprintf("ERROR: %v is not a .png file\n", argnames[i])
			os.exit(auto_cast os.EINVAL)	
		}

		images[i] = rl.LoadImage(strings.unsafe_string_to_cstring(args[i]))
		if !rl.IsImageReady(images[i]) {
			fmt.eprintf("ERROR: can't load %v\n", argnames[i])
			os.exit(auto_cast os.EIO)
		}

		if images[i].width != CART_WIDTH || images[i].height != CART_HEIGHT {
			fmt.eprintf("ERROR: %v has wrong dimensions. 160x205 is expected\n", argnames[i])
			rl.UnloadImage(images[i])
			os.exit(auto_cast os.EINVAL)
		}
	}
	defer {
		for img in images {
			rl.UnloadImage(img)
		}
	}
	
	newCart := convertCart(images[0], images[1])
	defer rl.UnloadImage(newCart)

	if !outToStd {
		rl.ExportImage(newCart, strings.unsafe_string_to_cstring(args[2]))
	} else {
		filesize : i32 = 0
		ptr := rl.ExportImageToMemory(newCart, ".png", &filesize)
		defer rl.MemFree(ptr)
		os.write_ptr(os.stdout, ptr, auto_cast filesize)
	}
	fmt.eprintln("done!")
}
