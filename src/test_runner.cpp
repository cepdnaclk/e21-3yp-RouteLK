#ifdef RUN_TESTS  // ← only compiled when testing

#include <Arduino.h>
#include <WiFi.h>
#include <FirebaseESP32.h>

// ─── credentials (must match your project) ──────────────────
static const char* testSsid     = "A04e";
static const char* testPassword = "zrkw3466";
#define FIREBASE_HOST "bus-tracker-6469a-default-rtdb.asia-southeast1.firebasedatabase.app"
#define FIREBASE_AUTH "RmLRzh5JrlKTfhtbeL2nHDLngdbFyNpvLbdMSnH6"

FirebaseData fbData;

// ─── test result tracker ─────────────────────────────────────
int passed = 0;
int failed = 0;

void printResult(const char* name, bool ok) {
    Serial.print(ok ? "[PASS] " : "[FAIL] ");
    Serial.println(name);
    ok ? passed++ : failed++;
}

// ════════════════════════════════════════════════════════════
//  WIFI TESTS
// ════════════════════════════════════════════════════════════

bool test_wifi_connects() {
    Serial.println("\n--- WiFi: connects on boot ---");
    WiFi.disconnect(true);
    delay(300);
    WiFi.begin(testSsid, testPassword);
    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < 15000) {
        delay(500); Serial.print(".");
    }
    Serial.println();
    bool ok = (WiFi.status() == WL_CONNECTED);
    if (ok) { Serial.print("  IP: "); Serial.println(WiFi.localIP()); }
    else      Serial.println("  Could not connect.");
    return ok;
}

bool test_wifi_drop_detected() {
    Serial.println("\n--- WiFi: drop detected ---");
    Serial.println("  >>> TURN OFF router now. Waiting 12 seconds...");
    delay(12000);
    bool dropped = (WiFi.status() != WL_CONNECTED);
    Serial.print("  Status: ");
    Serial.println(dropped ? "DISCONNECTED (correct)" : "Still connected (weak drop?)");
    return dropped;
}

bool test_wifi_reconnects() {
    Serial.println("\n--- WiFi: reconnects after restore ---");
    Serial.println("  >>> TURN ON router now. Waiting 15 seconds...");
    delay(15000);
    WiFi.reconnect();
    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < 15000) {
        delay(500); Serial.print(".");
    }
    Serial.println();
    bool ok = (WiFi.status() == WL_CONNECTED);
    Serial.println(ok ? "  Reconnected!" : "  Failed to reconnect.");
    return ok;
}

void run_wifi_tests() {
    Serial.println("\n╔══════════════════════════════╗");
    Serial.println("║     WIFI TESTS               ║");
    Serial.println("╚══════════════════════════════╝");
    printResult("WiFi connects on boot",     test_wifi_connects());
    printResult("WiFi drop detected",        test_wifi_drop_detected());
    printResult("WiFi reconnects",           test_wifi_reconnects());
}

// ════════════════════════════════════════════════════════════
//  FIREBASE TESTS
// ════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════
//  FIREBASE TESTS — with cache & resend verification
// ════════════════════════════════════════════════════════════

// ─── Local retry queue ───────────────────────────────────────
struct QueuedPayload {
    String path;
    String value;
    String type;   // "int" or "float"
};

const int MAX_QUEUE = 20;
QueuedPayload retryQueue[MAX_QUEUE];
int queueSize = 0;

void pushToQueue(String path, String value, String type) {
    if (queueSize < MAX_QUEUE) {
        retryQueue[queueSize++] = {path, value, type};
        Serial.print("  [QUEUED] ");
        Serial.print(path);
        Serial.print(" = ");
        Serial.println(value);
    } else {
        Serial.println("  [QUEUE FULL] Data dropped!");
    }
}

bool drainQueue() {
    if (queueSize == 0) {
        Serial.println("  Queue is empty — nothing to resend.");
        return true;
    }
    Serial.print("  Draining queue — ");
    Serial.print(queueSize);
    Serial.println(" item(s) to resend...");

    int resent  = 0;
    int skipped = 0;

    for (int i = 0; i < queueSize; i++) {
        bool ok = false;
        if (retryQueue[i].type == "int") {
            ok = Firebase.RTDB.setInt(&fbData,
                     retryQueue[i].path.c_str(),
                     retryQueue[i].value.toInt());
        } else if (retryQueue[i].type == "float") {
            ok = Firebase.RTDB.setFloat(&fbData,
                     retryQueue[i].path.c_str(),
                     retryQueue[i].value.toFloat());
        }

        Serial.print("  Resend [");
        Serial.print(i + 1);
        Serial.print("] ");
        Serial.print(retryQueue[i].path);
        Serial.print(" = ");
        Serial.print(retryQueue[i].value);
        Serial.print(" -> ");
        if (ok) { Serial.println("SENT ✓"); resent++; }
        else    { Serial.println("FAILED ✗ — " + fbData.errorReason()); skipped++; }
        delay(200);
    }

    Serial.print("  Resent: "); Serial.print(resent);
    Serial.print("  Failed: "); Serial.println(skipped);
    queueSize = 0;
    return (skipped == 0);
}

// ─── Smart send — queues on failure ──────────────────────────
bool smartSendInt(String path, int value) {
    if (WiFi.status() != WL_CONNECTED) {
        pushToQueue(path, String(value), "int");
        return false;
    }
    if (Firebase.RTDB.setInt(&fbData, path.c_str(), value)) {
        Serial.print("  [SENT] "); Serial.print(path);
        Serial.print(" = "); Serial.println(value);
        return true;
    } else {
        Serial.print("  [FAIL] "); Serial.println(fbData.errorReason());
        pushToQueue(path, String(value), "int");
        return false;
    }
}

// ─── Helper: reconnect and wait ──────────────────────────────
bool waitForWiFi(unsigned long timeoutMs = 15000) {
    WiFi.reconnect();
    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < timeoutMs) {
        delay(500); Serial.print(".");
    }
    Serial.println();
    if (WiFi.status() == WL_CONNECTED) {
        delay(2000); // let Firebase SSL settle
        return true;
    }
    return false;
}

// ─── Test A: Normal online send still works ───────────────────
bool test_firebase_send_online() {
    Serial.println("\n--- Firebase A: send while online ---");
    queueSize = 0;
    bool ok = smartSendInt("/test/counter", 42);
    Serial.println(ok ? "  >>> Check Firebase: /test/counter = 42"
                      : "  Send failed unexpectedly.");
    return ok;
}

// ─── Test B: Offline sends go into queue ─────────────────────
bool test_firebase_queues_when_offline() {
    Serial.println("\n--- Firebase B: offline sends go into queue ---");
    Serial.println("  >>> TURN OFF router now. Waiting 10 seconds...");
    delay(10000);

    queueSize = 0;
    smartSendInt("/test/counter", 10);
    smartSendInt("/test/counter", 20);
    smartSendInt("/test/counter", 30);

    Serial.print("  Items in queue: "); Serial.println(queueSize);
    bool ok = (queueSize == 3);
    Serial.println(ok ? "  All 3 buffered correctly."
                      : "  Queue did not capture all sends.");
    return ok;
}

// ─── Test C: Queue resends after restore ─────────────────────
bool test_firebase_resends_after_restore() {
    Serial.println("\n--- Firebase C: queue drains after restore ---");
    Serial.println("  >>> TURN ON router now. Waiting 15 seconds...");
    delay(15000);

    if (!waitForWiFi()) {
        Serial.println("  WiFi did not reconnect. Cannot drain.");
        return false;
    }

    Serial.print("  Queue size before drain: "); Serial.println(queueSize);
    bool ok = drainQueue();
    Serial.print("  Queue size after drain:  "); Serial.println(queueSize);

    if (ok) Serial.println("  >>> Check Firebase: /test/counter should show 30");
    return ok;
}

// ─── Test D: Queue overflow protection ───────────────────────
bool test_firebase_queue_overflow() {
    Serial.println("\n--- Firebase D: queue overflow protection ---");
    Serial.println("  >>> TURN OFF router. Waiting 8 seconds...");
    delay(8000);

    queueSize = 0;
    for (int i = 0; i < 25; i++) {
        smartSendInt("/test/counter", i);
    }

    bool capped = (queueSize == MAX_QUEUE);
    Serial.print("  Attempted: 25 sends. Queue size: "); Serial.println(queueSize);
    Serial.println(capped ? "  Correctly capped at 20. Extra 5 dropped."
                          : "  ERROR: Queue exceeded max size!");

    Serial.println("  >>> TURN ON router. Waiting 15 seconds...");
    delay(15000);
    if (waitForWiFi()) drainQueue();

    return capped;
}

void run_firebase_tests() {
    Serial.println("\n╔══════════════════════════════╗");
    Serial.println("║     FIREBASE CACHE TESTS     ║");
    Serial.println("╚══════════════════════════════╝");

    Firebase.begin(FIREBASE_HOST, FIREBASE_AUTH);
    Firebase.reconnectWiFi(true);
    delay(1000);

    // ensure connected before starting
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("  Connecting WiFi...");
        WiFi.begin(testSsid, testPassword);
        unsigned long s = millis();
        while (WiFi.status() != WL_CONNECTED && millis() - s < 15000) {
            delay(500); Serial.print(".");
        }
        Serial.println();
    }

    queueSize = 0;

    printResult("A: Online send works",            test_firebase_send_online());
    printResult("B: Offline sends queued locally", test_firebase_queues_when_offline());
    printResult("C: Queue resends after restore",  test_firebase_resends_after_restore());
    printResult("D: Queue overflow protected",     test_firebase_queue_overflow());
}
// ════════════════════════════════════════════════════════════
//  PASSENGER COUNTER TESTS (no sensors needed)
// ════════════════════════════════════════════════════════════

namespace Sim {
    int  count      = 0;
    int  state      = 0;
    bool updateFlag = false;
    unsigned long stateStart = 0;
    unsigned long clearStart = 0;
    unsigned long fakeTime   = 0;

    void reset() { count = 0; state = 0; updateFlag = false; fakeTime = 0; }
    void advance(unsigned long ms) { fakeTime += ms; }

    void tick(bool outer, bool inner) {
        if (state == 0) {
            if      (outer && !inner)  { state = 1; stateStart = fakeTime; }
            else if (!outer && inner)  { state = 2; stateStart = fakeTime; }
        }
        else if (state == 1) {
            if (inner)                          { state = 3; stateStart = fakeTime; }
            if (fakeTime - stateStart > 4000)   { state = 0; }
        }
        else if (state == 2) {
            if (outer)                          { state = 4; stateStart = fakeTime; }
            if (fakeTime - stateStart > 4000)   { state = 0; }
        }
        else if (state == 3) {
            if (!inner && outer)                { state = 1; stateStart = fakeTime; }
            else if (!outer && !inner)          { count++; updateFlag = true; state = 5; clearStart = fakeTime; }
            if (fakeTime - stateStart > 4000)   { state = 0; }
        }
        else if (state == 4) {
            if (!outer && inner)                { state = 2; stateStart = fakeTime; }
            else if (!outer && !inner)          { if (count > 0) count--; updateFlag = true; state = 5; clearStart = fakeTime; }
            if (fakeTime - stateStart > 4000)   { state = 0; }
        }
        else if (state == 5) {
            if (!outer && !inner) { if (fakeTime - clearStart > 300) state = 0; }
            else clearStart = fakeTime;
        }
    }

    // simulate a full entry sequence
    void doEntry() {
        tick(true,  false);
        tick(true,  true);
        tick(false, false);
        advance(400);
        tick(false, false);
    }

    // simulate a full exit sequence
    void doExit() {
        tick(false, true);
        tick(true,  true);
        tick(false, false);
        advance(400);
        tick(false, false);
    }
}

// fix: Arduino doesn't have elif
//#define elif else if

bool test_counter_entry() {
    Sim::reset();
    Sim::doEntry();
    return (Sim::count == 1 && Sim::state == 0);
}

bool test_counter_exit() {
    Sim::reset();
    Sim::count = 1;
    Sim::doExit();
    return (Sim::count == 0 && Sim::state == 0);
}

bool test_counter_no_negative() {
    Sim::reset();
    Sim::count = 0;
    Sim::doExit();
    return (Sim::count == 0);
}

bool test_counter_backward_abort() {
    Sim::reset();
    Sim::tick(true,  false);   // outer → state 1
    Sim::tick(true,  true);    // both  → state 3
    Sim::tick(true,  false);   // back  → state 1 (abort)
    return (Sim::state == 1 && Sim::count == 0);
}

bool test_counter_timeout() {
    Sim::reset();
    Sim::tick(true, false);    // start entry → state 1
    Sim::advance(4100);        // past timeout
    Sim::tick(false, false);   // trigger check
    return (Sim::state == 0 && Sim::count == 0);
}

bool test_counter_three_entries() {
    Sim::reset();
    Sim::doEntry();
    Sim::doEntry();
    Sim::doEntry();
    return (Sim::count == 3);
}

bool test_counter_update_flag() {
    Sim::reset();
    Sim::doEntry();
    return (Sim::updateFlag == true);
}

void run_counter_tests() {
    Serial.println("\n╔══════════════════════════════╗");
    Serial.println("║     COUNTER TESTS            ║");
    Serial.println("╚══════════════════════════════╝");
    printResult("Normal entry",              test_counter_entry());
    printResult("Normal exit",               test_counter_exit());
    printResult("Count floor at 0",          test_counter_no_negative());
    printResult("Backward step abort",       test_counter_backward_abort());
    printResult("Timeout resets state",      test_counter_timeout());
    printResult("3 consecutive entries",     test_counter_three_entries());
    printResult("Update flag set on entry",  test_counter_update_flag());
}

// ════════════════════════════════════════════════════════════
//  EMERGENCY BUTTON TESTS
// ════════════════════════════════════════════════════════════

bool test_emergency_toggle_alternates() {
    Serial.println("\n--- Emergency: toggle alternates ---");
    Firebase.RTDB.setBool(&fbData, "/buses/bus1/Emergency", false);
    delay(300);

    bool results[3];
    for (int i = 0; i < 3; i++) {
        bool current = false;
        Firebase.RTDB.getBool(&fbData, "/buses/bus1/Emergency");
        current = fbData.boolData();
        results[i] = Firebase.RTDB.setBool(&fbData, "/buses/bus1/Emergency", !current);
        delay(300);
    }

    Firebase.RTDB.getBool(&fbData, "/buses/bus1/Emergency");
    bool final = fbData.boolData();
    Serial.print("  Final value after 3 toggles: "); Serial.println(final ? "true" : "false");
    Serial.println("  Expected: true");
    return (results[0] && results[1] && results[2] && final == true);
}

bool test_emergency_fails_offline() {
    Serial.println("\n--- Emergency: fails gracefully offline ---");
    Serial.println("  >>> TURN OFF router. Waiting 8 seconds...");
    delay(8000);
    bool ok = Firebase.RTDB.setBool(&fbData, "/buses/bus1/Emergency", true);
    Serial.println(ok ? "  Sent (unexpected)" : "  Failed (expected — press is lost)");
    Serial.println("  >>> TURN ON router. Waiting 10 seconds...");
    delay(10000);
    WiFi.reconnect(); delay(3000);
    return !ok;  // PASS = it failed (proves data loss)
}

void run_emergency_tests() {
    Serial.println("\n╔══════════════════════════════╗");
    Serial.println("║     EMERGENCY BUTTON TESTS   ║");
    Serial.println("╚══════════════════════════════╝");
    printResult("Toggle alternates true/false",     test_emergency_toggle_alternates());
    printResult("Toggle lost when offline",         test_emergency_fails_offline());
}

// ════════════════════════════════════════════════════════════
//  GPS TESTS
// ════════════════════════════════════════════════════════════

bool test_gps_firebase_send() {
    Serial.println("\n--- GPS: fake coords reach Firebase ---");
    bool ok = Firebase.RTDB.setFloat(&fbData, "/test/gps/lat",  6.9271) &&
              Firebase.RTDB.setFloat(&fbData, "/test/gps/lng", 79.8612);
    Serial.println(ok ? "  Sent — check /test/gps in Firebase" : "  FAILED");
    return ok;
}

bool test_gps_data_lost_offline() {
    Serial.println("\n--- GPS: data lost offline ---");
    Serial.println("  >>> TURN OFF router. Waiting 8 seconds...");
    delay(8000);
    int lost = 0;
    for (int i = 0; i < 3; i++) {
        bool ok = Firebase.RTDB.setFloat(&fbData, "/test/gps/lat", 6.9271 + i * 0.001);
        Serial.print("  GPS tick "); Serial.print(i+1);
        Serial.println(ok ? ": sent (unexpected)" : ": LOST");
        if (!ok) lost++;
        delay(1000);
    }
    Serial.println("  >>> TURN ON router. Waiting 12 seconds...");
    delay(12000);
    WiFi.reconnect(); delay(3000);
    return (lost > 0);
}

void run_gps_tests() {
    Serial.println("\n╔══════════════════════════════╗");
    Serial.println("║     GPS TESTS                ║");
    Serial.println("╚══════════════════════════════╝");
    printResult("GPS coords reach Firebase",    test_gps_firebase_send());
    printResult("GPS data lost when offline",   test_gps_data_lost_offline());
}

// ════════════════════════════════════════════════════════════
//  MENU
// ════════════════════════════════════════════════════════════

void printMenu() {
    Serial.println("\n╔══════════════════════════════╗");
    Serial.println("║  TEST MENU — send a number   ║");
    Serial.println("╠══════════════════════════════╣");
    Serial.println("║  1 = WiFi tests              ║");
    Serial.println("║  2 = Firebase tests          ║");
    Serial.println("║  3 = Counter tests           ║");
    Serial.println("║  4 = Emergency button tests  ║");
    Serial.println("║  5 = GPS tests               ║");
    Serial.println("║  6 = ALL tests               ║");
    Serial.println("╚══════════════════════════════╝");
}

void printSummary() {
    Serial.println("\n╔══════════════════════════════╗");
    Serial.println("║         FINAL SUMMARY        ║");
    Serial.println("╠══════════════════════════════╣");
    Serial.print(  "║  PASSED: "); Serial.println(passed);
    Serial.print(  "║  FAILED: "); Serial.println(failed);
    Serial.println("╚══════════════════════════════╝");
    passed = 0; failed = 0;
}

// ════════════════════════════════════════════════════════════
//  SETUP & LOOP
// ════════════════════════════════════════════════════════════

void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("\n==========================================");
    Serial.println("  ESP32 Test Runner");
    Serial.println("  Real project code is DISABLED");
    Serial.println("==========================================");
    printMenu();
}

void loop() {
    if (!Serial.available()) return;

    char cmd = Serial.read();
    while (Serial.available()) Serial.read();  // flush

    switch (cmd) {
        case '1':
            run_wifi_tests();
            printSummary();
            break;
        case '2':
            if (WiFi.status() != WL_CONNECTED) {
                Serial.println("Connecting WiFi first...");
                WiFi.begin(testSsid, testPassword);
                unsigned long s = millis();
                while (WiFi.status() != WL_CONNECTED && millis() - s < 15000) {
                    delay(500); Serial.print(".");
                }
                Serial.println();
            }
            run_firebase_tests();
            printSummary();
            break;
        case '3':
            run_counter_tests();
            printSummary();
            break;
        case '4':
            run_emergency_tests();
            printSummary();
            break;
        case '5':
            run_gps_tests();
            printSummary();
            break;
        case '6':
            run_wifi_tests();
            run_firebase_tests();
            run_counter_tests();
            run_emergency_tests();
            run_gps_tests();
            printSummary();
            break;
        default:
            printMenu();
    }
}

#endif  // RUN_TESTS