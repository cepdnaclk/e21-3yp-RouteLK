// ============================================================
// TEST: GPS Module — Fix Quality, Send Rate & Data Loss
// PURPOSE: Tests GPS lock acquisition, data validity checks,
//          send interval accuracy, and Firebase data loss
//          when signal drops during GPS streaming
// HOW TO USE:
//   1. Take ESP32 outdoors or near a window with sky view
//   2. Upload to ESP32
//   3. Open Serial Monitor at 115200 baud
//   4. Commands:
//        S  = show current GPS status snapshot
//        T  = run automated test sequence
//        L  = live stream GPS readings for 30 seconds
// ============================================================

#include <Arduino.h>
#include <WiFi.h>
#include <TinyGPSPlus.h>
#include <FirebaseESP32.h>

const char* ssid     = "A04e";
const char* password = "zrkw3466";

#define FIREBASE_HOST "bus-tracker-6469a-default-rtdb.asia-southeast1.firebasedatabase.app"
#define FIREBASE_AUTH "RmLRzh5JrlKTfhtbeL2nHDLngdbFyNpvLbdMSnH6"

TinyGPSPlus gps;
HardwareSerial GPSserial(2);   // RX=16, TX=17
FirebaseData   fbData;

unsigned long lastGPSSend = 0;
const unsigned long GPS_INTERVAL = 1000;

int sendAttempts  = 0;
int sendSuccesses = 0;
int sendFails     = 0;
int validFixCount = 0;
int noFixCount    = 0;

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

void feedGPS() {
    while (GPSserial.available()) gps.encode(GPSserial.read());
}

bool sendGPS(double lat, double lng) {
    sendAttempts++;
    if (Firebase.RTDB.setFloat(&fbData, "/test/gps/latitude",  (float)lat) &&
        Firebase.RTDB.setFloat(&fbData, "/test/gps/longitude", (float)lng)) {
        sendSuccesses++;
        return true;
    } else {
        sendFails++;
        Serial.print("  [GPS SEND FAIL] "); Serial.println(fbData.errorReason());
        return false;
    }
}

void printGPSSnapshot() {
    feedGPS();
    Serial.println("\n--- GPS Snapshot ---");
    Serial.print("  Fix valid   : "); Serial.println(gps.location.isValid() ? "YES" : "NO");
    Serial.print("  Satellites  : "); Serial.println(gps.satellites.value());
    Serial.print("  HDOP        : "); Serial.println(gps.hdop.hdop(), 2);
    Serial.print("  Est. Acc(m) : "); Serial.println(gps.hdop.hdop() * 5, 1);
    if (gps.location.isValid()) {
        Serial.print("  Latitude    : "); Serial.println(gps.location.lat(), 6);
        Serial.print("  Longitude   : "); Serial.println(gps.location.lng(), 6);
        Serial.print("  Altitude(m) : "); Serial.println(gps.altitude.meters(), 1);
        Serial.print("  Speed(km/h) : "); Serial.println(gps.speed.kmph(), 1);
    }
    Serial.print("  Chars parsed: "); Serial.println(gps.charsProcessed());
    Serial.print("  Sentences OK: "); Serial.println(gps.sentencesWithFix());
    Serial.print("  Failed cksum: "); Serial.println(gps.failedChecksum());
}

// ---------- Test 1: GPS hardware is receiving NMEA data ----------
bool test_gps_receiving_data() {
    Serial.println("\n--- Test 1: GPS Hardware Receiving NMEA Data ---");
    Serial.println("  Feeding GPS for 5 seconds...");
    unsigned long start = millis();
    while (millis() - start < 5000) feedGPS();

    unsigned long chars = gps.charsProcessed();
    unsigned long failed = gps.failedChecksum();

    Serial.print("  Characters processed : "); Serial.println(chars);
    Serial.print("  Bad checksums        : "); Serial.println(failed);

    bool ok = (chars > 10);
    if (!ok) Serial.println("  WARNING: No NMEA data received. Check wiring on GPIO16/17.");
    return ok;
}

// ---------- Test 2: GPS fix acquired ----------
bool test_gps_fix(unsigned long timeoutMs = 90000) {
    Serial.println("\n--- Test 2: GPS Fix Acquisition ---");
    Serial.print("  Waiting up to ");
    Serial.print(timeoutMs / 1000);
    Serial.println(" seconds for a fix (go near a window)...");

    unsigned long start = millis();
    while (millis() - start < timeoutMs) {
        feedGPS();
        if (gps.location.isValid() && gps.location.isUpdated()) {
            unsigned long elapsed = (millis() - start) / 1000;
            Serial.print("  FIX ACQUIRED in "); Serial.print(elapsed); Serial.println(" seconds!");
            Serial.print("  Lat: "); Serial.println(gps.location.lat(), 6);
            Serial.print("  Lng: "); Serial.println(gps.location.lng(), 6);
            Serial.print("  Sats: "); Serial.println(gps.satellites.value());
            validFixCount++;
            return true;
        }
        if (millis() - start > 5000 && (millis() - start) % 5000 < 100) {
            Serial.print("  Still waiting... Sats: ");
            Serial.println(gps.satellites.value());
        }
    }
    Serial.println("  NO FIX within timeout. Indoor/obstructed?");
    noFixCount++;
    return false;
}

// ---------- Test 3: Send interval accuracy ----------
bool test_send_interval() {
    Serial.println("\n--- Test 3: GPS Send Interval Accuracy ---");
    Serial.println("  Checking 5 send intervals (should each be ~1000ms)...");

    bool allOk = true;
    unsigned long lastSend = millis();
    int checks = 0;

    while (checks < 5) {
        feedGPS();
        if (millis() - lastSend >= GPS_INTERVAL) {
            unsigned long actual = millis() - lastSend;
            lastSend = millis();
            checks++;

            bool withinTolerance = (actual >= 900 && actual <= 1200);
            Serial.print("  Interval "); Serial.print(checks);
            Serial.print(": "); Serial.print(actual);
            Serial.print("ms -> "); Serial.println(withinTolerance ? "OK" : "DRIFT!");
            if (!withinTolerance) allOk = false;
        }
    }
    return allOk;
}

// ---------- Test 4: GPS data sent to Firebase ----------
bool test_gps_firebase_send() {
    Serial.println("\n--- Test 4: GPS Data Sent to Firebase ---");

    if (!gps.location.isValid()) {
        // Use fake coords for Firebase test if no fix
        Serial.println("  No GPS fix — using fake coords for Firebase test.");
        bool ok = sendGPS(6.9271, 79.8612);
        printResult("GPS Firebase send (fake coords)", ok);
        return ok;
    }

    bool ok = sendGPS(gps.location.lat(), gps.location.lng());
    if (ok) {
        Serial.println("  >>> Check Firebase: /test/gps/latitude and /longitude");
    }
    return ok;
}

// ---------- Test 5: Data loss when WiFi drops ----------
bool test_gps_data_loss() {
    Serial.println("\n--- Test 5: GPS Data Loss During WiFi Drop ---");
    Serial.println("  Sending 3 GPS points online, then 3 offline, then 3 online...");
    Serial.println("  >>> WATCH for DROP/RESTORE prompts below");

    int lostCount = 0;

    // Phase 1: online sends
    Serial.println("  [Phase 1] Online sends...");
    for (int i = 0; i < 3; i++) {
        feedGPS();
        double lat = gps.location.isValid() ? gps.location.lat() : 6.9271 + i * 0.001;
        double lng = gps.location.isValid() ? gps.location.lng() : 79.8612 + i * 0.001;
        bool ok = sendGPS(lat, lng);
        Serial.print("  Online "); Serial.print(i+1); Serial.print(": "); Serial.println(ok ? "SENT" : "LOST");
        if (!ok) lostCount++;
        delay(1000);
    }

    // Phase 2: drop WiFi
    Serial.println("  >>> TURN OFF router NOW. Waiting 8 seconds...");
    delay(8000);

    Serial.println("  [Phase 2] Offline sends...");
    for (int i = 0; i < 3; i++) {
        bool ok = sendGPS(6.9271 + i * 0.001, 79.8612 + i * 0.001);
        Serial.print("  Offline "); Serial.print(i+1); Serial.print(": "); Serial.println(ok ? "SENT (unexpected!)" : "LOST");
        if (!ok) lostCount++;
        delay(1000);
    }

    // Phase 3: restore WiFi
    Serial.println("  >>> TURN ON router NOW. Waiting 15 seconds...");
    delay(15000);
    WiFi.reconnect();
    delay(5000);

    Serial.println("  [Phase 3] Post-restore sends...");
    for (int i = 0; i < 3; i++) {
        bool ok = sendGPS(6.9280 + i * 0.001, 79.8620 + i * 0.001);
        Serial.print("  Restored "); Serial.print(i+1); Serial.print(": "); Serial.println(ok ? "SENT" : "LOST");
        if (!ok) lostCount++;
        delay(1000);
    }

    Serial.print("  Total GPS points lost: "); Serial.print(lostCount); Serial.println("/9");
    Serial.println("  Offline points are permanently LOST — no retry in current code.");
    return (lostCount >= 3); // PASS = at least the 3 offline ones were lost
}

// ---------- Live stream ----------
void liveStream(unsigned long durationMs = 30000) {
    Serial.println("\n--- Live GPS Stream (30 seconds) ---");
    unsigned long start = millis();
    while (millis() - start < durationMs) {
        feedGPS();
        if (millis() - lastGPSSend >= GPS_INTERVAL) {
            lastGPSSend = millis();
            printGPSSnapshot();
        }
    }
}

// ============================================================
void setup() {
    Serial.begin(115200);
    delay(1000);
    GPSserial.begin(9600, SERIAL_8N1, 16, 17);

    Serial.println("\n============================================");
    Serial.println("  GPS Module Test Suite");
    Serial.println("============================================");

    connectWiFi();
    Firebase.begin(FIREBASE_HOST, FIREBASE_AUTH);
    Firebase.reconnectWiFi(true);
    delay(1000);

    Serial.println("Commands: S=Snapshot  T=AutoTest  L=LiveStream");
}

void loop() {
    feedGPS();

    if (Serial.available()) {
        char cmd = toupper(Serial.read());
        while (Serial.available()) Serial.read();

        if      (cmd == 'S') { printGPSSnapshot(); }
        else if (cmd == 'L') { liveStream(); }
        else if (cmd == 'T') {
            bool t1 = test_gps_receiving_data();
            bool t2 = test_gps_fix();
            bool t3 = test_send_interval();
            bool t4 = test_gps_firebase_send();
            bool t5 = test_gps_data_loss();

            Serial.println("\n============================================");
            Serial.println("  SUMMARY");
            Serial.println("============================================");
            printResult("GPS hardware receiving NMEA data",     t1);
            printResult("GPS fix acquired",                     t2);
            printResult("Send interval ~1000ms",                t3);
            printResult("GPS data reaches Firebase",            t4);
            printResult("Data loss confirmed when offline",     t5);
            Serial.print("  Sends attempted  : "); Serial.println(sendAttempts);
            Serial.print("  Sends successful : "); Serial.println(sendSuccesses);
            Serial.print("  Sends failed     : "); Serial.println(sendFails);
        }
    }
}
