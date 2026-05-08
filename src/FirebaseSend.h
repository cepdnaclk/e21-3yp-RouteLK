#ifndef FIREBASE_SEND_H
#define FIREBASE_SEND_H

void setupFirebase();
void sendPassengerCount(int count);

// NEW FUNCTION: include speed (km/h)
void sendGPSLocation(double latitude, double longitude, double speed);

// Toggle /buses/bus1/Emergency boolean value
bool toggleEmergencyStatus();

#endif