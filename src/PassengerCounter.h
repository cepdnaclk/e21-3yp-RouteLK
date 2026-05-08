#ifndef PASSENGER_COUNTER_H
#define PASSENGER_COUNTER_H

#include <Arduino.h>

void setupPassengerCounter();
void loopPassengerCounter();
int getPassengerCount();
bool isCountUpdated();
void resetUpdateFlag();

#endif