# Issue # 15 - End-to-End Integration Test

## Purpose 

To verify that the Smart Library Seat Availability System correctly transfers seat occupancy information from the physical seat sensor through the Arduino,Rasberry Pi, backend/database and Flutter application.

## System Flow

Physical Seat
> Pressure Sensor
> Arduino
> Raspberry Pi
> Backend/Database
> Flutter Application

## Test Cases

### E2E01 - Empty Seat

Action: Leave the physical seat empty.

Expected Result: The corresponding seat in the Flutter application should display AVAILABLE.


### E2E02 - Student sits on seat

Action: A student sits on the physical prototype seat.

Expected Result: The pressure sensor detects the student, the Arduino identifies the seat as OCCUPIED, the status is transmitted through the Raspberry Pi and database, and the corresponding seat in the Flutter application changes to OCCUPIED.

### E2E03 - Student leaves seat

Action: A student leaves the physical prototype seat.

Expected Result: The system should detect that the seat is no longer occupied, and the corresponding seat in the Flutter application should change back to AVAILABLE.

### E2E04 - Repeat Occupancy Test

Action: A student sits on the physical seat again.

Expected Result: The corresponding seat in the Flutter application should change to OCCUPIED again.

### E2E05 - Repeat Departure Test

Action: A student leaves the physical seat again.

Expected Result: The corresponding seat in the Flutter apllication should change back to AVAILABLE.

## Evidence

The flutter seat map has been developed and is available for viewing. Physical prototype evidence will be collected when the hardware prototype is available for end-to-end testing.

## Defects/Issues

No defects have been recorded from the available application interface. The physical sensor-to-application integration still requires verification using the completed hardware prototype.

## Overall Result

The expected end-to-end behaviour is documented. Physical end-to-end verification will be performed when the prototype is available.
