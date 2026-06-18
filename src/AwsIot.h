#ifndef AWSIOT_H
#define AWSIOT_H

void setupAWS();
void loopAWS();
bool requestInitialPicksAWS();
bool publishPassengerCountAWS(int count);
bool publishGPSAWS(double latitude, double longitude);
bool publishEmergencyAWS(bool status);
bool publishBusDataAWS(int passengers, double latitude, double longitude, bool emergency, double speed);
bool publishClearAWS();

#endif // AWSIOT_H
