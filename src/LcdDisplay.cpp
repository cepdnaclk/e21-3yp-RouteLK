#include "LcdDisplay.h"
#include <Wire.h>
#include <hd44780.h>
#include <hd44780ioClass/hd44780_I2Cexp.h>

// Pin Configuration
#define SDA_PIN   32
#define SCL_PIN   33
#define I2C_FREQ  50000   // 50 kHz — safe for cheap backpacks

// LCD Configuration
#define LCD_COLS  16
#define LCD_ROWS  2

static hd44780_I2Cexp lcd;
static bool lcdReady = false;

// Scan all I2C addresses and return the first device found.
static uint8_t i2cScan() {
  Serial.println("\n[I2C] Scanning bus...");
  uint8_t found = 0;

  for (uint8_t addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    uint8_t err = Wire.endTransmission();

    if (err == 0) {
      Serial.printf("[I2C] Device found at 0x%02X\n", addr);
      if (found == 0) found = addr;
    }
  }

  if (found == 0) Serial.println("[I2C] No devices found!");
  return found;
}

// Try to initialise the LCD up to attempts times
static bool initLcd(uint8_t attempts = 3) {
  for (uint8_t i = 1; i <= attempts; i++) {
    Serial.printf("[LCD] Init attempt %d/%d ...\n", i, attempts);
    int status = lcd.begin(LCD_COLS, LCD_ROWS);

    if (status == 0) {
      Serial.println("[LCD] Init OK");
      return true;
    }

    Serial.printf("[LCD] Init failed (status=%d)\n", status);
    delay(500);
  }
  return false;
}

void setupLcd() {
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(I2C_FREQ);
  delay(500);

  uint8_t addr = i2cScan();
  if (addr == 0) {
    Serial.println("[ERROR] No I2C device found for LCD display.");
    return;
  }

  lcdReady = initLcd(3);
  if (!lcdReady) {
    Serial.println("[ERROR] LCD init failed.");
    return;
  }

  lcd.backlight();
  lcd.clear();
}

void playStartupAnimation() {
  if (!lcdReady) return;
  lcd.clear();
  
  // Typewriter "Hello RouteLK" on line 0
  const char* msg = " Hello RouteLK  ";
  lcd.setCursor(0, 0);
  for (int i = 0; i < 16; i++) {
    lcd.write(msg[i]);
    delay(60);
  }
  
  // Loading progress bar on line 1
  lcd.setCursor(0, 1);
  lcd.print("[              ]");
  for (int i = 0; i < 14; i++) {
    lcd.setCursor(i + 1, 1);
    lcd.write(0xFF); // Solid block character
    delay(100);
  }
  delay(300);
  
  // Flash backlight twice
  for (int i = 0; i < 2; i++) {
    lcd.noBacklight();
    delay(150);
    lcd.backlight();
    delay(150);
  }
  lcd.clear();
}


void displayTotalPickups(int count) {
  if (!lcdReady) return;
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("  Total Pickups ");
  
  // Center the count on the second line
  char buffer[17];
  int len = snprintf(buffer, sizeof(buffer), "%d", count);
  int spaces = (16 - len) / 2;
  
  lcd.setCursor(0, 1);
  for (int i = 0; i < spaces; i++) {
    lcd.print(" ");
  }
  lcd.print(buffer);
  for (int i = 0; i < (16 - len - spaces); i++) {
    lcd.print(" ");
  }
}

void displayTotalPickupsFetching() {
  if (!lcdReady) return;
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("  Total Pickups ");
  lcd.setCursor(0, 1);
  lcd.print("   Fetching...  ");
}

void displayPickupAlert(const char* alertMsg) {
  if (!lcdReady) return;
  lcd.clear();
  
  String msg = String(alertMsg);
  if (msg.startsWith("Pick up ")) {
    // Print "Pick up" centered on first line
    lcd.setCursor(4, 0);
    lcd.print("Pick up");
    
    // Print remaining text (e.g. "300 m ahead") centered on second line
    String remaining = msg.substring(8);
    int len = remaining.length();
    if (len > 16) remaining = remaining.substring(0, 16);
    int spaces = (16 - remaining.length()) / 2;
    lcd.setCursor(spaces, 1);
    lcd.print(remaining);
  } else {
    // General case: print on two lines
    lcd.setCursor(0, 0);
    lcd.print(msg.substring(0, 16));
    if (msg.length() > 16) {
      lcd.setCursor(0, 1);
      lcd.print(msg.substring(16, 32));
    }
  }
}

void displayClear() {
  if (!lcdReady) return;
  lcd.clear();
}

void displayDateTime(const char* dateStr, const char* timeStr) {
  if (!lcdReady) return;
  
  // Print Date left-aligned up to 10 chars
  lcd.setCursor(0, 0);
  char line1[17];
  snprintf(line1, sizeof(line1), "Date: %-10s", dateStr);
  lcd.print(line1);
  
  // Print Time left-aligned up to 8 chars
  lcd.setCursor(0, 1);
  char line2[17];
  snprintf(line2, sizeof(line2), "Time: %-10s", timeStr);
  lcd.print(line2);
}

void displayEmergencyAlert() {
  if (!lcdReady) return;
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Emegrncy Alert  ");
  lcd.setCursor(0, 1);
  lcd.print("      Sent      ");
}

void displayEmergencyActive() {
  if (!lcdReady) return;
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("   EMERGENCY    ");
  lcd.setCursor(0, 1);
  lcd.print("                ");
}

void displayEmergencyCleared() {
  if (!lcdReady) return;
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("   Emergency    ");
  lcd.setCursor(0, 1);
  lcd.print("    cleared     ");
}

void displayAllPickupsCleared() {
  if (!lcdReady) return;
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("  All pickups   ");
  lcd.setCursor(0, 1);
  lcd.print("    cleared     ");
}

