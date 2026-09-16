Project: Smart Library Seat Availability System
Testing Phase: Initial Testing
System Type: IoT Hardware-Integrated Mobile Application
Institution: Africa University

Purpose
The purpose of this test plan is to verify that the Smart Library Seat Availability System:
Correctly detects whether seats are occupied or available.
Reliably transfers sensor information from the Arduino to the Raspberry Pi.
Successfully communicates seat information from the Raspberry Pi to the backend.
Correctly stores and retrieves seat information from the database.
Accurately displays seat availability in the Flutter application.
Provides reasonably real-time seat-status updates.
Handles communication and component failures appropriately.
Records accurate occupancy data for later analysis.
Can support multiple seats and multiple users.
Provides a usable and reliable experience for students.
Testing Objectives
The main testing objectives are:
1.Verify sensor accuracy in detecting occupied and vacant seats.
2.Verify Arduino functionality and sensor data processing.
3.Verify Raspberry Pi communication with the Arduino and backend.
4.Verify backend functionality, including APIs and database operations.
5.Verify Flutter application functionality and usability.
6.Verify integration between all system components.
7.Measure system response time between a physical seat-status change and the application update.
8.Test system reliability during continuous operation.
9.Test failure recovery for network, hardware, and software failures.
10.Verify occupancy data integrity for future MATLAB analysis.
11.Identify defects and limitations before deployment.
Test Environment
The initial test environment should include:
Hardware
Arduino board
Raspberry Pi
Pressure/presence sensors
Test library seats or representative seating setup
Appropriate power supplies
Connecting wires and components
Wi-Fi/network connection
At least one Android smartphone for the Flutter application
Software
Arduino firmware
Raspberry Pi application/script
Backend/API
Database
Flutter mobile application
MATLAB
Development computer/laptop
Initial test size
Testing should initially be performed using a small number of seats, for example:
Phase 1: 5–10 seats
Phase 2: 10–50 seats
Phase 3: Larger simulated deployment
The system should pass basic tests before increasing the number of seats

Testing Approach
Testing will be performed progressively.
Component Testing
↓
Hardware Testing
↓
Application Testing
↓
Integration Testing
↓
End-to-End Testing
↓
Performance & Reliability Testing
↓
User Acceptance Testing
This approach allows defects to be identified at the appropriate system level before they affect the complete system.
Hardware Testing
Sensor Occupancy Detection
The sensors will be tested to determine whether they correctly identify occupied and vacant seats.
Test procedure:
1.Leave a seat empty.
2.Record the sensor reading.
3.Place a person/appropriate test load on the seat.
4.Record the sensor reading.
5.Remove the load.
6.Record the reading again.
7.Repeat the test multiple times.
Expected result
The system should:
Empty seat → VACANT
Occupied seat → OCCUPIED
Released seat → VACANT
Sensor Threshold Testing
If pressure sensors are used, an appropriate threshold must be established.The system should be tested with:
Empty seat
Person sitting normally
Different users
Light objects
Backpack or books
Partial pressure
Temporary pressure
The purpose is to identify false positives and false negatives.
Expected result:
The selected threshold should reliably distinguish between normal seat occupancy and non-occupancy conditions.
 Sensor Stability Testing
A person should remain seated for an extended period while sensor readings are monitored.
Expected result:
The sensor should not repeatedly switch between:
OCCUPIED → VACANT → OCCUPIED
while the seat remains occupied.
Arduino Testing
The Arduino will be tested for:
Sensor reading
Correct input configuration
Occupancy threshold processing
Seat identification
Data formatting
Communication with the Raspberry Pi
Handling of multiple sensors
Expected result:
The Arduino should correctly convert sensor readings into the appropriate seat status.
Raspberry Pi Testing
The Raspberry Pi will be tested for:
Receiving data from Arduino
Processing received data
Identifying individual seats
Sending data to the backend
Handling network interruptions
Reconnecting after temporary failures
Restart/recovery behaviour
Expected result:
The Raspberry Pi should reliably act as the communication gateway between the Arduino and backend.
Power Failure Testing
Power will be temporarily disconnected from the Arduino and Raspberry Pi.
Expected result:
After power is restored, the system should restart correctly and return to a valid state without permanently losing its ability to detect and report seat occupancy.
Backend Testing
The backend will be tested independently before complete integration.
API Testing
Tests will verify:
Valid requests
Invalid requests
Seat-status updates
Seat-status retrieval
Missing seat IDs
Invalid seat statuses
Error responses
Authentication where applicable
Expected result:
The backend should validate the request and correctly update the corresponding seat.
Database Testing
The database will be tested for:
Creating seat records
Updating seat status
Retrieving seat status
Recording timestamps
Storing occupancy history
Handling invalid data
Maintaining data consistency
Expected result:
The database should contain accurate records corresponding to actual system events.
Flutter Application Testing
The Flutter application will be tested from the student's perspective.
Application Launch
Test:
Open the application on a supported smartphone.
Expected result: 
The application should load successfully without crashing.
Seating Layout
The application should display the library seating layout.
The physical seat and application seat must have matching identifiers.
For example:
Physical Seat AU 34
        ↓
Database AU 34
        ↓
Flutter AU 34
Expected result
Each physical seat should correspond to the correct seat displayed in the application.
Seat Availability Display
Test both states:
AVAILABLE
OCCUPIED
Expected result
The application should clearly distinguish available and occupied seats.
The application should not rely only on colour. Text, icons, or other visual indicators should also be considered for accessibility.
 Application Network Failure
Disconnect the mobile device from the network.
Expected result:
The application should display an appropriate error/offline message and should not falsely imply that the displayed information is currently real-time.
Integration Testing
Integration testing is one of the most important parts of this project because the system consists of several connected components.
The following interfaces will be tested:
Sensor                  ↔     Arduino
Arduino                ↔     Raspberry Pi
Raspberry Pi        ↔     Backend
Backend               ↔     Database
Backend               ↔     Flutter
Backend/Data     ↔     MATLAB
Sensor-to-Arduino Integration Test
Scenario:
A student sits on seat AU 7.
Expected flow:
Student sits
     ↓
Sensor detects pressure
     ↓
Arduino reads sensor
     ↓
Arduino determines:
AU 7 = OCCUPIED
Expected result:
The Arduino should identify the correct seat and status.
Arduino-to-Raspberry Pi Integration Test
The Arduino should send the seat status to the Raspberry Pi.
Example:
AU 7, OCCUPIED
Expected result:
The Raspberry Pi should receive the correct:
Seat ID
Occupancy status
Sensor information where applicable
No seat should be assigned the status of another seat.

Raspberry Pi-to-Backend Integration Test
The Raspberry Pi should transmit seat information to the backend.
Expected result:
The backend should receive the data and update the correct database record.
Backend-to-Flutter Integration Test
The Flutter application should retrieve or receive current seat information from the backend.
Expected flow:
Backend:
AU 5  = OCCUPIED
       ↓
Flutter App
       ↓
AU 5 displayed as OCCUPIED
Expected result:
The mobile application should accurately reflect the backend state.
Full End-to-End Testing
The most important system test is to verify the complete data flow.
E2E-01: Student Occupies a Seat
Initial condition
AU 11 = AVAILABLE
Procedure:
1.Open the Flutter application.
2.Confirm that AU 11 is available.
3.Sit on physical seat AU 11.
4.Allow the sensor to detect occupancy.
5.Monitor the Arduino.
6.Monitor the Raspberry Pi.
7.Monitor the backend.
8.Verify the database.
9.Check the Flutter application.
Expected result:
The status should change through the complete chain:
AVAILABLE
   ↓
Sensor detects occupancy
   ↓
Arduino
   ↓
Raspberry Pi
   ↓
Backend
   ↓
Database
   ↓
Flutter App
   ↓
AU 11  = OCCUPIED

Full End-to-End Seat Release Test
E2E-02: Student Leaves a Seat
Initial condition
AU 13 = OCCUPIED
Procedure
1.Student leaves AU13 .
2.Sensor detects that the seat is no longer occupied.
3.Arduino processes the new reading.
4.Raspberry Pi transmits the update.
5.Backend updates the database.
6.Flutter application receives the new status.
Expected result
OCCUPIED → AVAILABLE
The application should eventually display AU 13 as available.

Multiple-Seat Testing
The system should be tested with several seats changing state.
Example:
AU 1 → OCCUPIED
AU 2 → AVAILABLE
AU 3 → OCCUPIED
AU 4 → OCCUPIED
AU 5 → AVAILABLE
Expected result:
The backend and Flutter application should display the correct status for every seat.
Tests should include:
One seat changing
Several seats changing
Several students sitting simultaneously
Several students leaving simultaneously
Rapid changes in seat status

Real-Time Performance Testing
The system should measure the time taken for a physical seat-status change to appear in the Flutter application.
The measurement will be:
Physical status change
        ↓
Sensor detection
        ↓
Arduino processing
        ↓
Raspberry Pi transmission
        ↓
Backend processing
        ↓
Flutter update
Metric
End-to-end latency = Time mobile application reflects the correct state − Time physical state changed
An initial target may be:
The system should update the application within approximately 3 seconds under normal network conditions.
The final acceptable value should be confirmed using actual prototype measurements.

Reliability Testing
The system should be operated continuously for an extended period.
Initial reliability tests may include:
8 hours
24 hours
Longer test period where possible
During testing, monitor:
Sensor failures
Arduino failures
Raspberry Pi crashes
Network disconnections
Backend failures
Database errors
Application crashes
Excessive resource usage
Expected result:
The system should remain operational and should not experience unexplained failures during the defined test period.

Failure and Recovery Testing
The system will be deliberately tested under failure conditions.
Failure	Expected Behaviour
Sensor disconnected	Fault detected/handled
Arduino disconnected	Raspberry Pi detects communication failure
Raspberry Pi loses network	Connection recovers when network returns
Backend unavailable	System handles failed request
Smartphone loses network	Application displays appropriate error
Raspberry Pi restarts	System resumes operation
Arduino restarts	Sensor monitoring resumes
The exact recovery behaviour will depend on the final implementation.

Performance and Load Testing
The system should be tested with increasing numbers of seats and users.
The tests should monitor:
API response time
Database response time
Application response time
Raspberry Pi CPU/memory usage
Backend CPU/memory usage
Data loss
Application crashes
Expected result:
The system should continue to provide correct seat information without unacceptable performance degradation.

Security Testing
Basic security testing will verify that users cannot manipulate seat information without authorization.
Tests will include:
Invalid API requests
Unauthorized requests
Invalid authentication credentials where authentication is implemented
Invalid seat IDs
Invalid status values
Attempts to modify data directly through the API
Backend input validation
Expected result:
Unauthorized or malformed requests should be rejected and should not corrupt the database.

MATLAB/Data Analytics Testing
The occupancy data collected by the system should be verified before being used for analysis.
Test whether the system correctly records:
Seat ID
Occupancy status
Date
Time
Occupancy duration where applicable
The exported data set will then be tested in MATLAB.
Expected result:
MATLAB should be able to import the data and generate meaningful occupancy analysis such as:
Peak occupancy periods
Average occupancy
Seat usage frequency
Occupancy trends
Library usage patterns
The MATLAB results should correspond to the recorded test events.

Usability Testing
A small group of students should test the Flutter application.
Participants will be asked to perform tasks such as:
1.Open the application.
2.Identify an available seat.
3.Locate that seat in the physical library.
4.Interpret occupied/available indicators.
5.Refresh or view updated information.
Feedback should be collected on:
Ease of use
Clarity of seating layout
Understanding of seat status
Application navigation
Perceived usefulness
Problems encountered

Test Metrics
The following metrics will be recorded during testing.
Sensor Accuracy
Sensor Accuracy =
Correct Occupancy Detections / Total Test Detections × 100
For example, if 98 out of 100 occupancy events are correctly detected:
Accuracy = 98%
False Positive Rate
The percentage of cases where the system reports a seat as occupied when it is actually available.
False Negative Rate
The percentage of cases where the system reports a seat as available when it is actually occupied.
End-to-End Latency
The time between a physical seat-status change and the corresponding update in the Flutter application.
System Availability
The percentage of the defined testing period during which the system remains operational.
Data Integrity
The percentage of verified physical occupancy events that are correctly represented in the database.

Initial Acceptance Criteria
The following are proposed initial targets and may be refined after baseline testing.
Requirement	Initial Target
Sensor detection accuracy	≥ 95% under defined test conditions
Seat-status consistency	Correct seat ID and status maintained
Database accuracy	100% of verified test events correctly recorded
Application status	Matches backend status
End-to-end latency	Approximately ≤ 3 seconds under normal conditions
Basic recovery	System recovers from defined temporary failures
API validation	Invalid requests rejected
Application stability	No critical crashes during normal testing
Data export	Occupancy data successfully imported into MATLAB
Usability	Students can identify available seats without assistance
Acceptance targets will be reviewed and adjusted based on actual prototype performance.

Defect Recording
Any failed test will be recorded as a defect.
Each defect should include:
Defect ID
Test Case
Date
Component
Description
Steps to Reproduce
Expected Result
Actual Result
Severity
Status
Fix
Retest Result
Example:
Defect ID : DEF-001
Test Case : E2E-001
Component : Sensor
Description  : Seat remains occupied after student leaves.
Severity : Medium
Status : Open

Test Execution Process
Testing will follow this sequence:
Phase 1 - Component Testing
Test individual components independently.
Phase 2 - Interface Testing
Test communication between connected components.
Phase 3 - System Integration
Test the complete system using several seats.
Phase 4 - Performance and Reliability
Measure latency, system stability, load handling, and recovery.
Phase 5 - User Acceptance Testing
Allow representative students to use the system and provide feedback.

Test Deliverables
The testing process will produce:
Test plan
Test case register
Test execution results
Defect reports
Sensor accuracy results
Performance measurements
Screenshots/videos where appropriate
Occupancy test dataset
MATLAB analysis results
User feedback
Final test report

Risks and Considerations
The following risks will receive particular attention:
False occupancy
A backpack, book, or other object may trigger the sensor.
False vacancy
A student may sit in a position that does not produce enough sensor pressure.
Sensor drift
Sensor readings may change over time due to repeated use.
Network failure
Communication between the Raspberry Pi, backend, and mobile application may be interrupted.
Stale seat information
The application may display outdated information if updates are delayed or communication fails.
Incorrect seat mapping
The physical seat ID, database record, and Flutter seat representation must always refer to the same physical seat.
Power failure
Arduino or Raspberry Pi power interruptions may affect system operation.
Scalability
A system that works with a small number of seats may experience performance problems when the number of seats or users increases.

Overall Success Criteria
The Smart Library Seat Availability System will be considered to have successfully passed the initial testing phase when:
1.Sensors reliably detect seat occupancy.
2.Arduino correctly processes sensor information.
3.Raspberry Pi reliably communicates with the Arduino and backend.
4.Backend correctly processes and stores seat information.
5.Flutter correctly displays seat availability.
6.End-to-end seat occupancy and release scenarios work correctly.
7.Multiple seats can be monitored simultaneously.
8.The system meets the agreed response-time target under normal conditions.
9.Critical hardware, software, and integration defects have been resolved or documented.
10.Occupancy data can be successfully exported and analysed using MATLAB.
11.Representative users can understand and use the application to identify available seats.