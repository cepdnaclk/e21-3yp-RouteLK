# Bus Tracker - Code Structure

## Overview
The codebase has been refactored into a clean, maintainable architecture following Flutter best practices.

## Directory Structure

```
lib/
├── main.dart                          # App entry point (28 lines)
├── firebase_options.dart              # Firebase configuration
│
├── models/                            # Data models
│   └── bus_data.dart                 # BusData model with occupancy logic
│
├── services/                          # Business logic & external services
│   ├── location_service.dart         # Location & permissions handling
│   └── firebase_bus_service.dart     # AppSync-backed bus location polling and pickup request handling
│
├── pages/                             # Screen/Page widgets
│   └── bus_map_page.dart             # Main map page with bus tracking
│
├── widgets/                           # Reusable UI components
│   ├── bus_marker.dart               # Bus map marker widget
│   ├── route_selector.dart           # Route filter dropdown widget
│   └── bus_info_card.dart            # Bus info display cards
│
└── utils/                             # Helper functions
    └── map_utils.dart                # Map calculation utilities
```

## Component Responsibilities

### Models (`models/`)
- **bus_data.dart**: Contains the `BusData` model with location, passenger count, route, and occupancy level calculations.

### Services (`services/`)
- **location_service.dart**: Handles geolocation permissions and current position retrieval.
- **firebase_bus_service.dart**: Manages AppSync bus location polling, filtering logic, and existing pickup request handling.

### Pages (`pages/`)
- **bus_map_page.dart**: Main screen that orchestrates the map display, coordinates services, and manages state.

### Widgets (`widgets/`)
- **bus_marker.dart**: Creates color-coded bus markers with occupancy indicators.
- **route_selector.dart**: Dropdown widget for filtering buses by route.
- **bus_info_card.dart**: Displays bus information cards, including `BusInfoCard`, `NoBusesMessage`, and `WaitingForDataMessage`.

### Utils (`utils/`)
- **map_utils.dart**: Helper functions for map operations like calculating bounds and fitting camera to multiple points.

## Benefits of This Structure

1. **Separation of Concerns**: Each file has a single, clear responsibility.
2. **Reusability**: Widgets can be easily reused across different screens.
3. **Testability**: Services and utilities can be unit tested independently.
4. **Maintainability**: Easy to locate and modify specific functionality.
5. **Scalability**: Adding new features is straightforward with clear organization.

## Key Improvements

- **Reduced main.dart**: From 709 lines to 28 lines
- **Modular widgets**: Easy to modify UI components independently
- **Testable services**: Business logic separated from UI
- **Clear data flow**: Models → Services → Pages → Widgets
- **Better code navigation**: Logical folder structure

## Running the App

The app functionality remains exactly the same. Simply run:
```bash
flutter run -d chrome
```

Or use the Flutter tools in VS Code to run on your desired platform.
