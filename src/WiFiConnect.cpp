#include "WiFiConnect.h"
#include <WiFi.h>

const char* ssid = "A04e";
const char* password = "zrkw3466";

void connectWiFi(){
    Serial.print("Connecting to Wi-Fi");
    WiFi.begin(ssid, password);
    while(WiFi.status() != WL_CONNECTED){
        delay(500);
        Serial.print(".");
    }
    Serial.println();
    Serial.print("Connected! IP: "); Serial.println(WiFi.localIP());
}