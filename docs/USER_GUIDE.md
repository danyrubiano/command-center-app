# Musician's Command Center - User Guide

## Introduction
The Musician's Command Center is a rock-solid macOS and tablet application exclusively designed for live stage performers to precisely control and manipulate audio backing tracks, cues, loops, and clicks during a performance.

## 1. Getting Started
- When you first load the App, navigate to the **Library** tab.
- Click the "+" button to import a compiled `.zip` file of your multitrack stems (e.g. `Song 1 (Stems).zip`).
- Your tracks will be processed natively, extracting `.wav` metadata automatically.
- Navigate to **Settings** to modify keywords (`click`, `clk`, `cues`, `guide`) that automatically map incoming ZIP files to separate Click/Cues logic buses.

## 2. Managing Setlists
- Hop over to the **Setlist** tab to organize your performance flow.
- You can freely drag-and-drop imported Sequences into a single continuous Setlist.
- Select an individual sequence to open the **Sequence Editor** to configure detailed routing parameters.

## 3. The Sequence Editor 
The core configuration workspace for a single underlying song.
- **Mixer Section**: Pre-mix Faders, Solo/Mute toggle banks, and default Left/Right headphone Panning controls.
- **Auto-Detect Tags**: Click "Auto-detect tags from Cues" to parse transient threshold spikes inside any track flagged as `cues` or `guide`. The engine will auto-generate sections indicating major transitions.
- **Manage Tags**: Rename sections logically (e.g. from "Section 1" to "Bridge 2"), insert custom `CueTags` at the playhead, or scrub to confirm alignment. Hit the floating Action Chips overlaying the Timeline to teleport the playhead!
- **Save Configuration**: Permanently embeds the JSON manifest into the Sequence's root logic.

## 4. Live Player Module
Built specifically for absolute focus on a dark stage.
- **Cinematic Time Readout**: Oversized, glowing duration formatting ensuring visibility.
- **Waveform Interaction**: The timeline graph renders your custom sections with bright orange markers. 
  - *Scrubbing:* Press anywhere on the black Canvas to instantly slide the playhead to that relative percentage. 
  - *Section Quick-Jumps:* Tap directly onto an orange Section marker text (e.g. "Chorus") generated from your CueTags to natively reset the playback head to that downbeat—at zero latency.
- **Track Isolation**: Immediately solo key instruments, control volume bounds, or adjust panning live.
- **Hardware Agnostic**: Ensure your outputs are correctly mapped within the Host OS output preferences. The AudioEngine will directly stream binary audio to that primary bus.
