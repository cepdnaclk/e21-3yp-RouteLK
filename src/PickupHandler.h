#ifndef PICKUP_HANDLER_H
#define PICKUP_HANDLER_H

#include <Arduino.h>

void initPickupHandler();
bool hasReceivedInitialMessage();
void showPostFetchPickups();
void handlePickupMessage(const char* payload, unsigned int length);
void updatePickupHandler();
void handleEmergencyStatusFromPayload(bool emergency);
void handleClearButtonPressed();

#endif // PICKUP_HANDLER_H
