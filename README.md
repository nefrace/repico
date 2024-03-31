# RePico — PICO-8 shell replacer

RePico is small tool that allows user to replace visual shell of PNG carts used by PICO-8 fantasy console. It's my project made for the sake of practice writing something useful with Odin language and Raylib.
It was actually inspired by [another project](https://www.lexaloffle.com/bbs/?tid=50563) that did the same thing made with Godot engine

![repico](https://i.imgur.com/h4TuwgS.png)
I didn't really bother with styling that thing. It's just basic Raygui theme. You can drag-and-drop images into the slots and convert the cart! There's also a whole command line interface if you don't want to touch mouse and click GUI buttons!
![cmd](https://i.imgur.com/QHA9KxM.png)

## What do you mean "replace visual shell"?

Everyone who's familiar with PICO-8 fantasy console knows that the game carts it can read and write can be PNG images. Not everyone knows how it stores date inside these images.
The core of data storage here is a technique called "steganography". Basically it means "store some information inside other information". In case of the image we can embed some binary data inside the pixels of the image itself! PICO-8 carts use 2 least significant bits of every channel of the image to store ROM data. And the trick is to get another image that's similar in size and replace it's 2 least significant bits with the ones from original cart.

## Usage

Just open it and drag-n-drop the PICO-8 PNG cart you want to change the shell of in the left slot (or click it to open file dialog) and the target shell to the right one.

Or you can call it from the terminal and provide the filepaths as arguments:

```sh
repico cart shell [output]
```

- `cart` — the PICO-8 cart file
- `shell` — the target shell
- `output` — the output PNG cart (optional, you can send it to stdout and pipe somewhere if you want)

*The target shell should be **160x205 pixels PNG image using only colors from PICO-8 palette** or it will look messy in Splore*.

## Why even bother if such tool already exists?

For practice of course! You don't need to make something unique if you're just learning stuff.

## Binaries

There's none for now. Need to change some code and create scripts to make it buildable for Windows and MacOS (don't have any Apple computer so it might be a problem). After that they'll be available on Itch.

## Building

You'll need an [Odin compiler](https://odin-lang.org/) to do so. Also gcc for building the TinyFileDialogs as a static library which is included here to use native file dialogs in the application. 

It's only tested on Linux for now and all the build scripts and TinyFileDialogs bindings are written for Linux only. Gonna fix that later.

## Credits

- [Sosasses](https://www.lexaloffle.com/bbs/?uid=42335) — the author of "cartridge shell replacer" mentioned above
- [Vareille](https://sourceforge.net/u/vareille/profile/) — the author of [TinyFileDialogs](https://sourceforge.net/projects/tinyfiledialogs/)