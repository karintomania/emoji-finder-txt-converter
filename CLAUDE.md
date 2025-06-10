# CLAUDE.md

## Project Overview

This is a part of emoji finder terminal application written in Zig.
The project aims to provide blazing fast fuzzy search for emojis with an fzf-like terminal interface.
This repo contains the code to generate emoji.json from emoji.txt and keywords.jsonl, which will be used for search.

## Data Sources

- `emoji.txt`: Contains Unicode emoji data in the format `CODEPOINT ; STATUS # EMOJI VERSION DESCRIPTION`
- `keywords.jsonl`: To be added in the later version. Keywords will be stored in JSON-Lines format: `{ "😀": ["grinning", "smile", ...] }`

## Build Commands

```bash
# Build the project
zig build

# Run the application
zig build run

# Run tests
zig build test
```