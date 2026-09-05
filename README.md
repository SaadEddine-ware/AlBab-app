# AlBab Student Hub

AI-powered desktop application for university students in Morocco.

## Features

- **AI Chat** — Gemini API with function calling (math, code, files, system)
- **14 Tools** — Calculator, Equation Solver, Graph Plotter, Formula Library, Linear Algebra, Graph Algorithms, Statistics, Geometry, 3D Mesh Editor, Timeline, Source Analyzer, World Map, Coordinate Calculator, Demographics
- **User Authentication** — Multi-account support with email login
- **Dark Mode** — Toggle between light and dark themes
- **Keyboard Shortcuts** — Ctrl+1-4 for page switching

## Installation

`ash
pip install -r requirements.txt
python main.py
`

## Configuration

1. Get a free Gemini API key from https://aistudio.google.com/apikey
2. Set the key in Settings or as environment variable GEMINI_API_KEY

## Project Structure

`
albab-app/
├── main.py              # Application entry point
├── core/                # Backend logic (15 modules)
├── ui/                  # QML UI files (28 components)
├── windows/             # Window backends
├── bin/                 # Bundled executables
├── data/                # User data
├── tests/               # Unit tests (82 tests)
└── requirements.txt     # Python dependencies
`

## Testing

`ash
python tests/test_core.py
python tests/test_user_manager.py
python tests/test_opencode.py
python tests/test_all_features.py
`

## License

Internal use only.
