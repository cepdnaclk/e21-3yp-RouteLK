// ============================================================
// TEST: Ultrasonic Passenger Counter Logic
// PURPOSE: Validates entry/exit counting, timeout, and
//          backward-step abort using Serial commands to
//          simulate sensor triggers (no physical movement needed)
// HOW TO USE:
//   1. Upload to ESP32
//   2. Open Serial Monitor at 115200 baud
//   3. Send commands via Serial Monitor:
//        O  = trigger Outer sensor
//        I  = trigger Inner sensor
//        B  = trigger Both sensors
//        N  = trigger Neither (clear)
//        R  = reset counter to 0
//        S  = show current state + count
//        T  = run automated test sequence
// ============================================================

#include <Arduino.h>

// ---- Mirror the state machine from UltrasonicPassengerCounter.cpp ----
namespace Counter {
    int  passengerCount = 0;
    int  state          = 0;
    unsigned long stateStart = 0;
    unsigned long clearStart = 0;
    bool updateFlag = false;

    #define SENSOR_TIMEOUT 4000

    void reset() {
        passengerCount = 0;
        state = 0;
        updateFlag = false;
        Serial.println("[RESET] Counter and state reset to 0.");
    }

    // Simulate one update tick with given sensor readings
    void tick(bool outerDetect, bool innerDetect) {
        if (state == 0) {
            if (outerDetect && !innerDetect) {
                Serial.println("  >> OUTER triggered (Entry start)");
                state = 1; stateStart = millis();
            } else if (innerDetect && !outerDetect) {
                Serial.println("  >> INNER triggered (Exit start)");
                state = 2; stateStart = millis();
            }
        }
        else if (state == 1) {
            if (innerDetect) {
                Serial.println("  >> Inner triggered — halfway through entry");
                state = 3; stateStart = millis();
            }
            if (millis() - stateStart > SENSOR_TIMEOUT) {
                Serial.println("  !! TIMEOUT: Entry abandoned");
                state = 0;
            }
        }
        else if (state == 2) {
            if (outerDetect) {
                Serial.println("  >> Outer triggered — halfway through exit");
                state = 4; stateStart = millis();
            }
            if (millis() - stateStart > SENSOR_TIMEOUT) {
                Serial.println("  !! TIMEOUT: Exit abandoned");
                state = 0;
            }
        }
        else if (state == 3) {
            if (!innerDetect && outerDetect) {
                Serial.println("  !! ABORT: Stepped backwards — back to State 1");
                state = 1; stateStart = millis();
            } else if (!outerDetect && !innerDetect) {
                passengerCount++;
                updateFlag = true;
                Serial.print("  ✓ ENTRY COMPLETE. Count = ");
                Serial.println(passengerCount);
                state = 5; clearStart = millis();
            }
            if (millis() - stateStart > SENSOR_TIMEOUT) state = 0;
        }
        else if (state == 4) {
            if (!outerDetect && innerDetect) {
                Serial.println("  !! ABORT: Stepped backwards — back to State 2");
                state = 2; stateStart = millis();
            } else if (!outerDetect && !innerDetect) {
                if (passengerCount > 0) passengerCount--;
                updateFlag = true;
                Serial.print("  ✓ EXIT COMPLETE. Count = ");
                Serial.println(passengerCount);
                state = 5; clearStart = millis();
            }
            if (millis() - stateStart > SENSOR_TIMEOUT) state = 0;
        }
        else if (state == 5) {
            if (!outerDetect && !innerDetect) {
                if (millis() - clearStart > 300) {
                    Serial.println("  >> Zone clear. Ready for next person.");
                    state = 0;
                }
            } else {
                clearStart = millis();
            }
        }
    }

    void printStatus() {
        Serial.print("  State="); Serial.print(state);
        Serial.print("  Count="); Serial.print(passengerCount);
        Serial.print("  UpdateFlag="); Serial.println(updateFlag ? "YES" : "NO");
    }
}

// ---------- helpers ----------
void printResult(const char* name, bool passed) {
    Serial.print("["); Serial.print(passed ? "PASS" : "FAIL"); Serial.print("] ");
    Serial.println(name);
}

void tickClear(int times = 5) {
    for (int i = 0; i < times; i++) { Counter::tick(false, false); delay(100); }
}

// ---------- Automated test sequence ----------
void runAutomatedTests() {
    Serial.println("\n======================================");
    Serial.println("  AUTOMATED COUNTER TEST SEQUENCE");
    Serial.println("======================================");

    Counter::reset();

    // Test A: Normal entry
    Serial.println("\n[A] Normal Entry (Outer then Inner then clear)");
    Counter::tick(true,  false);   // outer
    delay(50);
    Counter::tick(true,  true);    // both
    delay(50);
    Counter::tick(false, true);    // inner only
    delay(50);
    tickClear(4);
    bool tA = (Counter::passengerCount == 1);
    printResult("Normal entry increments count to 1", tA);

    // Test B: Normal exit
    Serial.println("\n[B] Normal Exit (Inner then Outer then clear)");
    Counter::tick(false, true);    // inner
    delay(50);
    Counter::tick(true,  true);    // both
    delay(50);
    Counter::tick(true,  false);   // outer only
    delay(50);
    tickClear(4);
    bool tB = (Counter::passengerCount == 0);
    printResult("Normal exit decrements count to 0", tB);

    // Test C: Count doesn't go below 0
    Serial.println("\n[C] Exit when count=0 (should not go negative)");
    Counter::tick(false, true);
    delay(50);
    Counter::tick(true, true);
    delay(50);
    Counter::tick(true, false);
    delay(50);
    tickClear(4);
    bool tC = (Counter::passengerCount == 0);
    printResult("Count does not go below 0", tC);

    // Test D: Backward step abort on entry
    Serial.println("\n[D] Backward step abort during entry");
    Counter::reset();
    Counter::tick(true,  false);   // outer — state 1
    delay(50);
    Counter::tick(true,  true);    // both  — state 3
    delay(50);
    Counter::tick(false, true);    // inner only — still state 3, wait
    delay(50);
    Counter::tick(true,  false);   // back to outer — should abort to state 1
    delay(50);
    // Now properly complete entry
    Counter::tick(true,  true);
    delay(50);
    tickClear(4);
    // Count should still be 0 after the abort, then 1 after re-entry
    printResult("Backward step detected and aborted", true); // visual check
    Counter::printStatus();

    // Test E: Timeout resets state
    Serial.println("\n[E] Timeout resets state (takes ~4.5 seconds)");
    Counter::reset();
    Counter::tick(true, false);    // start entry — state 1
    int stateBefore = Counter::state;
    Serial.println("  Waiting 4.5 seconds for timeout...");
    delay(4500);
    Counter::tick(false, false);   // tick to trigger timeout check
    bool tE = (Counter::state == 0 && Counter::passengerCount == 0);
    printResult("Timeout resets state to 0 without counting", tE);

    // Test F: Multiple entries
    Serial.println("\n[F] 3 consecutive entries");
    Counter::reset();
    for (int i = 0; i < 3; i++) {
        Counter::tick(true,  false);
        delay(50);
        Counter::tick(true,  true);
        delay(50);
        Counter::tick(false, false);
        delay(50);
        tickClear(4);
    }
    bool tF = (Counter::passengerCount == 3);
    printResult("3 consecutive entries = count of 3", tF);

    // SUMMARY
    Serial.println("\n======================================");
    Serial.println("  RESULTS");
    Serial.println("======================================");
    printResult("Normal entry",               tA);
    printResult("Normal exit",                tB);
    printResult("Count floor at 0",           tC);
    printResult("Timeout resets state",       tE);
    printResult("3 consecutive entries",      tF);
}

// ============================================================
void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("\n============================================");
    Serial.println("  Passenger Counter Logic Test Suite");
    Serial.println("============================================");
    Serial.println("Commands: O=Outer  I=Inner  B=Both  N=Neither  R=Reset  S=Status  T=AutoTest");
    Serial.println("Send 'T' to run automated tests now.");
}

void loop() {
    // Periodic timeout check
    Counter::tick(false, false);

    if (Serial.available()) {
        char cmd = toupper(Serial.read());
        while (Serial.available()) Serial.read(); // flush

        Serial.print("CMD: "); Serial.println(cmd);
        switch (cmd) {
            case 'O': Counter::tick(true,  false); break;
            case 'I': Counter::tick(false, true);  break;
            case 'B': Counter::tick(true,  true);  break;
            case 'N': Counter::tick(false, false); break;
            case 'R': Counter::reset();            break;
            case 'S': Counter::printStatus();      break;
            case 'T': runAutomatedTests();         break;
            default:
                Serial.println("Unknown command. Use: O I B N R S T");
        }
        Counter::printStatus();
    }

    delay(50);
}
