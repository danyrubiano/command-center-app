# Musician's Command Center - Architecture Overview

## 1. System Design Principles
The Musician's Command Center application is designed to be a highly resilient, low-latency audio control interface for live stage performances. Because live environments demand extreme reliability, the architecture emphasizes:
- **Zero-Latency Audio Pipeline**: Direct hardware-accelerated C++ audio bridging via `flutter_soloud`.
- **Stateless Configuration Injection**: Sequence configuration data (`.sequence_config.json`) is stored adjacent to the raw `.wav` stems in local device storage, meaning sequences can be arbitrarily moved or backed up without breaking the database. 
- **Isolated State Management**: Screens aggressively dispose and teardown memory-heavy visual assets (like raw Waveform Canvas instances) when transitioning.

## 2. Core Components

### A. Core Services (`lib/core/services/`)
- **`AudioEngineService`**: The nexus of the application. Handles track instantiations, routing discrete audio stems to left/right output channels (e.g., Click/Cues default routing to L/R), managing Unity Gain calculations, and executing playhead `seek()` commands directly against the SoLoud engine.
- **`FileExtractionService`**: Handles ingestion. Automatically unzips `.zip` payloads containing stems, builds a `Sequence` object by scanning filenames (auto-identifying keywords like "clk" or "guide" to map Tracks), and persists `.sequence_config.json` updates back to disk.
- **`SetlistService`**: Manages the structured JSON arrays representing distinct Setlists, allowing users to reorder `Sequence` items efficiently without duplicating the heavy `.wav` files.
- **`WaveformService`**: Connects via `just_waveform` to run asynchronous offline renders of stems to synthesize graphical representations. Handles transient auto-detection algorithms pointing explicitly to high-energy spikes in vocal cue tracks to automatically map `CueTags`.
- **`SettingsService`**: A `SharedPreferences` singleton that persists global configurations such as custom Click/Cue keyword dictionaries and preferred root storage path logic.

### B. Core Models (`lib/core/models/`)
- **`Sequence`**: A serialized wrapper containing metadata (BPM, Key, Name), a list of `CueTag` sections, and a nested list of `Track` models representing the actual `.wav` layers.
- **`Track`**: Encapsulates data for an individual audio layer, maintaining volume floats, panning integers, mute/solo flags, and dynamic routing configurations.
- **`CueTag`**: Time-stamped objects correlating a `String` name ("Chorus 1") to an exact `Duration`. 

## 3. Core Presentation Features (`lib/features/`)
The application is bifurcated into distinct modular capabilities:
1. **Library (`features/library`)**: File ingestion hub, ZIP parsing, deleting, and initial visual routing.
2. **Setlist (`features/setlist`)**: Setlist construction and the `SequenceEditorPage` for configuring granular tracking metadata, managing auto-detected `CueTags`, trimming/seeking, and verifying routing mixes asynchronously.
3. **Player (`features/player`)**: The Live environment interface. High-contrast, dark-mode Canvas rendering with aggressive touch-hit detection optimizations. 

## 4. Audio Processing Graph
1. Stems (`.wav`) loaded into memory via SoLoud `loadAudio` handles.
2. Individual `Voice` nodes played asynchronously via `play3d`.
3. Volumes manipulated natively at the C++ buffer level before hitting CoreAudio frameworks.
4. Active instances destroyed completely when `Sequence` context switches to avert Memory-Leak scenarios.
