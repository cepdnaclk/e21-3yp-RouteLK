#include "FirebaseSend.h"
#include <FirebaseESP32.h>

#define FIREBASE_HOST "bus-tracker-6469a-default-rtdb.asia-southeast1.firebasedatabase.app"
#define FIREBASE_AUTH "RmLRzh5JrlKTfhtbeL2nHDLngdbFyNpvLbdMSnH6"

FirebaseData firebaseData;

void setupFirebase(){
    Firebase.begin(FIREBASE_HOST, FIREBASE_AUTH);
    Firebase.reconnectWiFi(true);
}

void sendPassengerCount(int count){
    if(Firebase.RTDB.setInt(&firebaseData, "/buses/bus1/passengers", count)){
        Serial.println("Passenger count sent!");
    } else {
        Serial.print("Firebase failed: ");
        Serial.println(firebaseData.errorReason());
    }
}

// NEW FUNCTION
void sendGPSLocation(double latitude, double longitude){

    if(Firebase.RTDB.setFloat(&firebaseData, "/buses/bus1/latitude", latitude) &&
       Firebase.RTDB.setFloat(&firebaseData, "/buses/bus1/longitude", longitude)){

        Serial.println("GPS sent to Firebase");

    } else {

        Serial.print("Firebase failed: ");
        Serial.println(firebaseData.errorReason());
    }
}

bool toggleEmergencyStatus(){
    bool currentEmergency = false;

    if(Firebase.RTDB.getBool(&firebaseData, "/buses/bus1/Emergency")){
        currentEmergency = firebaseData.boolData();
    } else {
        // If the field does not exist yet, default from false and set true on first press.
        Serial.print("Emergency read failed, using default false: ");
        Serial.println(firebaseData.errorReason());
    }

    bool newEmergency = !currentEmergency;

    if(Firebase.RTDB.setBool(&firebaseData, "/buses/bus1/Emergency", newEmergency)){
        Serial.print("Emergency toggled to: ");
        Serial.println(newEmergency ? "true" : "false");
        return true;
    }

    Serial.print("Emergency toggle failed: ");
    Serial.println(firebaseData.errorReason());
    return false;
}