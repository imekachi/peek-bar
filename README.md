<p align="center">
  <img src="PeekBar/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="PeekBar app icon">
</p>

<h1 align="center">PeekBar</h1>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-lightgrey.svg" alt="platform">
  <img src="https://img.shields.io/badge/requirement-macOS%2026.0%2B-blue.svg" alt="requirement">
</p>

## Overview

PeekBar hides menu-bar clutter so your Mac feels cleaner.

Inspired by [Hidden Bar](https://github.com/dwarvesf/hidden).

## Install

There're 2 ways to install PeekBar:

### 1. Download from release page

Download the latest version from the [Releases page](https://github.com/imekachi/peek-bar/releases/latest), then open the app.

### 2. Build from source

```sh
brew install xcodegen
xcodegen generate
open PeekBar.xcodeproj
```

Then build and run the `PeekBar` scheme in Xcode.

## Usage

Click the PeekBar toggle in the menu bar to collapse or expand hidden items.

Use macOS Command-drag (`⌘` + drag) to arrange menu-bar icons around PeekBar's separators. Items placed in the always-hidden area stay hidden until you move them out again.

Right-click the menu-bar item to open Settings and configure launch behavior, automatic collapse, and update options.

## Requirement

macOS version >= 26.0
