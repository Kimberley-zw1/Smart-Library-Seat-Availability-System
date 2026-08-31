# Smart-Library-Seat-Availability-System

## Description

The Smart Library Seat Availability System is a hardware-integrated mobile application designed to help students find available seats in the library, especially during busy examination periods.

Students often waste time walking around the library looking for an empty seat without knowing which seats are available. Our system solves this problem by using pressure or presence sensors installed on library seats to detect whether they are occupied.

The sensors send information through an Arduino and Raspberry Pi to a backend system, which then provides the seat status to a Flutter mobile application. Students can use the app to view the library seating layout and identify available and occupied seats in real time.

The system will also collect occupancy data that can be analysed using MATLAB to identify library usage patterns and peak occupancy periods.

The project combines **IoT hardware, mobile application development, backend systems, and data analytics** to create a smarter and more efficient library experience.

**Sensor → Arduino → Raspberry Pi → Backend → Flutter App → Student**
