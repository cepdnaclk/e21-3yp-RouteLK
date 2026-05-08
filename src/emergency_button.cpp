#include <Arduino.h>
#include "emergency_button.h"
#include "FirebaseSend.h"

// -------- PIN CONFIG --------
constexpr int EMERGENCY_BUTTON_PIN = 25;
const unsigned long BUTTON_DEBOUNCE_MS = 50;

// -------- VARIABLES --------
bool lastButtonReading = HIGH;
bool stableButtonState = HIGH;
unsigned long lastDebounceTime = 0;

void setupEmergencyButton() {
    pinMode(EMERGENCY_BUTTON_PIN, INPUT_PULLUP);
}

void updateEmergencyButton() {
    bool reading = digitalRead(EMERGENCY_BUTTON_PIN);

    // Detect change (possible bounce)
    if (reading != lastButtonReading) {
        lastDebounceTime = millis();
    }

    // Check if stable after debounce time
    if ((millis() - lastDebounceTime) > BUTTON_DEBOUNCE_MS) {
        if (reading != stableButtonState) {
            stableButtonState = reading;

            // Active LOW button press.
            if (stableButtonState == LOW) {
                Serial.println("\n>> EMERGENCY BUTTON PRESSED! Toggling status...");
                toggleEmergencyStatus();
                delay(200); // Allow Firebase message to print
            }
        }
    }

    lastButtonReading = reading;
}