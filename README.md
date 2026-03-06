# Musician's Command Center 🎛️

A powerful, low-latency, resilient macOS/Tablet application engineered explicitly for live stage performers to precisely control and manipulate audio backing tracks, cues, loops, and clicks during a performance.

Built with **Flutter**, **SoLoud**, and pure **Custom Canvas** rendering algorithms.

## Documentation

To explore the application deeply, please review our comprehensive documentation files:

* [**User Guide** (`docs/USER_GUIDE.md`)](./docs/USER_GUIDE.md): Learn how to ingest `.zip` stems, organize setlists, auto-detect CueTags, and mix tracks live.
* [**System Architecture** (`docs/ARCHITECTURE.md`)](./docs/ARCHITECTURE.md): An overview of our isolated state management, C++ Audio Bridging, and stateless configuration design logic.
* [**Technical Features** (`docs/FEATURES.md`)](./docs/FEATURES.md): In-depth look into the custom algorithms powering transient auto-detection, DSP waveform scraping, and continuous integration workflows.

## Quick Start

1. Clone the repository.
2. Initialize local Git pre-commit hooks: `git config core.hooksPath .githooks`
3. Run `flutter pub get`.
4. Launch on macOS: `flutter run -d macos`.
5. Import a `.zip` file of audio stems into the **Library** interface!

## Setup Dependencies (C++)
Because we use hardware-accelerated audio (`flutter_soloud`), compiling for the first time may require building local binaries using CMake on your respective platform toolchain natively. 

## CI/CD Pipeline
This repository leverages strict formatting checks `dart format`, memory analyzing heuristics `flutter analyze`, programmatic unit testing `flutter test --coverage`, and compiler testing natively inside GitHub Actions across Apple and Android architectures upon targeting the `main` or `develop` branches.
