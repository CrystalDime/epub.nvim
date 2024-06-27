# epub.nvim

A Neovim plugin for reading EPUB files directly in your editor.

Inspired by [bk](https://github.com/aeosynth/bk)

## Features

- Open and read EPUB files within Neovim
- Navigate through chapters
- Remember last read position
- Formatting support (bold, italic, underline)

## Requirements

- Neovim 0.10+
- unzip
  
## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "CrystalDime/epub.nvim",
  opts = {
    -- your configuration comes here
    -- or leave it empty to use the default settings
  },
  config = true,
}
```

## Configuration

Here are the default options:
```lua
{
  auto_open = false, -- Enable automatic opening of EPUBs
  output_dir = vim.fn.stdpath("cache") .. "/epub_reader", -- Default output directory (where epubs are unziped)
  data_dir = vim.fn.stdpath("data") .. "/epub_reader", -- Persistent data directory
}
```

## Usage

### Commands

- `:EpubOpen <path_to_epub>`: Open an EPUB file

### Keymaps

When an EPUB is open:

- `]c`: Next chapter
- `[c`: Previous chapter
- `gt`: Show table of contents

### API

- `require("epub").setup(opts)`: Set up the plugin with custom options
- `require("epub").open_epub(path)`: Programmatically open an EPUB file

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.

---
