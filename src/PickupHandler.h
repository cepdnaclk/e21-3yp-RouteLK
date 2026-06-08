#ifndef PICKUP_HANDLER_H
#define PICKUP_HANDLER_H

#include <Arduino.h>

void initPickupHandler();
void handlePickupMessage(const char* payload, unsigned int length);
void updatePickupHandler();

#endif // PICKUP_HANDLER_H
