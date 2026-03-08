# Musician's Command Center - Technical Features

## Audio Engine Pipeline (C++ Dart Integration)
- **`flutter_soloud` Framework**: High-performance cross-platform audio engine written natively in C and C++, wrapped securely inside Dart isolated instances. 
- **Unity Gain Scaling**: Volumes mapped from absolute linear constraints `0.0 (Silence)` to `1.0 (Full Pass)`. 
- **Dynamic Bus Configuration**: Live tracking channels mapping dynamic `pan` bounds from `-100.0 (Hard Left Mono)` to `100.0 (Hard Right Mono)`.
- **In-Ear Monitor Logic Bypass (Auto-Router)**: Configurable rules engine inside `Settings` forcing track arrays detected as Clicks or Cues to inherently map 100% Left on ingest.

## DSP & Waveform Analysis
- **`just_waveform` Interoperability**: Decodes pure audio headers parsing amplitudes inside large multi-minute `.wav` stems accurately off the main UI rendering thread. Output is downsampled efficiently via `Waveform.getPixelMin` caching.
- **Transient Automatic Tagging Algorithms**: Programmatic sequence scanning looping through the detected `Cue` waveform. Detects prominent absolute peaks crossing empirical `.15` noise floors, capturing consecutive instances mapping accurately into isolated `CueTag` durations indicating structural vocal phrases across song timelines.

## Data Schema & Storage Architecture
- **`.sequence_config.json` Sidecars**: State is entirely disconnected from centralized SQLite DB monoliths. All logic, volumes, keys, BPMs, names, tracking parameters, and `CueTag` durations are mapped into isolated `Map<String, dynamic>` structures serialized natively into a sidecar next to the raw audio assets inside isolated app folders (`ApplicationDocumentsDirectory`). Moving a folder moves the entire internal mix session seamlessly.

## Continuous Integration & Continuous Deployment (CI/CD)
- **GitHub Actions Runner Automation**: Workflows targeting `macos-latest` configured automatically for `push` events onto branch rules (like `main`, `develop`).
- **Headless Build Matrix Pipeline**:
  - `dart format` execution catching strict styling violations on PR diffs.
  - `flutter analyze` validating memory management heuristics across context lifecycles.
  - `flutter test` spinning isolated `TestWidgetsFlutterBinding` instances executing granular, high-coverage unit tests across both logical models (`Sequence`, `Track`, `Setlist`, `Settings`) and complex side-effecting algorithms (`FileExtractionService`, `AudioEngineService`, `SetlistService`). Tests utilize `mocktail` for wrapping C++ FFI bindings (such as `flutter_soloud`) and leverage `dart:io` memory-sandboxing to validate actual physical logic mapping without corrupting host state.
- **Compiling AppBundles & iOS Binaries**: Validates the cross-platform toolchains by executing `release --no-codesign` routines confirming upstream Dart commits won't break upstream Apple/Google builds cleanly.

## Responsive UI Capabilities
- **Direct Canvas Hit-Testing**: Absolute replacement over generic Flutter Widgets (like `InkWell` layout boundaries). The application calculates `(localX / box.size.width)` explicitly off of gesture constraints over a custom `RenderBox` matching exact playback positions or bounding pixel hits matching overlapping Section overlays rendered natively in `paint()`. Allows for dense UI visualizations overlaid simultaneously over active waveform inputs without compromising UI framerates natively.
