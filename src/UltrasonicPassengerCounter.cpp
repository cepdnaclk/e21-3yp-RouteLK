#include "UltrasonicPassengerCounter.h"
#include <Arduino.h>

// -------- PIN DEFINITIONS (ESP32 SAFE) --------

// sensor 1
#define TRIG_FRONT_OUTER 5
#define ECHO_FRONT_OUTER 18

// sensor 2
#define TRIG_FRONT_INNER 19
#define ECHO_FRONT_INNER 21

#define TRIG_REAR_OUTER 26
#define ECHO_REAR_OUTER 34

#define TRIG_REAR_INNER 27
#define ECHO_REAR_INNER 35

// -------- CALIBRATION SETTINGS --------
#define DETECT_DISTANCE 23
#define SENSOR_TIMEOUT  4000

// -------- DOOR STATE MACHINE STRUCT --------
struct DoorCounter {
  const char* label;        // "FRONT" or "REAR"

  int trigOuter;
  int echoOuter;
  int trigInner;
  int echoInner;

  int  state;
  unsigned long stateStart;
  unsigned long clearStart;
  unsigned long lastDebugPrint;
};

namespace {
  int passengerCount = 0;
  bool updateFlag    = false;

  DoorCounter doors[2] = {
    { "FRONT", TRIG_FRONT_OUTER, ECHO_FRONT_OUTER, TRIG_FRONT_INNER, ECHO_FRONT_INNER, 0, 0, 0, 0 },
    { "REAR",  TRIG_REAR_OUTER,  ECHO_REAR_OUTER,  TRIG_REAR_INNER,  ECHO_REAR_INNER,  0, 0, 0, 0 },
  };
}

// -------- HELPERS --------
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

static void updateDoor(DoorCounter &d)
{
  long outerDist = measureDistance(d.trigOuter, d.echoOuter);
  long innerDist = measureDistance(d.trigInner, d.echoInner);

  bool outerDetect = (outerDist < DETECT_DISTANCE);
  bool innerDetect = (innerDist < DETECT_DISTANCE);

  // --- Debug print every 250 ms ---
  if (millis() - d.lastDebugPrint > 250)
  {
    Serial.print("["); Serial.print(d.label); Serial.print("] ");
    Serial.print("Dist O: ");
    if (outerDist == 999) Serial.print("---"); else Serial.print(outerDist);
    Serial.print(" cm | Dist I: ");
    if (innerDist == 999) Serial.print("---"); else Serial.print(innerDist);
    Serial.print(" cm || Det O: "); Serial.print(outerDetect ? "YES" : " NO");
    Serial.print(" | Det I: "); Serial.print(innerDetect ? "YES" : " NO");
    Serial.print(" || State: "); Serial.println(d.state);
    d.lastDebugPrint = millis();
  }

  // --- Identical state machine logic per door ---
  if (d.state == 0)
  {
    if (outerDetect && !innerDetect)
    {
      Serial.print("\n>> ["); Serial.print(d.label); Serial.println("] ACTION: Someone triggered OUTER (Starting Entry)");
      d.state = 1;
      d.stateStart = millis();
    }
    else if (innerDetect && !outerDetect)
    {
      Serial.print("\n>> ["); Serial.print(d.label); Serial.println("] ACTION: Someone triggered INNER (Starting Exit)");
      d.state = 2;
      d.stateStart = millis();
    }
  }
  else if (d.state == 1)
  {
    if (innerDetect)
    {
      Serial.print(">> ["); Serial.print(d.label); Serial.println("] ACTION: Inner triggered, crossing halfway done...");
      d.state = 3;
      d.stateStart = millis();
    }
    if (millis() - d.stateStart > SENSOR_TIMEOUT)
    {
      Serial.print("\n!! ["); Serial.print(d.label); Serial.println("] TIMEOUT: Entry abandoned. Resetting to 0.");
      d.state = 0;
    }
  }
  else if (d.state == 2)
  {
    if (outerDetect)
    {
      Serial.print(">> ["); Serial.print(d.label); Serial.println("] ACTION: Outer triggered, crossing halfway done...");
      d.state = 4;
      d.stateStart = millis();
    }
    if (millis() - d.stateStart > SENSOR_TIMEOUT)
    {
      Serial.print("\n!! ["); Serial.print(d.label); Serial.println("] TIMEOUT: Exit abandoned. Resetting to 0.");
      d.state = 0;
    }
  }
  else if (d.state == 3)
  {
    if (!innerDetect && outerDetect)
    {
      Serial.print("\n!! ["); Serial.print(d.label); Serial.println("] ABORT: Passenger stepped backwards. Reverting to State 1.");
      d.state = 1;
      d.stateStart = millis();
    }
    else if (!outerDetect && !innerDetect)
    {
      passengerCount++;
      updateFlag = true;
      Serial.println("\n=======================");
      Serial.print("["); Serial.print(d.label); Serial.print("] SUCCESS! Person ENTERED. Count: ");
      Serial.println(passengerCount);
      Serial.println("=======================\n");
      d.state = 5;
      d.clearStart = millis();
    }
    if (millis() - d.stateStart > SENSOR_TIMEOUT) d.state = 0;
  }
  else if (d.state == 4)
  {
    if (!outerDetect && innerDetect)
    {
      Serial.print("\n!! ["); Serial.print(d.label); Serial.println("] ABORT: Passenger stepped backwards. Reverting to State 2.");
      d.state = 2;
      d.stateStart = millis();
    }
    else if (!outerDetect && !innerDetect)
    {
      if (passengerCount > 0) passengerCount--;
      updateFlag = true;
      Serial.println("\n=======================");
      Serial.print("["); Serial.print(d.label); Serial.print("] SUCCESS! Person EXITED. Count: ");
      Serial.println(passengerCount);
      Serial.println("=======================\n");
      d.state = 5;
      d.clearStart = millis();
    }
    if (millis() - d.stateStart > SENSOR_TIMEOUT) d.state = 0;
  }
  else if (d.state == 5)
  {
    if (!outerDetect && !innerDetect)
    {
      if (millis() - d.clearStart > 300)
      {
        Serial.print(">> ["); Serial.print(d.label); Serial.println("] System Cleared. Ready for next person.");
        d.state = 0;
      }
    }
    else
    {
      d.clearStart = millis();
    }
  }
}

// -------- PUBLIC API --------
void setupUltrasonicPassengerCounter()
{
  for (auto &d : doors)
  {
    pinMode(d.trigOuter, OUTPUT);
    pinMode(d.echoOuter, INPUT);
    pinMode(d.trigInner, OUTPUT);
    pinMode(d.echoInner, INPUT);
  }

  Serial.println("\n--- PASSENGER COUNTER DEBUG MODE (FRONT + REAR) ---");
  Serial.print("Detect Distance Threshold: ");
  Serial.print(DETECT_DISTANCE);
  Serial.println(" cm");
}

void updateUltrasonicPassengerCounter()
{
  for (auto &d : doors)
    updateDoor(d);

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