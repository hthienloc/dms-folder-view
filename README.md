# Folder View

A folder viewer widget that displays and manages files and directories on your screen.

<img src="screenshot.png" width="400" alt="Screenshot">

## Install

**Required:** This plugin requires [dms-common](https://github.com/hthienloc/dms-common) to be installed.

```bash
# 1. Install shared components
git clone https://github.com/hthienloc/dms-common ~/.config/DankMaterialShell/plugins/dms-common

# 2. Install this plugin
dms plugins install folderView
```

Or manually:

```bash
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
| Left Click Folder Title | Open folder selection dropdown (Desktop, Downloads, Music, Videos, Documents, Trash, Home, Custom...) |
| Left Click View Mode Icon | Open view mode selection dropdown (Grid, List, Compact) |
| Left Click Sort Icon | Open sorting options dropdown (Name, Date, Size, Type) |
| Left Click Zoom Icon | Open icon size selection dropdown (Small, Medium, Large, Extra Large) |
| Left Click `+` Icon | Open creation dropdown (New Folder, New Document) |
| Left Click File/Folder | Select/Highlight item |
| Ctrl + Left Click File/Folder | Toggle selection of item (multi-select) |
| Shift + Left Click File/Folder | Select range of items between last selection and clicked item |
| Left Click Empty Space | Clear all active file/folder selections |
| Middle Click Empty Space | Paste copied files/folders or clipboard screenshot images into active directory |
| Double Click File/Folder | Open using system default application |
| Middle Click File/Folder | Open context menu (Open, Copy, Copy Path, Rename, Move to Trash) for selected items |

## Requirements

- `wl-clipboard` - Required for copying actual files to the system clipboard (`wl-copy`).
- `glib2` (or `gio`) - Required for trashing files cleanly (`gio trash`).

## License

GPL-3.0

## Roadmap / TODO

- [ ] **Drag & Drop support:** Drag files directly from the widget into external windows (or vice versa to copy into the folder).
- [x] **Multi-file operations:** Select multiple items using Ctrl/Shift and perform bulk copies, moves, or trashing.
- [x] **File Search:** Add a small integrated search field in the header to filter large directories instantly.
- [x] **Folder & File Creation:** Add a quick action button to create new folders or empty text documents directly within the widget.
