# 🚗 MOCA Mobility System

## Project Information

- **Student**: 27438 Ntwari Ashimwe Fiacre
- **Course**: Database Development with PL/SQL (INSY 8311)
- **Update on**: 7 DEcember 2025
- **Database**: Oracle PL/SQL

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Key Challenges Addressed](#Key-Challenges-Addressed)
3. [Core Features](#Core-Features)
4. [Database Schema](#Database-Schema)
5. [Innovation & Key Differentiators](#Innovation-&-Key-Differentiators)
6. [LINKS](#LINKS)

---


## Project Overview

Moca is a localized, tech-driven mobility system platform designed to modernize transportation services in emerging markets. It provides an integrated ecosystem for on-demand ride-hailing (car, motorcycle, and delivery services), digital payments, real-time location tracking, and user experience management.

### Key Challenges Addressed
- Fragmented transportation services in developing regions
- Cash-dependent transactions limiting digital adoption
- Lack of reliable digital mobility systems

### Core Features
Moca creates a seamless experience for riders, drivers, and service operators through:
- **Real-time ride requests** - Request rides for cars, motorcycles, or delivery services
- **Live location tracking** - Track drivers in real-time with accurate ETA predictions
- **Multi-channel payments** - NFC, Mobile Money (MoMo), cards, PayPal, and QR codes
- **In-app messaging** - Direct communication between riders and drivers
- **Security tokens** - Daily JWTokens for controlled access across multiple devices

**Vision**: Enhance transportation reliability, reduce operational friction, and promote safer, cashless mobility experiences.

---

## Database Schema

The system relies on a relational database structured around key operational entities.

### Users Table

| Field | Type | Description |
|-------|------|-------------|
| user_id (PK) | INT | Unique user identifier |
| full_name | VARCHAR | Rider/driver name |
| email | VARCHAR | Unique email for login |
| phone | VARCHAR | Mobile identity |
| role | VARCHAR2(rider, driver, admin) | User category |
| password_hash | TEXT | Secure credential storage |
| jwt_token | TEXT | Daily token for access control |
| created_at | TIMESTAMP | Registration date |

### Drivers Table

| Field | Type | Description |
|-------|------|-------------|
| driver_id (PK) | INT | Driver profile |
| user_id (FK) | INT | Link to Users table |
| license_no | VARCHAR | Driver license |
| vehicle_type | VARCHAR2(car, moto, delivery) | Service category |
| vehicle_plate | VARCHAR | Vehicle identification |
| rating | FLOAT | Driver rating score |

### Rides Table

| Field | Type | Description |
|-------|------|-------------|
| ride_id (PK) | INT | Ride transaction ID |
| rider_id (FK) | INT | Who requested the ride |
| driver_id (FK) | INT | Assigned driver |
| pickup_location | NUMBER | Start point |
| dropoff_location | NUMBER | End point |
| fare_amount | BINARY_DOUBLE | Total fare |
| payment_method | VARCHAR2(nfc, momo, paypal, card, qr) | Selected payment mode |
| status | VARCHAR2(requested, active, completed, canceled) | Ride state |
| started_at | TIMESTAMP | Start time |
| completed_at | TIMESTAMP | Completion time |

### Payments Table

| Field | Type | Description |
|-------|------|-------------|
| payment_id (PK) | INT | Transaction identifier |
| ride_id (FK) | INT | Associated ride |
| amount | BINARY_DOUBLE | Amount charged |
| method | VARCHAR2(nfc, momo, paypal, card, qr) | Payment channel |
| transaction_ref | VARCHAR | Gateway transaction ID |
| is_successful | BOOLEAN | Payment outcome |
| timestamp | TIMESTAMP | Payment time |

### Messages Table

| Field | Type | Description |
|-------|------|-------------|
| message_id (PK) | INT | Unique message ID |
| sender_id (FK) | INT | User sending message |
| receiver_id (FK) | INT | User receiving message |
| ride_id (FK) | INT | Conversation context |
| message_body | VARCHAR2 | Content |
| sent_at | TIMESTAMP | Timestamp |

### Real-Time Tracking Table

| Field | Type | Description |
|-------|------|-------------|
| tracking_id (PK) | INT | Location log |
| driver_id (FK) | INT | Tracking driver |
| latitude | BINARY_DOUBLE | Current latitude |
| longitude | BINARY_DOUBLE | Current longitude |
| speed | BINARY_DOUBLE | Driver speed |
| timestamp | TIMESTAMP | Record time |

---

## ERDIAGRAM

![ERD](/screenshots/architecture/Moca_erd.png)



## Innovation & Key Differentiators

Moca stands out by integrating multiple innovations tailored to emerging markets:

### 1. Multi-Channel Digital Payments for Mobility

Unlike traditional ride-hailing systems that depend solely on card payments, Moca supports a diverse range of payment methods:

- **NFC tap-to-pay** - Contactless payment for quick transactions
- **Mobile Money (MoMo)** - Accessible in regions with limited banking infrastructure
- **QR Code payments** - Flexible payment option for low-resource settings
- **Credit/Debit cards** - Traditional secure payment channel
- **PayPal** - International and digital-native option

**Impact**: Solves the digital-payment accessibility gap in developing countries by meeting users where they are financially.

### 2. JWTokens for Daily Access Management

Instead of static tokens, Moca issues daily JWTokens per device, providing:

- **Enhanced security** - Tokens expire and refresh daily, limiting exposure
- **Multi-device synchronization** - Better control across multiple user devices
- **Misuse prevention** - Reduces unauthorized access, especially critical for drivers' accounts
- **Audit trail** - Improved tracking of who accesses the system and when

### 3. Real-Time Location Intelligence

The system implements continuous geolocation tracking for:

- **Accurate ETA predictions** - Improved rider experience through precise arrival estimates
- **Safety monitoring** - Track driver behavior and ensure passenger safety
- **Route optimization** - Navigate efficiently through dense urban areas and irregular road networks

### 4. Integrated Chat & Operations System

Riders and drivers communicate directly in-app to:

- **Confirm pickup** - Reduce missed pickups and communication gaps
- **Adjust directions** - Navigate using local landmarks in areas without formal addressing
- **Improve transparency** - Real-time updates enhance trust and reliability

### 5. Localized Technology for Emerging Markets

Every component is designed with local market realities in mind:

- **Motorcycle support ("moto")** - Dominant transport mode in many developing regions
- **Cashless alternatives** - Compatible with populations lacking traditional bank accounts
- **Optimized routing** - Designed for irregular road networks and geographic challenges
- **Multi-language support** - Accessible across diverse linguistic regions

---

## BPMN Diagram

![ERD](/screenshots/architecture/moca_bpmn.png)

## LINKS

1. [DB Creation Process Doc](/db/documentation/database_creation.md)
2. [Database Schema Overview](/db/scripts/db.schema.sql)
3. [Packages](/db/scripts/moca_packages.sql)
4. [Procedures](/db/scripts/moca_Procedures.sql)
5. [Cursors](/db/scripts/moca_cursors.sql)
6. [Triggers](/db/scripts/moca_triggers.sql)
7. [Docker documentation](/documentation/dockerising_moca.md)
8. [Screenshots](/screenshots/)

---

## Conclusion

Moca delivers an end-to-end mobility ecosystem that blends ride-hailing, secure multi-channel payments, real-time tracking, and communication into a single, locally optimized platform. The inclusion of NFC payments, token-based access controls, and location-driven intelligence represents a significant innovation over traditional systems and makes Moca a scalable, future-ready transportation solution for emerging markets.
