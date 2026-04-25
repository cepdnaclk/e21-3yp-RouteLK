#ifndef FIREBASE_SEND_H
#define FIREBASE_SEND_H

void setupFirebase();
void sendPassengerCount(int count);

// NEW FUNCTION
void sendGPSLocation(double latitude, double longitude);

// Toggle /buses/bus1/Emergency boolean value
bool toggleEmergencyStatus();

#endif