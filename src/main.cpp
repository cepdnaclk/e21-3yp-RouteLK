#ifndef RUN_TESTS   // ← only compile real code when NOT testing


#include <Arduino.h>
#include "UltrasonicPassengerCounter.h"
#include "WiFiConnect.h"
#include "FirebaseSend.h"
#include "gps_module.h"   // NEW
#include "emergency_button.h"
#include "AwsIot.h"
#include "LcdDisplay.h"
#include "PickupHandler.h"
#include "clear_button.h"



void setup() {
    Serial.begin(115200);

    setupUltrasonicPassengerCounter();
    connectWiFi();
    
    // Configure NTP time synchronization for Sri Lanka (UTC+5:30)
    configTime(19800, 0, "pool.ntp.org", "time.nist.gov");

    setupFirebase();
    setupEmergencyButton();
    setupClearButton();


    setupAWS();

    setupGPS();   // NEW: initialize GPS module

    // Initialize LCD display and play startup animation
    setupLcd();
    playStartupAnimation();
    initPickupHandler();

    // Request initial pending requests from AWS IoT Core on boot
    Serial.println("[Setup] Requesting initial pending requests from AWS...");
    if (requestInitialPicksAWS()) {
        unsigned long startFetch = millis();
        // Wait up to 10000ms for the response
        while (!hasReceivedInitialMessage() && (millis() - startFetch < 10000)) {
            loopAWS();
            delay(10);
        }
    } else {
        Serial.println("[Setup] Failed to send sync request to AWS.");
    }

    if (hasReceivedInitialMessage()) {
        Serial.println("[Setup] Initial pending requests count received from AWS.");
        showPostFetchPickups();
    } else {
        Serial.println("[Setup] Wait timed out. Defaulting to 0.");
        displayTotalPickups(0);
    }

    Serial.println("Passenger Counter + GPS System Started");
}

void loop() {

    // Passenger counting logic
    updateUltrasonicPassengerCounter();

    if(isUltrasonicCountUpdated()){
        sendPassengerCount(getUltrasonicPassengerCount());
        resetUltrasonicUpdateFlag();
    }

    // GPS update
    updateGPS();   // NEW: read GPS and send location to Firebase

    // AWS mqtt loop
    loopAWS();

    // Emergency button toggle
    updateEmergencyButton();

    // Clear button trigger
    updateClearButton();


    // Update pickup alerts display state/timer
    updatePickupHandler();

    delay(50); // small delay to avoid flooding Firebase
}

#endif  // RUN_TESTS