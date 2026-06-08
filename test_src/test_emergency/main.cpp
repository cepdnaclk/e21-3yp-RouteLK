// ============================================================
// TEST: Emergency Button — Debounce & Firebase Toggle
// PURPOSE: Tests button debounce, state toggle correctness,
//          and behavior when Firebase is unreachable
// HOW TO USE:
//   1. Wire a push button between GPIO25 and GND
//   2. Upload to ESP32
//   3. Open Serial Monitor at 115200 baud
//   4. Press button physically, or send 'S' to simulate press
//   5. Send 'T' for full automated test sequence
//   COMMANDS:
//        S  = simulate button press (no physical button needed)
//        T  = run automated test sequence
//        R  = reset emergency state on Firebase to false
// ============================================================

#include <Arduino.h>
#include <WiFi.h>
#include <FirebaseESP32.h>

const char* ssid     = "A04e";
const char* password = "zrkw3466";

#define FIREBASE_HOST "bus-tracker-6469a-default-rtdb.asia-southeast1.firebasedatabase.app"
#define FIREBASE_AUTH "RmLRzh5JrlKTfhtbeL2nHDLngdbFyNpvLbdMSnH6"

#define EMERGENCY_BUTTON_PIN 25
#define BUTTON_DEBOUNCE_MS   50

FirebaseData fbData;

// ---- Debounce state ----
bool lastButtonReading  = HIGH;
bool stableButtonState  = HIGH;
unsigned long lastDebounceTime = 0;

// ---- Test tracking ----
int pressCount   = 0;
int toggleCount  = 0;
int failCount    = 0;

// ---------- helpers ----------
void printResult(const char* name, bool passed) {
    Serial.print("["); Serial.print(passed ? "PASS" : "FAIL"); Serial.print("] ");
    Serial.println(name);
}

void connectWiFi() {
    WiFi.begin(ssid, password);
    Serial.print("Connecting WiFi");
    while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
    Serial.println("\nConnected: " + WiFi.localIP().toString());
}

bool toggleEmergencyStatus() {
    bool current = false;
    if (Firebase.RTDB.getBool(&fbData, "/buses/bus1/Emergency")) {
        current = fbData.boolData();
    } else {
        Serial.print("  Read failed: "); Serial.println(fbData.errorReason());
        failCount++;
        return false;
    }

    bool next = !current;
    if (Firebase.RTDB.setBool(&fbData, "/buses/bus1/Emergency", next)) {
        toggleCount++;
        Serial.print("  Emergency toggled: ");
        Serial.print(current ? "true" : "false");
        Serial.print(" -> ");
        Serial.println(next ? "true" : "false");
        return true;
    } else {
        Serial.print("  Write failed: "); Serial.println(fbData.errorReason());
        failCount++;
        return false;
    }
}

// ---------- Test 1: Toggle correctness ----------
bool test_toggle_alternates() {
    Serial.println("\n--- Test 1: Toggle alternates true/false ---");

    // Set known starting state
    Firebase.RTDB.setBool(&fbData, "/buses/bus1/Emergency", false);
    delay(500);

    bool r1 = toggleEmergencyStatus(); // should become true
    delay(300);
    bool r2 = toggleEmergencyStatus(); // should become false
    delay(300);
    bool r3 = toggleEmergencyStatus(); // should become true
    delay(300);

    // Read final value
    bool finalVal = false;
    Firebase.RTDB.getBool(&fbData, "/buses/bus1/Emergency");
    finalVal = fbData.boolData();

    bool ok = (r1 && r2 && r3 && finalVal == true);
    Serial.print("  Final Firebase value: "); Serial.println(finalVal ? "true" : "false");
    Serial.println("  Expected: true (3 toggles from false)");
    return ok;
}

// ---------- Test 2: Debounce blocks rapid presses ----------
bool test_debounce() {
    Serial.println("\n--- Test 2: Debounce (simulated rapid presses) ---");

    int countBefore = toggleCount;

    // Simulate 10 rapid fake LOW signals within debounce window
    Serial.println("  Simulating 10 rapid button signals within 50ms...");
    for (int i = 0; i < 10; i++) {
        // Simulate the debounce logic directly
        bool reading = LOW;
        if (reading != lastButtonReading) {
            lastDebounceTime = millis();
        }
        if ((millis() - lastDebounceTime) > BUTTON_DEBOUNCE_MS) {
            if (reading != stableButtonState) {
                stableButtonState = reading;
                if (stableButtonState == LOW) {
                    toggleEmergencyStatus();
                }
            }
        }
        lastButtonReading = reading;
        delay(5); // only 5ms between — inside debounce window
    }

    int toggled = toggleCount - countBefore;
    Serial.print("  Toggles fired during rapid signals: "); Serial.println(toggled);
    bool ok = (toggled <= 1); // debounce should allow at most 1
    return ok;
}

// ---------- Test 3: Toggle fails when offline ----------
bool test_toggle_offline() {
    Serial.println("\n--- Test 3: Toggle fails gracefully when offline ---");
    Serial.println("  >>> TURN OFF router now. Waiting 10 seconds...");
    delay(10000);

    int failsBefore = failCount;
    Serial.println("  Attempting toggle while offline...");
    bool ok = toggleEmergencyStatus();

    bool newFail = (failCount > failsBefore);
    Serial.print("  Toggle returned: "); Serial.println(ok ? "success (unexpected)" : "failed (expected)");
    Serial.println("  >>> TURN ON router now.");
    delay(10000);
    WiFi.reconnect();
    delay(5000);
    return newFail; // PASS = it failed (proving data loss)
}

// ---------- Test 4: Physical button press ----------
void test_physical_button(int timeoutMs = 15000) {
    Serial.println("\n--- Test 4: Physical Button Press ---");
    Serial.println("  >>> PRESS THE BUTTON on GPIO25 within 15 seconds...");

    bool pressed = false;
    unsigned long start = millis();

    while (millis() - start < timeoutMs) {
        bool reading = digitalRead(EMERGENCY_BUTTON_PIN);

        if (reading != lastButtonReading) lastDebounceTime = millis();

        if ((millis() - lastDebounceTime) > BUTTON_DEBOUNCE_MS) {
            if (reading != stableButtonState) {
                stableButtonState = reading;
                if (stableButtonState == LOW) {
                    Serial.println("  >>> BUTTON PRESS DETECTED!");
                    pressCount++;
                    pressed = true;
                    toggleEmergencyStatus();
                    delay(200);
                }
            }
        }
        lastButtonReading = reading;
        delay(10);
    }

    if (!pressed) Serial.println("  No button press detected within timeout.");
    printResult("Physical button press detected + toggled", pressed);
}

// ============================================================
void setup() {
    Serial.begin(115200);
    delay(1000);
    pinMode(EMERGENCY_BUTTON_PIN, INPUT_PULLUP);

    Serial.println("\n============================================");
    Serial.println("  Emergency Button Test Suite");
    Serial.println("============================================");

    connectWiFi();
    Firebase.begin(FIREBASE_HOST, FIREBASE_AUTH);
    Firebase.reconnectWiFi(true);
    delay(1000);

    Serial.println("Commands: S=SimulatePress  T=AutoTest  R=ResetFirebase");
}

void loop() {
    // Live button monitoring
    bool reading = digitalRead(EMERGENCY_BUTTON_PIN);
    if (reading != lastButtonReading) lastDebounceTime = millis();
    if ((millis() - lastDebounceTime) > BUTTON_DEBOUNCE_MS) {
        if (reading != stableButtonState) {
            stableButtonState = reading;
            if (stableButtonState == LOW) {
                Serial.println(">> BUTTON PRESSED (live)");
                pressCount++;
                toggleEmergencyStatus();
                delay(200);
            }
        }
    }
    lastButtonReading = reading;

    if (Serial.available()) {
        char cmd = toupper(Serial.read());
        while (Serial.available()) Serial.read();

        if (cmd == 'S') {
            Serial.println(">> Simulating button press...");
            pressCount++;
            toggleEmergencyStatus();
        }
        else if (cmd == 'T') {
            bool t1 = test_toggle_alternates();
            bool t2 = test_debounce();
            bool t3 = test_toggle_offline();
            test_physical_button();

            Serial.println("\n============================================");
            Serial.println("  SUMMARY");
            Serial.println("============================================");
            printResult("Toggle alternates correctly",            t1);
            printResult("Debounce blocks rapid signals",          t2);
            printResult("Toggle fails gracefully when offline",   t3);
            Serial.print("  Total presses: ");   Serial.println(pressCount);
            Serial.print("  Total toggles: ");   Serial.println(toggleCount);
            Serial.print("  Total failures: ");  Serial.println(failCount);
        }
        else if (cmd == 'R') {
            Firebase.RTDB.setBool(&fbData, "/buses/bus1/Emergency", false);
            Serial.println(">> Firebase Emergency reset to false.");
        }
    }

    delay(10);
}
