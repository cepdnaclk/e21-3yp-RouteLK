# Bus Tracker App - Navigation Flow

## Updated App Structure

The app now has a three-tier navigation structure:

### 1. Splash Page (Entry Point)
- **File**: `lib/pages/splash_page.dart`
- **Features**:
  - Animated bus logo with fade-in effect
  - App name and tagline
  - Auto-navigates to Home Page after 3 seconds
  - Deep orange gradient background

### 2. Home Page (Main Menu)
- **File**: `lib/pages/home_page.dart`
- **Features**:
  - App information card with key features
  - Two service navigation options:
    - **Live Bus Tracking** → Opens map page
    - **AC Bus Booking** → Opens booking page
  - Beautiful gradient UI with animated cards
  - Feature descriptions:
    - Real-time bus tracking
    - AC bus booking
    - Multiple routes
    - Passenger count information

### 3. Service Pages

#### a) Live Bus Tracking
- **File**: `lib/pages/bus_map_page.dart`
- Real-time bus location tracking
- Route filtering
- Occupancy information
- Interactive map with markers

#### b) AC Bus Booking (Placeholder)
- **File**: `lib/pages/ac_bus_booking_page.dart`
- "Coming Soon" placeholder page
- Lists planned features:
  - Browse AC bus routes
  - Select travel date and time
  - Choose preferred seats
  - Secure online payment
  - Instant booking confirmation
- Can be easily replaced with actual booking functionality

## Navigation Flow

```
SplashPage (3 seconds)
    ↓
HomePage (App Info + Options)
    ├── Live Bus Tracking → BusMapPage
    └── AC Bus Booking → ACBusBookingPage
```

## Page Details

### Splash Page
- **Duration**: 3 seconds
- **Animation**: Fade-in effect
- **Color Scheme**: Deep orange with white text
- **Auto-navigation**: Yes

### Home Page
- **Layout**: Single scroll view with cards
- **Sections**:
  1. Header with logo
  2. About section with 4 feature items
  3. Service selection with 2 cards
- **Navigation**: Push-based (back button available)

### AC Bus Booking Page
- **Status**: Placeholder for future implementation
- **Purpose**: Shows "Coming Soon" message with planned features
- **Back Navigation**: Yes (back button to return to home)

## How to Extend

### Adding New Services
To add a new service option on the home page:

1. Create a new page in `lib/pages/`
2. Add a new service card in `home_page.dart`:
   ```dart
   _buildServiceCard(
     context,
     icon: Icons.your_icon,
     title: 'Your Service',
     description: 'Service description',
     color: Colors.yourColor,
     onTap: () {
       Navigator.of(context).push(
         MaterialPageRoute(builder: (_) => const YourPage()),
       );
     },
   ),
   ```

### Implementing AC Bus Booking
Replace the placeholder content in `ac_bus_booking_page.dart` with:
- Route search functionality
- Date/time selection
- Seat selection UI
- Payment gateway integration
- Booking confirmation

## File Structure

```
lib/
├── main.dart                          # Entry point (starts with SplashPage)
├── pages/
│   ├── splash_page.dart              # Animated splash screen
│   ├── home_page.dart                # Main menu with app info
│   ├── bus_map_page.dart             # Live bus tracking map
│   └── ac_bus_booking_page.dart      # Booking placeholder
├── models/
│   └── bus_data.dart
├── services/
│   ├── location_service.dart
│   └── firebase_bus_service.dart
├── widgets/
│   ├── bus_marker.dart
│   ├── route_selector.dart
│   └── bus_info_card.dart
└── utils/
    └── map_utils.dart
```

## Running the App

```bash
flutter run -d chrome
```

Or select your preferred device/emulator in VS Code.
