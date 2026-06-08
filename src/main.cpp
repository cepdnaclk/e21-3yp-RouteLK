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


void setup() {
    Serial.begin(115200);

    setupUltrasonicPassengerCounter();
    connectWiFi();
    
    // Configure NTP time synchronization for Sri Lanka (UTC+5:30)
    configTime(19800, 0, "pool.ntp.org", "time.nist.gov");

    setupFirebase();
    setupEmergencyButton();

    setupAWS();

    setupGPS();   // NEW: initialize GPS module

    // Initialize LCD display and play startup animation
    setupLcd();
    playStartupAnimation();
    initPickupHandler();

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

    // Update pickup alerts display state/timer
    updatePickupHandler();

    delay(50); // small delay to avoid flooding Firebase
}

#endif  // RUN_TESTS