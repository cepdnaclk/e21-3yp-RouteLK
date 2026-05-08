#include "AwsIot.h"
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <Arduino.h>
#include "certs.h"

static WiFiClientSecure secureClient;
static PubSubClient mqttClient(secureClient);
static unsigned long lastReconnectAttempt = 0;

static bool connectMQTT(){
    mqttClient.setServer(AWS_IOT_ENDPOINT, 8883);

    // load certificates into the secure client
    secureClient.setCACert(AWS_CERT_CA);
    secureClient.setCertificate(AWS_CERT_CRT);
    secureClient.setPrivateKey(AWS_CERT_PRIVATE);

    if (mqttClient.connected()) return true;

    Serial.print("Connecting to AWS IoT Core...");
    if (mqttClient.connect(AWS_CLIENT_ID)){
        Serial.println(" connected");
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

bool publishBusDataAWS(int passengers, double latitude, double longitude, bool emergency, double speed){
    char payload[256];
    // Build a JSON payload with all fields
    snprintf(payload, sizeof(payload), "{\"passengers\":%d,\"latitude\":%.6f,\"longitude\":%.6f,\"emergency\":%s,\"speed_kmh\":%.2f}",
             passengers, latitude, longitude, emergency ? "true" : "false", speed);

    // Publish to unified topic
    return publishJSON("bus/01/data", payload);
}
