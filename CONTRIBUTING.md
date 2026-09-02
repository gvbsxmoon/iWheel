# Contributing

Thanks for your interest. Ground rules, in the spirit of keeping a small
project maintainable by one person:

- **Bugs**: search existing issues first. Include your macOS version,
  hardware (Apple Silicon / Intel), number of desktops, and what the
  terminal log printed. Screenshots or a short screen recording help a
  lot.
- **Features**: open an issue before writing code. The interaction model
  (hold 3, point with 2, release) is deliberately minimal - features
  that complicate the core gesture will likely be declined.
- **Pull requests**: match the existing style. Comment only non-obvious
  *why*, never narrate the code. Run `swift build` and `swift test`
  before submitting. Keep private-API surface area contained to the
  existing boundary files (MultitouchMonitor, SpaceManager, CursorHider,
  SymbolicHotkeys).
- Contributions are accepted under the MIT license.
