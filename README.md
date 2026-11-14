# hostel_app

A new Flutter project.

## Admin student and fee management

Admins can create and edit student profiles, including address and parent or
guardian contact and occupation details, and swap room assignments for checked-in
students. New student accounts receive an initial pending hostel fee of ₹5000.
Opening the Fees page or choosing its monthly-generation action creates one
₹5000 hostel fee per student for the current month, without duplicating a fee
already recorded for that month.

Fee reminders use the saved parent phone number to open WhatsApp, with SMS as a
fallback. The admin must review and send the message; reminders are not sent by
an automatic scheduler. Admin changes are available in the Activity Log.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
