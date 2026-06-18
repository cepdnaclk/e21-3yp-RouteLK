#ifndef LCD_DISPLAY_H
#define LCD_DISPLAY_H

#include <Arduino.h>

void setupLcd();
void playStartupAnimation();
void displayTotalPickups(int count);
void displayTotalPickupsFetching();
void displayPickupAlert(const char* alertMsg);
void displayDateTime(const char* dateStr, const char* timeStr);
void displayClear();
void displayEmergencyAlert();
void displayEmergencyActive();
void displayEmergencyCleared();
void displayAllPickupsCleared();

#endif // LCD_DISPLAY_H
