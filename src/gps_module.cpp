#include <Arduino.h>
#include <TinyGPSPlus.h>
#include "gps_module.h"
#include "FirebaseSend.h"

// GPS object
TinyGPSPlus gps;

// Use UART2 on ESP32
HardwareSerial GPSserial(2);

// timing
unsigned long lastUpdate = 0;
const unsigned long gpsInterval = 1000;   // 1 second

void setupGPS()
{
    // RX = GPIO16, TX = GPIO17
    GPSserial.begin(9600, SERIAL_8N1, 16, 17);

    Serial.println("GPS Module Initialized");
}

void updateGPS()
{
    // Read incoming GPS data
    while (GPSserial.available())
    {
        gps.encode(GPSserial.read());
    }

    // Send update every second
    if (millis() - lastUpdate >= gpsInterval)
    {
        lastUpdate = millis();

        Serial.println("------ GPS STATUS ------");

        if (gps.location.isValid())
        {
            double latitude = gps.location.lat();
            double longitude = gps.location.lng();

            Serial.print("Latitude: ");
            Serial.println(latitude, 6);

            Serial.print("Longitude: ");
            Serial.println(longitude, 6);

            // Send to Firebase
            sendGPSLocation(latitude, longitude);
        }
        else
        {
            Serial.println("Location: Not Fixed");
        }

        Serial.print("Satellites: ");
        Serial.println(gps.satellites.value());

        Serial.print("HDOP (Accuracy): ");
        Serial.println(gps.hdop.hdop());

        Serial.print("Estimated Accuracy (m): ");
        Serial.println(gps.hdop.hdop() * 5);

        Serial.print("Speed (km/h): ");
        Serial.println(gps.speed.kmph());

        Serial.print("Altitude (m): ");
        Serial.println(gps.altitude.meters());

        Serial.println("------------------------\n");
    }
}