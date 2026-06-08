// ============================================================
// TEST: WiFi Resilience
// PURPOSE: Tests WiFi connection, drop detection, and reconnection
// HOW TO USE:
//   1. Upload to ESP32
//   2. Open Serial Monitor at 115200 baud
//   3. During "DROP WIFI NOW" prompt, turn off your router/hotspot
//   4. During "RESTORE WIFI NOW" prompt, turn it back on
//   5. Observe PASS/FAIL results
// ============================================================

#include <Arduino.h>
#include <WiFi.h>

const char* ssid     = "A04e";       // <-- change to your SSID
const char* password = "zrkw3466";   // <-- change to your password

// ---------- helpers ----------
void printResult(const char* testName, bool passed) {
    Serial.print("[");
    Serial.print(passed ? "PASS" : "FAIL");
    Serial.print("] ");
    Serial.println(testName);
}

void waitForSerial(const char* prompt, unsigned long waitMs = 10000) {
    Serial.println();
    Serial.print(">>> ACTION REQUIRED: ");
    Serial.println(prompt);
    Serial.print(">>> Waiting ");
    Serial.print(waitMs / 1000);
    Serial.println(" seconds...");
    delay(waitMs);
}

// ---------- Test 1: Basic connection ----------
bool test_wifi_connects() {
    Serial.println("\n--- Test 1: Basic WiFi Connection ---");
    WiFi.disconnect(true);
    delay(500);

    WiFi.begin(ssid, password);
    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < 15000) {
        delay(500);
        Serial.print(".");
    }
    Serial.println();

    bool connected = (WiFi.status() == WL_CONNECTED);
    if (connected) {
        Serial.print("  IP: ");
        Serial.println(WiFi.localIP());
        Serial.print("  RSSI: ");
        Serial.print(WiFi.RSSI());
        Serial.println(" dBm");
    }
    return connected;
}

// ---------- Test 2: Detect WiFi drop ----------
bool test_wifi_drop_detected() {
    Serial.println("\n--- Test 2: WiFi Drop Detection ---");
    Serial.println("  WiFi status before drop: " + String(WiFi.status() == WL_CONNECTED ? "CONNECTED" : "DISCONNECTED"));

    waitForSerial("TURN OFF your router/hotspot NOW", 12000);

    bool dropped = (WiFi.status() != WL_CONNECTED);
    Serial.print("  WiFi status after drop: ");
    Serial.println(WiFi.status() == WL_CONNECTED ? "STILL CONNECTED (weak drop?)" : "DISCONNECTED");
    Serial.print("  RSSI: "); Serial.print(WiFi.RSSI()); Serial.println(" dBm");

    return dropped;
}

// ---------- Test 3: Reconnection after drop ----------
bool test_wifi_reconnects() {
    Serial.println("\n--- Test 3: WiFi Reconnection ---");

    waitForSerial("TURN ON your router/hotspot NOW", 12000);

    // Attempt manual reconnect (mirrors what your code SHOULD do)
    WiFi.reconnect();
    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
        delay(500);
        Serial.print(".");
    }
    Serial.println();

    bool reconnected = (WiFi.status() == WL_CONNECTED);
    if (reconnected) {
        Serial.print("  Reconnected! IP: ");
        Serial.println(WiFi.localIP());
        Serial.print("  Time to reconnect: ");
        Serial.print((millis() - start) / 1000);
        Serial.println(" seconds");
    } else {
        Serial.println("  FAILED to reconnect within 20 seconds");
    }
    return reconnected;
}

// ---------- Test 4: Signal strength reading ----------
void test_signal_strength() {
    Serial.println("\n--- Test 4: Signal Strength (RSSI) ---");
    Serial.println("  (Move ESP32 far from router to see RSSI drop)");
    for (int i = 0; i < 5; i++) {
        int rssi = WiFi.RSSI();
        Serial.print("  Reading ");
        Serial.print(i + 1);
        Serial.print(": ");
        Serial.print(rssi);
        Serial.print(" dBm  -> Signal: ");
        if      (rssi > -50)  Serial.println("EXCELLENT");
        else if (rssi > -60)  Serial.println("GOOD");
        else if (rssi > -70)  Serial.println("FAIR");
        else if (rssi > -80)  Serial.println("WEAK");
        else                  Serial.println("VERY WEAK / LIKELY TO FAIL");
        delay(2000);
    }
}

// ============================================================
void setup() {
    Serial.begin(115200);
    delay(1000);

    Serial.println("\n============================================");
    Serial.println("  ESP32 WiFi Resilience Test Suite");
    Serial.println("============================================");

    bool t1 = test_wifi_connects();
    printResult("WiFi connects on boot", t1);

    if (!t1) {
        Serial.println("ABORT: Cannot run further tests without WiFi.");
        return;
    }

    test_signal_strength();

    bool t2 = test_wifi_drop_detected();
    printResult("WiFi drop detected by status check", t2);

    bool t3 = test_wifi_reconnects();
    printResult("WiFi reconnects after restore", t3);

    Serial.println("\n============================================");
    Serial.println("  SUMMARY");
    Serial.println("============================================");
    printResult("WiFi connects on boot",              t1);
    printResult("WiFi drop detected by status check", t2);
    printResult("WiFi reconnects after restore",      t3);

    Serial.println("\nDONE. Your current code has NO reconnection");
    Serial.println("logic — add WiFi.reconnect() in the main loop.");
}

void loop() {}
