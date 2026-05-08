#ifndef ULTRASONIC_PASSENGER_COUNTER_H
#define ULTRASONIC_PASSENGER_COUNTER_H

void setupUltrasonicPassengerCounter();
void updateUltrasonicPassengerCounter();
int getUltrasonicPassengerCount();
bool isUltrasonicCountUpdated();
void resetUltrasonicUpdateFlag();

#endif
