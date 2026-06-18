#include "AwsIot.h"
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <Arduino.h>
#include <ArduinoJson.h>
#include "certs.h"
#include "PickupHandler.h"

static void mqttCallback(char* topic, byte* payload, unsigned int length) {
    Serial.printf("[AWS IoT] Message arrived on topic: %s\n", topic);
    if (strcmp(topic, "buses/B001/pickups") == 0) {
        handlePickupMessage((const char*)payload, length);
    }
}

static WiFiClientSecure secureClient;
static PubSubClient mqttClient(secureClient);
static unsigned long lastReconnectAttempt = 0;

static bool connectMQTT(){
    mqttClient.setServer(AWS_IOT_ENDPOINT, 8883);
    mqttClient.setCallback(mqttCallback);

    // load certificates into the secure client
    secureClient.setCACert(AWS_CERT_CA);
    secureClient.setCertificate(AWS_CERT_CRT);
    secureClient.setPrivateKey(AWS_CERT_PRIVATE);

    if (mqttClient.connected()) return true;

    Serial.print("Connecting to AWS IoT Core...");
    if (mqttClient.connect(AWS_CLIENT_ID)){
        Serial.println(" connected");
        mqttClient.subscribe("buses/B001/pickups");
        Serial.println("Subscribed to topic: buses/B001/pickups");
        return true;
    }

    Serial.print(" failed, rc=");
    Serial.println(mqttClient.state());
    return false;
}

void setupAWS(){
    mqttClient.setServer(AWS_IOT_ENDPOINT, 8883);
    // Certificates will be set during connect
    connectMQTT();
}

void loopAWS(){
    if (!mqttClient.connected()){
        unsigned long now = millis();
        if (now - lastReconnectAttempt > 5000){
            lastReconnectAttempt = now;
            connectMQTT();
        }
    } else {
        mqttClient.loop();
    }
}

static bool publishJSON(const char* topic, const char* payload){
    if (!mqttClient.connected()){
        if (!connectMQTT()) return false;
    }
    bool ok = mqttClient.publish(topic, payload);
    if(!ok){
        Serial.print("MQTT publish failed: ");
        Serial.println(topic);
    }
    return ok;
}
/*
bool publishPassengerCountAWS(int count){
    char payload[64];
    snprintf(payload, sizeof(payload), "{\"passengers\":%d}", count);
    return publishJSON("buses/bus1/passengers", payload);
}

bool publishGPSAWS(double latitude, double longitude){
    char payload[96];
    snprintf(payload, sizeof(payload), "{\"latitude\":%.6f,\"longitude\":%.6f}", latitude, longitude);
    return publishJSON("buses/bus1/gps", payload);
}

bool publishEmergencyAWS(bool status){
    char payload[32];
    snprintf(payload, sizeof(payload), "{\"emergency\":%s}", status ? "true" : "false");
    return publishJSON("buses/bus1/emergency", payload);
}
*/
bool publishBusDataAWS(int passengers, double latitude, double longitude, bool emergency, double speed){
    static int prevPassengers = -1;
    static double prevLatitude = 0.0;
    static double prevLongitude = 0.0;
    static bool prevEmergency = false;
    static double prevSpeed = -1.0;
    static bool firstPublish = true;

    // Round values to match the formatting precision and suppress float noise
    double roundedLat = round(latitude * 1000000.0) / 1000000.0;
    double roundedLng = round(longitude * 1000000.0) / 1000000.0;
    double roundedSpeed = round(speed * 100.0) / 100.0;

    JsonDocument doc;
    bool changed = false;

    if (firstPublish || passengers != prevPassengers) {
        doc["passengers"] = passengers;
        prevPassengers = passengers;
        changed = true;
    }
    if (firstPublish || roundedLat != prevLatitude) {
        doc["latitude"] = roundedLat;
        prevLatitude = roundedLat;
        changed = true;
    }
    if (firstPublish || roundedLng != prevLongitude) {
        doc["longitude"] = roundedLng;
        prevLongitude = roundedLng;
        changed = true;
    }
    if (firstPublish || emergency != prevEmergency) {
        doc["emergency"] = emergency;
        prevEmergency = emergency;
        changed = true;
    }
    if (firstPublish || roundedSpeed != prevSpeed) {
        doc["speed"] = roundedSpeed;
        prevSpeed = roundedSpeed;
        changed = true;
    }

    // If nothing has changed, bypass the publish
    if (!changed) {
        return true; 
    }

    firstPublish = false;

    char payload[256];
    serializeJson(doc, payload);

    // Publish to unified topic
    bool success = publishJSON("bus/B001/data", payload);
    if (success) {
        JsonDocument tempDoc;
        DeserializationError err = deserializeJson(tempDoc, payload);
        if (!err && tempDoc["emergency"].is<bool>()) {
            bool val = tempDoc["emergency"];
            handleEmergencyStatusFromPayload(val);
        }
    }
    return success;
}

bool requestInitialPicksAWS(){
    return publishJSON("buses/B001/request", "{\"request\":\"sync\"}");
}

bool publishClearAWS() {
    return publishJSON("buses/B001/clear", "{\"clear\":true}");
}

