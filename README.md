# RouteLK : Smart Bus Tracking & Passenger Assistance App

---

## Team
-  E/21/017, Thimal Adeesha, [e21017@eng.pdn.ac.lk](mailto:e21017@eng.pdn.ac.lk)
-  E/21/126, Dinithi Epitakaduwa, [e21126@eng.pdn.ac.lk](mailto:e21126@eng.pdn.ac.lk)
-  E/21/372, Lakshika Seneviratne, [e21372@eng.pdn.ac.lk](mailto:e21372@eng.pdn.ac.lk)
-  E/21/391, Walter Ravindu, [e21391@eng.pdn.ac.lk](mailto:e21391@eng.pdn.ac.lk)

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

## Introduction

Public transportation systems in developing regions often suffer from poor visibility, unpredictable arrival times, overcrowding, and lack of reliable passenger information. Traditional bus systems operate without real-time tracking, accurate occupancy monitoring, or intelligent data handling mechanisms, resulting in passenger inconvenience and operational inefficiencies.

The Bus Tracking & Passenger Assistance System is an IoT- and cloud-powered intelligent transport solution designed to address these challenges. The system integrates embedded hardware, real-time GPS tracking, passenger counting logic, cloud-based data processing, and a mobile application interface to deliver:

- Real-time bus location tracking
- Intelligent passenger counting
- Dynamic crowd-level estimation
- Arrival time prediction
- Robust offline data handling

By combining embedded systems (ESP32 + Ultrasonic sensors + GPS), wireless communication, and scalable backend services, the solution ensures accurate monitoring even in unstable network conditions.

This system demonstrates how IoT and cloud technologies can modernize public transportation with cost-effective and scalable architecture.

## Solution Architecture

### High Level Architecture Diagram
![System Architecture](docs/assets/images/high_level_architecture.png)


### Edge Layer (Bus Device):
An ESP32 board connected with peripheral components installed inside the bus collects passenger counts using ultrasonic sensors and tracks GPS location. Data is packaged in JSON format and stored locally if internet connectivity fails.

### Communication Layer:
Telemetry is transmitted every 10 seconds via WiFi or optionally 2G connectivity using MQTT or REST. If the network drops, data is cached on the local cache of ESP32 and automatically synchronized once connectivity is restored.

### Cloud Backend Layer:
The backend receives and stores timestamped data, stores it in database, exposes real time web sockets and REST APIs to the mobile app, and classifies crowd level.

### Application Layer:
The passenger mobile app displays live bus tracking, ETA, crowd levels, and notifications using map services such as Google Maps Platform.

### Data flow Diagram
![Data flow](docs/assets/images/data_flow_diagram.png)


## Hardware and Software Designs

### Main Hardware Components

- ESP32 CP2102 Type-C Development Board
- NEO-M8N GPS Module
- Ultrasonic Sensor Pairs (4 Sensors / 2 Doors)
- SIM 800L GSM Module
- 3.7 V Li-Ion 3500 mAh battery
- 16x2 I2C LCD Display
- Emergency Push Button

### Software Stack

### Firmware

- ESP32 (C/C++ – Arduino / ESP-IDF)
- FreeRTOS (built-in)
- JSON Serialization

### Cloud/Backend

- REST API Framework
- MQTT Broker
- HTTP / MQTT Protocol
- Cloud Hosting (AWS)

### Database

- AWS DynamoDB (realtime database)
- AWS RDS (relational postgresql database)

### Frontend/Mobile Application

- Flutter
- React

## Testing

### Hardware Testing

- Ultrasonic Sensor Testing for accurate passenger entry/exit detection.
- GPS Testing in both stationary and moving conditions.
- GSM module Testing for reliable connectivity.

### Software Testing

- Offline Mode Testing for simulated internet disconnection.
- API & Backend Testing.
- Mobile App Testing for smooth real-time map updates, correct crowd-level visualization, and accurate ETA display.

### End-to-End Integration Testing

- Full system tests for the complete data flow:
Sensor detection → ESP32 processing → Cloud transmission → Backend storage → Mobile app update.

## Detailed budget

| Item          | Quantity  | Unit Cost  | Total  |
| ------------- |:---------:|:----------:|-------:|
| ESP32 CP2102 Type-C Development Board    | 1         | 1490 LKR     | 1490 LKR |
| NEO-M8N GPS Module    | 1         | 3990 LKR     | 3990 LKR |
| Ultrasonic sensors    | 4         | 250 LKR     | 1000 LKR |
| Battery(3.7V Li-ion) x 2 with holder | 2  | 1080 LKR  | 1080 LKR |
| SIM 800L 2G GSM Module | 1  | 1190 LKR   | 1190 LKR   |
| 16x2 I2C LCD Character Display | 1  | 1000 LKR   |  1000 LKR  |
| Push Buttons | 2  | 120 LKR  |  120 LKR  |
| TP4056 Type-C 5V 1A Charging Module | 1  | 160 LKR  |  160 LKR  |
| Boost Convertor | 1  | 290 LKR  |  290 LKR  |
| LM2596 Buck Convertor | 1  | 290 LKR  |  290 LKR  |
| Other components (cables etc.) |    |    | 1530 LKR   |
| Enclosure 3D printing | 1  | 4500 LKR  |  4500 LKR  |
| Estimated Total Cost  |    |    | 20000 LKR   |

## Conclusion

The Bus Tracking & Passenger Assistance System demonstrates the design and implementation of a real-time, IoT-based transport monitoring solution integrating ESP32 hardware, Ultrasonic sensor counting, GPS tracking, cloud data processing, and mobile application. The system demonstrated accurate occupancy detection, reliable live tracking, and robust offline data handling with automatic synchronization, ensuring zero data loss during connectivity failures. Future developments may include predictive analytics using historical data, integration with digital ticketing systems, AI-based demand forecasting, multi-bus fleet management dashboards, and enhanced security features. From a commercialization perspective, the solution is designed to be low-cost and scalable, making it suitable for deployment in university transport systems, private bus operators, and smart city initiatives, with potential expansion into a subscription-based fleet management service model.
