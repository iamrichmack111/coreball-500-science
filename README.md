# Coreball 500 Science — V15

[![CI](https://github.com/iamrichmack111/letter-raider-3d/actions/workflows/ci.yml/badge.svg)](https://github.com/iamrichmack111/letter-raider-3d/actions/workflows/ci.yml)
[![Pages](https://github.com/iamrichmack111/letter-raider-3d/actions/workflows/pages.yml/badge.svg)](https://github.com/iamrichmack111/letter-raider-3d/actions/workflows/pages.yml)
[![Release](https://img.shields.io/github/v/release/iamrichmack111/letter-raider-3d)](https://github.com/iamrichmack111/letter-raider-3d/releases)


This build intentionally follows the simple classic Core Ball presentation:

- Dark purple playfield
- Dark center core
- Pink radial pins
- Pink numbered vertical queue
- Level 1 starts with 4 attached pins and 6 queued balls
- The entire attached-pin field rotates as one rigid object
- Fired ball travels straight upward
- 2 ms physics substeps prevent pins from tunneling through one another
- Collision stops at first contact
- Short 90 ms impact hold; no overlapping/glitch animation
- After every lost heart, a science question appears
- Correct answer restores that lost heart
- Wrong answer keeps the heart loss
- 3 / 5 / 7 heart modes
- 50% and 25% slow options
- 500 original deterministic levels

## Run

```bash
chmod +x start.sh
./start.sh
```

The launcher automatically picks the first free port from 8080–8199.

## Controls

- Tap board / FIRE / Space / Enter: launch
- S: Slow 50%
- F: Slow 25%
- P: Pause
- R: Retry

## Architecture

![Coreball Architecture](docs/architecture.svg)

The project uses a lightweight HTML5 Canvas game engine with deterministic levels, rotating-pin collision mechanics, hearts, slow-motion power-ups, science bonus-life questions, Playwright browser testing, GitHub Actions CI/CD, and GitHub Pages deployment.

## Project Automation

- 500 game levels
- Playwright smoke tests
- Automated screenshots
- Demo-video workflow
- GitHub Actions CI
- GitHub Pages deployment
- D2 architecture documentation
- GitHub Wiki
- Tagged GitHub releases
