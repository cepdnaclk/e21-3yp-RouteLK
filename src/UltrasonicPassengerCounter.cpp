#include "UltrasonicPassengerCounter.h"
#include <Arduino.h>

// -------- PIN DEFINITIONS (ESP32 SAFE) --------
#define TRIG_OUTER 5
#define ECHO_OUTER 18

#define TRIG_INNER 19
#define ECHO_INNER 21

// -------- CALIBRATION SETTINGS --------
#define DETECT_DISTANCE 23
#define SENSOR_TIMEOUT 4000

namespace {
int passengerCount = 0;
int state = 0;
unsigned long stateStart = 0;
unsigned long clearStart = 0;
unsigned long lastDebugPrint = 0;
bool updateFlag = false;
}

static long measureDistance(int trig, int echo)
{
  digitalWrite(trig, LOW);
  delayMicroseconds(2);

  digitalWrite(trig, HIGH);
  delayMicroseconds(10);
  digitalWrite(trig, LOW);

  long duration = pulseIn(echo, HIGH, 6000);
  if (duration == 0) return 999;

  return duration * 0.034 / 2;
}

void setupUltrasonicPassengerCounter()
{
  pinMode(TRIG_OUTER, OUTPUT);
  pinMode(ECHO_OUTER, INPUT);

  pinMode(TRIG_INNER, OUTPUT);
  pinMode(ECHO_INNER, INPUT);

  Serial.println("\n--- PASSENGER COUNTER DEBUG MODE ---");
  Serial.print("Detect Distance Threshold: ");
  Serial.print(DETECT_DISTANCE);
  Serial.println(" cm");
}

void updateUltrasonicPassengerCounter()
{
  long outerDist = measureDistance(TRIG_OUTER, ECHO_OUTER);
  long innerDist = measureDistance(TRIG_INNER, ECHO_INNER);

  bool outerDetect = (outerDist < DETECT_DISTANCE);
  bool innerDetect = (innerDist < DETECT_DISTANCE);

  if (millis() - lastDebugPrint > 250)
  {
    Serial.print("Dist O: ");
    if (outerDist == 999) Serial.print("---"); else Serial.print(outerDist);

    Serial.print(" cm | Dist I: ");
    if (innerDist == 999) Serial.print("---"); else Serial.print(innerDist);

    Serial.print(" cm || Det O: "); Serial.print(outerDetect ? "YES" : " NO");
    Serial.print(" | Det I: "); Serial.print(innerDetect ? "YES" : " NO");
    Serial.print(" || State: "); Serial.println(state);

    lastDebugPrint = millis();
  }

  if (state == 0)
  {
    if (outerDetect && !innerDetect)
    {
      Serial.println("\n>> ACTION: Someone triggered OUTER (Starting Entry)");
      state = 1;
      stateStart = millis();
    }
    else if (innerDetect && !outerDetect)
    {
      Serial.println("\n>> ACTION: Someone triggered INNER (Starting Exit)");
      state = 2;
      stateStart = millis();
    }
  }
  else if (state == 1)
  {
    if (innerDetect)
    {
      Serial.println(">> ACTION: Inner triggered, crossing halfway done...");
      state = 3;
      stateStart = millis();
    }

    if (millis() - stateStart > SENSOR_TIMEOUT)
    {
      Serial.println("\n!! TIMEOUT: Entry abandoned. Resetting to 0.");
      state = 0;
    }
  }
  else if (state == 2)
  {
    if (outerDetect)
    {
      Serial.println(">> ACTION: Outer triggered, crossing halfway done...");
      state = 4;
      stateStart = millis();
    }

    if (millis() - stateStart > SENSOR_TIMEOUT)
    {
      Serial.println("\n!! TIMEOUT: Exit abandoned. Resetting to 0.");
      state = 0;
    }
  }
  else if (state == 3)
  {
    if (!innerDetect && outerDetect)
    {
      Serial.println("\n!! ABORT: Passenger stepped backwards. Reverting to State 1.");
      state = 1;
      stateStart = millis();
    }
    else if (!outerDetect && !innerDetect)
    {
      passengerCount++;
      updateFlag = true;
      Serial.println("\n=======================");
      Serial.print("SUCCESS! Person ENTERED. Count: ");
      Serial.println(passengerCount);
      Serial.println("=======================\n");

      state = 5;
      clearStart = millis();
    }

    if (millis() - stateStart > SENSOR_TIMEOUT) state = 0;
  }
  else if (state == 4)
  {
    if (!outerDetect && innerDetect)
    {
      Serial.println("\n!! ABORT: Passenger stepped backwards. Reverting to State 2.");
      state = 2;
      stateStart = millis();
    }
    else if (!outerDetect && !innerDetect)
    {
      if (passengerCount > 0) passengerCount--;
      updateFlag = true;
      Serial.println("\n=======================");
      Serial.print("SUCCESS! Person EXITED. Count: ");
      Serial.println(passengerCount);
      Serial.println("=======================\n");

      state = 5;
      clearStart = millis();
    }

    if (millis() - stateStart > SENSOR_TIMEOUT) state = 0;
  }
  else if (state == 5)
  {
    if (!outerDetect && !innerDetect)
    {
      if (millis() - clearStart > 300)
      {
        Serial.println(">> System Cleared. Ready for next person.");
        state = 0;
      }
    }
    else
    {
      clearStart = millis();
    }
  }

  delay(10);
}

int getUltrasonicPassengerCount()
{
  return passengerCount;
}

bool isUltrasonicCountUpdated()
{
  return updateFlag;
}

void resetUltrasonicUpdateFlag()
{
  updateFlag = false;
}