# Emoji Finder

A blazing fast terminal-based emoji finder with fuzzy search, built in Zig.

## Features

- Fuzzy search for emoji by keywords
- fzf-like terminal interface
- Fast search performance
- Direct emoji output for easy copying

## Plan

### Phase 1: Data Integration
1. **Unicode Emoji Data Source**
   - Fetch emoji list from unicode.org
   - Parse fixed-length text format (emoji + Unicode codepoint)
   - Create data structure to store emoji metadata

2. **Keyword Data Source**
   - Parse JSON file containing emoji keywords
   - Structure: `{ "emoji": ["keyword1", "keyword2", ...] }`
   - Create mapping from emoji to keywords array

3. **Data Merging**
   - Combine Unicode data and keyword data
   - Create unified emoji database structure
   - Optimize data layout for fast search

### Phase 2: Search Engine
1. **Fuzzy Search Algorithm**
   - Implement lightweight fuzzy matching
   - Score matches based on relevance
   - Optimize for speed over perfect accuracy

2. **Search Index**
   - Build efficient search index from keywords
   - Support partial matching and typos
   - Return ranked results

### Phase 3: Terminal UI
1. **fzf-like Interface**
   - Real-time search as user types
   - Interactive selection from filtered results
   - Keyboard navigation (arrow keys, enter)

2. **Output**
   - Print selected emoji to stdout
   - Support for multiple selection modes

### Phase 4: Testing & Optimization
1. **Unit Tests**
   - Test data parsing modules
   - Test search algorithm accuracy and performance
   - Test data merging logic

2. **Performance Optimization**
   - Profile search performance
   - Optimize memory usage
   - Minimize startup time

## Technical Stack

- **Language**: Zig
- **UI**: Terminal-based (ncurses-like)
- **Data Sources**: Unicode.org + JSON keywords
- **Search**: Custom fuzzy search algorithm

## Build & Run

```bash
zig build
zig build run
```

## Test

```bash
zig build test
```