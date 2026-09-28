Issue #16 - Occupancy Test Data

## Purpose

To define a structured method for collecting, recording and checking occupancy data from the Smart Library Seat Availability System.

The data will be used to record the occupancy state of the library seats over time and provide information that can later be used for occupancy analysis.

## Scope

This data collection focuses on the occupancy status of physical seats monitored by the seat availability system.

The main occupancy states are:
- AVAILABLE
- OCCUPIED

## Data Fields

The following information will be recorded for each observation:
- Time
- Seat
- Status

## Status Definitions

AVAILABLE - The seat is not occupied and the system should report the seat as available.

OCCUPIED - A person is occupying the seat and the system should report the seat as occupied.


## Data Collection Procedure

1. Select a physical prototype seat.
2. Confirm the seat identifier. 
3. Record the time of the observation.
4. Observe whether the physical seat is empty or occupied.
5. Record the expected occupancy status.
6. Check the status displayed by the system.
7. Record all observations accurately.
8. Use the collected data for occupancy analysis when sufficient data has been collected.

During data collection check for:

- Incorrect occupancy status.
- Delayed status changes.
- Status changing without a person occupying the seat.
- Status remaining OCCUPIED after the seat is empty.
- Status remaining AVAILABLE when the seat is occupied.
- Unstable or rapidly changing sensor readings
- Missing observations
- Incorrect seat identifiers
- Communication interruptions

## Evidence 

Where possible, collect screenshots or photographs showing:

- The physical seat condition
- The sensor or hardware status
- The corresponding seat status in the application 
- Any unexpected or incorrect behaviour

## Summary

This document establishes a consistent method for collecting occupancy test data. The recorded data will allow the team to compare the physical occupancy condition of a seat with the status reported by the system.

Actual occupancy measurements will be added when the physical prototype is available.

