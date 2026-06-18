#include <Arduino.h>
#include "clear_button.h"
#include "AwsIot.h"
#include "PickupHandler.h"

// -------- PIN CONFIG --------
constexpr int CLEAR_BUTTON_PIN = 23;
constexpr unsigned long BUTTON_DEBOUNCE_MS = 50;

// -------- VARIABLES --------
static bool lastButtonReading = HIGH;
static bool stableButtonState = HIGH;
static unsigned long lastDebounceTime = 0;

void setupClearButton() {
    pinMode(CLEAR_BUTTON_PIN, INPUT_PULLUP);
}

void updateClearButton() {
    bool reading = digitalRead(CLEAR_BUTTON_PIN);

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
                Serial.println("\n>> CLEAR BUTTON PRESSED! Sending clear command to AWS...");
                publishClearAWS();
                handleClearButtonPressed();
            }
        }
    }

    lastButtonReading = reading;
}
