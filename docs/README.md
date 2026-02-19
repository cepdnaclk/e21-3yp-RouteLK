---
layout: home
permalink: index.html

# Please update this with your repository name and project title
repository-name: e21-3yp-RouteLK
title: RouteLK
---

[comment]: # "This is the standard layout for the project, but you can clean this and use your own template"

# RouteLK : Smart Bus Tracking & Passenger Assistance App

---

## Team
-  E/21/017, Thimal Adeesha, [e21017@eng.pdn.ac.lk](mailto:name@email.com)
-  E/21/126, Dinithi Epitakaduwa, [e21126@eng.pdn.ac.lk](mailto:name@email.com)
-  E/21/372, Lakshika Seneviratne, [e21372@eng.pdn.ac.lk](mailto:name@email.com)
-  E/21/391, Walter Ravindu, [e21391@eng.pdn.ac.lk](mailto:name@email.com)

<!-- Image (photo/drawing of the final hardware) should be here -->

<!-- This is a sample image, to show how to add images to your page. To learn more options, please refer [this](https://projects.ce.pdn.ac.lk/docs/faq/how-to-add-an-image/) -->

<!-- ![Sample Image](./images/sample.png) -->

#### Table of Contents
1. [Introduction](#introduction)
2. [Solution Architecture](#solution-architecture )
3. [Hardware & Software Designs](#hardware-and-software-designs)
4. [Testing](#testing)
5. [Detailed budget](#detailed-budget)
6. [Conclusion](#conclusion)
7. [Links](#links)

## Introduction

Public transportation systems in developing regions often suffer from poor visibility, unpredictable arrival times, overcrowding, and lack of reliable passenger information. Traditional bus systems operate without real-time tracking, accurate occupancy monitoring, or intelligent data handling mechanisms, resulting in passenger inconvenience and operational inefficiencies.

The Bus Tracking & Passenger Assistance System is an IoT- and cloud-powered intelligent transport solution designed to address these challenges. The system integrates embedded hardware, real-time GPS tracking, passenger counting logic, cloud-based data processing, and a mobile application interface to deliver:

Real-time bus location tracking
Intelligent passenger counting
Dynamic crowd-level estimation
Traffic-aware arrival time prediction
Robust offline data handling

By combining embedded systems (ESP32 + IR sensors + GPS), wireless communication, and scalable backend services, the solution ensures accurate monitoring even in unstable network conditions.

This system demonstrates how IoT and cloud technologies can modernize public transportation with cost-effective and scalable architecture.

## Solution Architecture

Architectural Description

1. Edge Layer (Bus Device)

Installed inside the bus, this layer performs real-time sensing and local processing:

Passenger detection via IR sensors
GPS coordinate and speed acquisition
Passenger count updates using directional logic
Data packaging into JSON format
Internet connectivity management
Local data caching during network failure

The ESP32 acts as the central controller, handling interrupts from sensors and serial communication with the GPS module.

2. Communication Layer

Data transmitted every 10 seconds
Uses WiFi or 2G connectivity through SIM 800L GSM module
Supports MQTT or REST transmission
Automatic offline detection via server ping monitoring

If connectivity drops:
  System switches to offline mode
  Logs telemetry data locally on SD card
  Synchronizes once internet reconnects

3. Cloud Backend Layer

Responsibilities include:
  Receiving IoT telemetry
  Timestamp-based data reordering
  Database storage
  Providing REST APIs to mobile application
  Handling offline synchronization batches
  Detecting crowd level

This ensures data consistency and zero data loss.

4. Application Layer (Passenger App)

The mobile application provides:
  Live map visualization
  Real-time bus marker updates
  Traffic-aware ETA
  Crowd-level indication (Low/Medium/High) using suitable colours
  Optional arrival notifications

Traffic data is integrated via APIs such as:

  Google Maps Platform

## Hardware and Software Designs

1. Hardware Design
   
1.1 Core Controller – ESP32

Dual-core processor
Built-in Wi-Fi & Bluetooth
FreeRTOS support
Multiple UART/SPI interfaces
Interrupt handling for IR sensors

Why selected:
Balanced cost-performance ratio
Sufficient RAM for JSON handling
Real-time interrupt capability
We don't need to run ML models

1.2 Passenger Counting System

Sensor Placement

Front Door:
Sensor 1 (Bottom Step)
Sensor 2 (Top Step)

Back Door:
Sensor 3 (Bottom Step)
Sensor 4 (Top Step)

Direction Logic

Entry:
Sensor1 → Sensor2
Exit:
Sensor2 → Sensor1
Same logic applies for both doors.

1.3 GPS Tracking – NEO-M8N

Provides latitude & longitude
Speed calculation
NMEA protocol via UART

1.4 Power Management

3.7 V 1800 mAh Li-Ion rechargeable battery

1.5 Local Storage (Offline Mode)

SD card module

Stores JSON records:
Timestamp
GPS location
Speed
Passenger count
Event type - Emergency button press

2. Software Design
2.1 Embedded Firmware (ESP32)

Modules:

Sensor Interrupt Handler
Passenger Counting Logic
GPS Data Parser
JSON Packet Builder
Connectivity Monitor
Offline Logger
Sync Manager

Real-Time Execution:

Non-blocking architecture
Interrupt-driven counting
Periodic telemetry transmission

2.2 Backend Software

Core Functional Modules:

IoT Data Receiver (MQTT/REST)
Timestamp Validator
Batch Sync Handler
Database Storage Layer
REST API Server
Analytics Engine

Data Reordering:
Late packets are sorted using timestamps before insertion.

2.3 Mobile Application

Features:

Live bus markers
Color-coded crowd levels (Green – Low, Yellow – Medium, Red – Crowded)
Route polyline rendering
Bus detail card (ETA, Occupancy)

Update Frequency:

Every 5–10 seconds via real-time database/socket.

## Testing

1. Hardware Testing
1.1 IR Sensor Testing

Single passenger entry
Single passenger exit
Multiple passengers closely spaced
Simultaneous front and rear door usage

1.2 GPS Accuracy Testing

Static location test
Moving vehicle test
Urban obstruction scenarios

1.3 Power Stability Testing

Long-duration operation

2. Software Testing

2.1 Offline Mode Testing

Internet manually disconnected - System switched to offline mode after 3 failed pings, Data logged to SD card

On reconnect:

Data uploaded in batches, Server acknowledgment verified, Local logs cleared

2.2 API Testing

Stress tested with simulated multiple buses, Verifing timestamp ordering, testing invalid packet handling





















## Detailed budget

All items and costs

| Item          | Quantity  | Unit Cost  | Total  |
| ------------- |:---------:|:----------:|-------:|
| Sample item   | 5         | 10 LKR     | 50 LKR |

## Conclusion

What was achieved, future developments, commercialization plans

## Links

- [Project Repository](https://github.com/cepdnaclk/{{ page.repository-name }}){:target="_blank"}
- [Project Page](https://cepdnaclk.github.io/{{ page.repository-name}}){:target="_blank"}
- [Department of Computer Engineering](http://www.ce.pdn.ac.lk/)
- [University of Peradeniya](https://eng.pdn.ac.lk/)

[//]: # (Please refer this to learn more about Markdown syntax)
[//]: # (https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet)
