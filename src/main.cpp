#ifndef RUN_TESTS   // ← only compile real code when NOT testing


#include <Arduino.h>
#include "UltrasonicPassengerCounter.h"
#include "WiFiConnect.h"
#include "FirebaseSend.h"
#include "gps_module.h"   // NEW
#include "emergency_button.h"
#include "AwsIot.h"

void setup() {
    Serial.begin(115200);

    setupUltrasonicPassengerCounter();
    connectWiFi();
    setupFirebase();
    setupEmergencyButton();

    setupAWS();

    setupGPS();   // NEW: initialize GPS module

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

    delay(50); // small delay to avoid flooding Firebase
}

#endif  // RUN_TESTS