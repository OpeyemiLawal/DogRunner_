# Endless Runner Procedural Generation System

## Overview
This system provides endless runner functionality for your dog runner game using your road1.tscn and other road chunks.

## Features
- **Endless Road Generation**: Automatically spawns road chunks as the player runs
- **Multiple Road Variations**: Supports road1.tscn, road2.tscn, and road3.tscn
- **Procedural Props**: Randomly spawns props (prop1.tscn to prop15.tscn) on road chunks
- **Performance Optimization**: Removes chunks behind the player to maintain performance
- **Debug UI**: Shows real-time information about chunk generation

## How It Works

### Core Components
1. **WorldGenerator.gd**: Main procedural generation script
2. **roadHolder**: Node that contains all spawned road chunks
3. **DebugUI**: Shows chunk count and player position

### Generation Parameters
- `CHUNK_LENGTH = 18.0`: Size of each road chunk
- `INITIAL_CHUNKS = 5`: Initial road chunks spawned at start
- `SPAWN_DISTANCE = 50.0`: Distance from player to spawn new chunks
- `DESPAWN_DISTANCE = 100.0`: Distance behind player to remove chunks
- `MAX_CHUNKS = 20`: Maximum chunks kept in memory

### Spawn Process
1. Spawns 5 initial road chunks in a line
2. As the dog runs, new chunks spawn when approaching the end
3. Old chunks are removed when they're too far behind
4. Each chunk randomly spawns 0-3 props on it
5. Road chunks are randomly selected from available variations

## Usage
1. Open `Scenes/WorldGenerator.tscn` as your main scene
2. The system automatically loads all road and prop scenes
3. Debug UI shows real-time generation info
4. Use arrow keys or swipe to control the dog

## Customization
- Add more road chunks by creating new .tscn files in `Scenes/Chunks/`
- Add more props by creating propX.tscn files
- Adjust generation parameters in WorldGenerator.gd
- Modify prop spawn density in `_spawn_props_on_chunk()`

## Performance Tips
- The system maintains a maximum of 20 chunks for optimal performance
- Chunks are automatically recycled to prevent memory issues
- Props are randomly spawned with controlled density

## Debug Information
The DebugUI shows:
- Current number of active chunks
- Player position
- Distance to next spawn point

This system creates an endless running experience with varied terrain and props while maintaining smooth performance.
