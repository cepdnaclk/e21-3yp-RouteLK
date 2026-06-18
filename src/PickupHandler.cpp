#include "PickupHandler.h"
#include "LcdDisplay.h"
#include <ArduinoJson.h>
#include <time.h>
#include <TinyGPSPlus.h>

extern TinyGPSPlus gps;

enum DisplayState {
  STATE_TOTAL_PICKS,
  STATE_ALERT,
  STATE_DATETIME,
  STATE_EMERGENCY_ALERT,
  STATE_EMERGENCY_ACTIVE,
  STATE_EMERGENCY_CLEARED,
  STATE_PICKUPS_CLEARED
};

static DisplayState state = STATE_TOTAL_PICKS;
static int totalPicks = 0;
static String currentAlertMsg = "";
static unsigned long alertStartTime = 0;
static unsigned long lastPickupChangeTime = 0;
static unsigned long dateTimeStartTime = 0;
static unsigned long lastDateTimeUpdate = 0;
static bool initialMessageReceived = false;
static unsigned long emergencyStartTime = 0;
static unsigned long emergencyClearedTime = 0;
static unsigned long clearAlertStartTime = 0;

static bool getSriLankaTime(char* dateStr, char* timeStr, size_t maxLen) {
  // Method 1: NTP via internal ESP32 RTC
  struct tm timeinfo;
  if (getLocalTime(&timeinfo, 10)) {
    // If the year is greater than 120 (since tm_year is years since 1900, so > 2020)
    if (timeinfo.tm_year > 120) {
      snprintf(dateStr, maxLen, "%02d/%02d/%04d", timeinfo.tm_mday, timeinfo.tm_mon + 1, timeinfo.tm_year + 1900);
      snprintf(timeStr, maxLen, "%02d:%02d:%02d", timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec);
      return true;
    }
  }
  
  // Method 2: Fallback to GPS
  if (gps.date.isValid() && gps.time.isValid() && gps.date.year() > 2020) {
    int yr = gps.date.year();
    int mn = gps.date.month();
    int dy = gps.date.day();
    int hr = gps.time.hour();
    int mt = gps.time.minute();
    int sc = gps.time.second();
    
    // Add timezone offset for Sri Lanka (+5:30)
    hr += 5;
    mt += 30;
    if (mt >= 60) {
      mt -= 60;
      hr += 1;
    }
    if (hr >= 24) {
      hr -= 24;
      dy += 1;
      
      int daysInMonth[] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
      // Leap year check
      if ((yr % 4 == 0 && yr % 100 != 0) || (yr % 400 == 0)) {
        daysInMonth[1] = 29;
      }
      if (dy > daysInMonth[mn - 1]) {
        dy = 1;
        mn += 1;
        if (mn > 12) {
          mn = 1;
          yr += 1;
        }
      }
    }
    
    snprintf(dateStr, maxLen, "%02d/%02d/%04d", dy, mn, yr);
    snprintf(timeStr, maxLen, "%02d:%02d:%02d", hr, mt, sc);
    return true;
  }
  
  return false;
}

void initPickupHandler() {
  totalPicks = 0;
  state = STATE_TOTAL_PICKS;
  currentAlertMsg = "";
  lastPickupChangeTime = millis();
  initialMessageReceived = false;
  displayTotalPickupsFetching();
}

bool hasReceivedInitialMessage() {
  return initialMessageReceived;
}

void showPostFetchPickups() {
  if (state == STATE_TOTAL_PICKS) {
    displayTotalPickups(totalPicks);
  }
}

void handlePickupMessage(const char* payload, unsigned int length) {
  // Parse JSON payload
  String jsonStr = "";
  jsonStr.reserve(length);
  for (unsigned int i = 0; i < length; i++) {
    jsonStr += (char)payload[i];
  }
  
  Serial.print("[PickupHandler] Received payload: ");
  Serial.println(jsonStr);

  // Parse JSON
  JsonDocument doc;
  DeserializationError error = deserializeJson(doc, jsonStr);

  if (error) {
    Serial.print("[PickupHandler] JSON Deserialization failed: ");
    Serial.println(error.f_str());
    return;
  }

  // Check if it is the sync payload containing "busId" and "totalPicks" (and does not contain "type" which indicates an alert)
  if (!doc["busId"].isNull() && !doc["totalPicks"].isNull() && doc["type"].isNull()) {
    int picks = doc["totalPicks"] | 0;
    totalPicks = picks;
    initialMessageReceived = true;
    lastPickupChangeTime = millis();
    Serial.printf("[PickupHandler] Sync response received. Bus: %s, Total Picks: %d\n", (const char*)doc["busId"], totalPicks);
    if (state == STATE_TOTAL_PICKS) {
      displayTotalPickups(totalPicks);
    }
    return;
  }

  const char* type = doc["type"];
  if (type == nullptr) {
    Serial.println("[PickupHandler] JSON type field is missing");
    return;
  }

  // Any message receipt resets the idle time
  lastPickupChangeTime = millis();
  initialMessageReceived = true;

  if (strcmp(type, "NEW_PICKUP_ALERT") == 0) {
    const char* alertMsg = doc["alertMsg"];
    int picks = doc["totalPicks"] | 0;
    
    if (alertMsg != nullptr) {
      currentAlertMsg = String(alertMsg);
      totalPicks = picks;
      if (state != STATE_EMERGENCY_ALERT && state != STATE_EMERGENCY_ACTIVE) {
        state = STATE_ALERT;
        alertStartTime = millis();
        displayPickupAlert(alertMsg);
      }
      Serial.printf("[PickupHandler] New Alert: '%s', Total Picks: %d\n", alertMsg, totalPicks);
    }
  } else if (strcmp(type, "CANCEL_ALERT") == 0) {
    int picks = doc["totalPicks"] | 0;
    totalPicks = picks;
    
    Serial.printf("[PickupHandler] Cancel Alert. Updated Total Picks: %d\n", totalPicks);
    if (state != STATE_EMERGENCY_ALERT && state != STATE_EMERGENCY_ACTIVE) {
      if (state == STATE_DATETIME) {
        // Transition back to total picks immediately upon change
        state = STATE_TOTAL_PICKS;
        displayTotalPickups(totalPicks);
      } else if (state == STATE_TOTAL_PICKS) {
        displayTotalPickups(totalPicks);
      }
    }
  } else {
    Serial.printf("[PickupHandler] Unknown alert type: %s\n", type);
  }
}

void updatePickupHandler() {
  unsigned long now = millis();

  switch (state) {
    case STATE_TOTAL_PICKS:
      if (now - lastPickupChangeTime > 40000) { // 40 seconds of inactivity
        state = STATE_DATETIME;
        dateTimeStartTime = now;
        lastDateTimeUpdate = 0; // trigger immediate tick update
        Serial.println("[PickupHandler] Idle timeout (>40s). Showing date/time.");
      }
      break;

    case STATE_ALERT:
      if (now - alertStartTime >= 10000) { // 10 seconds of alert display
        state = STATE_TOTAL_PICKS;
        lastPickupChangeTime = now; // reset the idle timer when returning to total picks
        Serial.printf("[PickupHandler] Alert display completed. Reverting to Total Picks: %d\n", totalPicks);
        displayTotalPickups(totalPicks);
      }
      break;

    case STATE_DATETIME:
      if (now - dateTimeStartTime >= 15000) { // 15 seconds of date/time display
        state = STATE_TOTAL_PICKS;
        lastPickupChangeTime = now; // reset the idle timer when returning to total picks
        Serial.printf("[PickupHandler] Date/time display completed. Reverting to Total Picks: %d\n", totalPicks);
        displayTotalPickups(totalPicks);
      } else {
        // Tick date and time display every 500 ms
        if (now - lastDateTimeUpdate >= 500) {
          lastDateTimeUpdate = now;
          char dStr[16] = {0};
          char tStr[16] = {0};
          if (getSriLankaTime(dStr, tStr, sizeof(dStr))) {
            displayDateTime(dStr, tStr);
          } else {
            displayDateTime("Syncing...", "Syncing...");
          }
        }
      }
      break;

    case STATE_EMERGENCY_ALERT:
      if (now - emergencyStartTime >= 5000) { // 5 seconds of "Emegrncy Alert Sent"
        state = STATE_EMERGENCY_ACTIVE;
        displayEmergencyActive();
        Serial.println("[PickupHandler] 5 seconds of Emergency Alert Sent display completed. Showing EMERGENCY.");
      }
      break;

    case STATE_EMERGENCY_ACTIVE:
      // Stay in active emergency display until cleared via payload trigger
      break;

    case STATE_EMERGENCY_CLEARED:
      if (now - emergencyClearedTime >= 5000) { // 5 seconds of "Emergency cleared"
        state = STATE_TOTAL_PICKS;
        lastPickupChangeTime = now; // reset the idle timer when returning to total picks
        Serial.printf("[PickupHandler] Emergency cleared display completed. Reverting to Total Picks: %d\n", totalPicks);
        displayTotalPickups(totalPicks);
      }
      break;

    case STATE_PICKUPS_CLEARED:
      if (now - clearAlertStartTime >= 3000) { // 3 seconds of "All pickups cleared"
        state = STATE_TOTAL_PICKS;
        lastPickupChangeTime = now; // reset the idle timer when returning to total picks
        Serial.printf("[PickupHandler] Clear display completed. Reverting to Total Picks: %d\n", totalPicks);
        displayTotalPickups(totalPicks);
      }
      break;
  }
}

void handleEmergencyStatusFromPayload(bool emergency) {
  if (emergency) {
    state = STATE_EMERGENCY_ALERT;
    emergencyStartTime = millis();
    displayEmergencyAlert();
    Serial.println("[PickupHandler] Emergency Alert payload observed. Displaying 'Emegrncy Alert Sent'.");
  } else {
    // Only clear emergency if we are in one of the emergency states
    if (state == STATE_EMERGENCY_ALERT || state == STATE_EMERGENCY_ACTIVE) {
      state = STATE_EMERGENCY_CLEARED;
      emergencyClearedTime = millis();
      displayEmergencyCleared();
      Serial.println("[PickupHandler] Emergency Cleared payload observed. Displaying 'Emergency cleared'.");
    }
  }
}

void handleClearButtonPressed() {
  // Reset pickups to 0 immediately
  totalPicks = 0;
  
  // Only override display if not currently in emergency status
  if (state != STATE_EMERGENCY_ALERT && state != STATE_EMERGENCY_ACTIVE) {
    state = STATE_PICKUPS_CLEARED;
    clearAlertStartTime = millis();
    displayAllPickupsCleared();
    Serial.println("[PickupHandler] Clear button pressed. Displaying 'All pickups cleared' and setting total to 0.");
  } else {
    Serial.println("[PickupHandler] Clear button pressed during emergency. Set total pickups to 0, but keeping emergency display.");
  }
}
