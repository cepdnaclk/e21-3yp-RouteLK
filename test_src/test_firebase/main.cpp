// ============================================================
// TEST: Firebase Send Failure & Data Loss
// PURPOSE: Proves that data is silently lost when Firebase fails
//          (weak signal, offline, or bad auth)
// HOW TO USE:
//   1. Upload to ESP32
//   2. Open Serial Monitor at 115200 baud
//   3. Follow on-screen prompts for each test phase
//   4. Check your Firebase console to verify what actually landed
// ============================================================

#include <Arduino.h>
#include <WiFi.h>
#include <FirebaseESP32.h>

const char* ssid     = "A04e";
const char* password = "zrkw3466";

#define FIREBASE_HOST "bus-tracker-6469a-default-rtdb.asia-southeast1.firebasedatabase.app"
#define FIREBASE_AUTH "RmLRzh5JrlKTfhtbeL2nHDLngdbFyNpvLbdMSnH6"

FirebaseData fbData;

int sentCount     = 0;
int successCount  = 0;
int failCount     = 0;

// ---------- helpers ----------
void printResult(const char* testName, bool passed) {
    Serial.print("[");
    Serial.print(passed ? "PASS" : "FAIL");
    Serial.print("] ");
    Serial.println(testName);
}

void connectWiFi() {
    WiFi.begin(ssid, password);
    Serial.print("Connecting WiFi");
    while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
    Serial.println("\nConnected. IP: " + WiFi.localIP().toString());
}

bool firebaseSendCount(int count) {
    sentCount++;
    if (Firebase.RTDB.setInt(&fbData, "/test/passenger_count", count)) {
        successCount++;
        return true;
    } else {
        failCount++;
        Serial.print("  [SEND FAILED] ");
        Serial.println(fbData.errorReason());
        return false;
    }
}

bool firebaseSendGPS(double lat, double lng) {
    sentCount++;
    if (Firebase.RTDB.setFloat(&fbData, "/test/latitude",  lat) &&
        Firebase.RTDB.setFloat(&fbData, "/test/longitude", lng)) {
        successCount++;
        return true;
    } else {
        failCount++;
        Serial.print("  [SEND FAILED] ");
        Serial.println(fbData.errorReason());
        return false;
    }
}

// ---------- Test 1: Normal online send ----------
bool test_send_while_online() {
    Serial.println("\n--- Test 1: Send while online ---");
    bool ok = firebaseSendCount(42);
    Serial.print("  Sent count=42 -> ");
    Serial.println(ok ? "SUCCESS (check Firebase: /test/passenger_count)" : "FAILED");
    return ok;
}

// ---------- Test 2: Send during WiFi drop (data loss proof) ----------
bool test_send_while_offline() {
    Serial.println("\n--- Test 2: Send while WiFi is DOWN ---");
    Serial.println("  >>> TURN OFF your router/hotspot NOW, then wait 10 seconds");
    delay(10000);

    Serial.println("  Attempting 5 sends while offline...");
    int localFails = 0;
    for (int i = 1; i <= 5; i++) {
        bool ok = firebaseSendCount(i * 10);
        Serial.print("  Send attempt ");
        Serial.print(i);
        Serial.print(": count=");
        Serial.print(i * 10);
        Serial.print(" -> ");
        Serial.println(ok ? "SUCCESS (unexpected!)" : "FAILED (data LOST)");
        if (!ok) localFails++;
        delay(1000);
    }

    Serial.print("  Result: ");
    Serial.print(localFails);
    Serial.println("/5 sends LOST (never reached Firebase)");
    Serial.println("  >>> Check Firebase — /test/passenger_count should still show 42");

    // PASS = all failed (proves data is lost, which is the bug we're exposing)
    return localFails == 5;
}

// ---------- Test 3: Behavior after WiFi restores ----------
bool test_send_after_restore() {
    Serial.println("\n--- Test 3: Send after WiFi restored ---");
    Serial.println("  >>> TURN ON your router/hotspot NOW, then wait 15 seconds");
    delay(15000);

    // Try to reconnect
    WiFi.reconnect();
    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < 15000) {
        delay(500); Serial.print(".");
    }
    Serial.println();

    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("  WiFi did not reconnect. Skipping.");
        return false;
    }

    Serial.println("  WiFi reconnected. Sending count=99...");
    bool ok = firebaseSendCount(99);
    Serial.print("  Send after restore -> ");
    Serial.println(ok ? "SUCCESS" : "FAILED");

    if (ok) {
        Serial.println("  >>> Check Firebase: /test/passenger_count should be 99");
        Serial.println("  >>> Values 10,20,30,40,50 sent offline are GONE — never queued");
    }
    return ok;
}

// ---------- Test 4: GPS data loss during drop ----------
bool test_gps_loss_during_drop() {
    Serial.println("\n--- Test 4: GPS data loss simulation ---");
    Serial.println("  Simulating 10 GPS ticks (5 online, 5 offline)");
    Serial.println("  >>> Turn OFF router after 5 seconds...");
    delay(5000);

    int gpsFails = 0;
    for (int i = 0; i < 10; i++) {
        double fakeLat = 6.9271 + (i * 0.0001);
        double fakeLng = 79.8612 + (i * 0.0001);
        bool ok = firebaseSendGPS(fakeLat, fakeLng);
        Serial.print("  GPS tick ");
        Serial.print(i + 1);
        Serial.print(": lat=");
        Serial.print(fakeLat, 4);
        Serial.print(" -> ");
        Serial.println(ok ? "SENT" : "LOST");
        if (!ok) gpsFails++;
        delay(1000);
    }

    Serial.print("  GPS ticks lost: ");
    Serial.print(gpsFails);
    Serial.println("/10");
    Serial.println("  >>> These are permanent gaps in your bus location trail");
    return (gpsFails > 0); // PASS = we proved data loss occurs
}

// ============================================================
void setup() {
    Serial.begin(115200);
    delay(1000);

    Serial.println("\n============================================");
    Serial.println("  Firebase Send Failure Test Suite");
    Serial.println("============================================");

    connectWiFi();
    Firebase.begin(FIREBASE_HOST, FIREBASE_AUTH);
    Firebase.reconnectWiFi(true);
    delay(1000);

    bool t1 = test_send_while_online();
    bool t2 = test_send_while_offline();
    bool t3 = test_send_after_restore();
    bool t4 = test_gps_loss_during_drop();

    Serial.println("\n============================================");
    Serial.println("  SUMMARY");
    Serial.println("============================================");
    Serial.print("  Total sends attempted : "); Serial.println(sentCount);
    Serial.print("  Successful            : "); Serial.println(successCount);
    Serial.print("  Failed (data lost)    : "); Serial.println(failCount);
    Serial.println();
    printResult("Normal send works online",              t1);
    printResult("Sends fail silently offline (bug confirmed)", t2);
    printResult("Sends resume after WiFi restore",       t3);
    printResult("GPS data gaps proven during drop",      t4);
    Serial.println("\nFix: Add a retry queue to buffer failed sends.");
}

void loop() {}
