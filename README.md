# Folder View

A folder viewer widget that displays and manages files and directories on your screen.

<img src="screenshot.png" width="400" alt="Screenshot">

## Install

**Required:** This plugin requires [dms-common](https://github.com/hthienloc/dms-common) to be installed.

```bash
# 1. Install shared components
git clone https://github.com/hthienloc/dms-common ~/.config/DankMaterialShell/plugins/dms-common

# 2. Install this plugin
git clone https://github.com/hthienloc/dms-folder-view ~/.config/DankMaterialShell/plugins/folderView
```

## Features

- **Dynamic Folder Switcher** - Instantly swap between Desktop, Downloads, Music, Videos, Documents, or any Custom directory.
- **Three Elegant View Modes** - Grid View (traditional), List View (detailed list), and Compact View (ultra-compact, auto-wrapping into 2 columns if the widget is wide).
- **Direct Header Controls** - Toggle view modes and choose file sorting (Name, Date, Size, Type) directly from the widget header popups.
- **Rich Context Menu Actions** - Open files, copy actual files to clipboard (via `wl-copy`), copy paths, rename (with smart extension exclusion), and move to trash (`gio trash`).
- **Warm & Vibrant Design** - Premium dark mode styling, custom folder/file icons, glassmorphism backdrop, and responsive hover transitions.

## Usage

| Action | Result |
|--------|--------|
| Left Click Folder Title | Open folder selection dropdown |
| Left Click View Mode Icon | Open view mode selection dropdown |
| Left Click Sort Icon | Open sorting options dropdown |
| Double Click File/Folder | Open using system default application |
| Left Click File/Folder | Select/Highlight item |
| Middle Click File/Folder | Open quick action context menu (Open, Copy, Copy Path, Rename, Move to Trash) |

## Requirements

- `wl-clipboard` - Required for copying actual files to the system clipboard (`wl-copy`).
- `glib2` (or `gio`) - Required for trashing files cleanly (`gio trash`).

## License

GPL-3.0

## Roadmap / TODO

- [ ] **Drag & Drop support:** Drag files directly from the widget into external windows (or vice versa to copy into the folder).
- [ ] **Multi-file operations:** Select multiple items using Ctrl/Shift and perform bulk copies, moves, or trashing.
- [ ] **File Search:** Add a small integrated search field in the header to filter large directories instantly.
- [ ] **Folder Creation:** Add a quick action button to create new folders or empty text documents directly within the widget.
