# 🏥 Appointment Booking & Queue Management System for Government Hospital OPD

A digital appointment booking and queue management system designed to improve the efficiency of the Outpatient Department (OPD) process in government hospitals.

The system helps patients book appointments, obtain queue numbers, track their queue status, and receive notifications while providing hospital staff and administrators with tools to manage doctors, appointments, queues, and hospital operations efficiently.

---

## 📌 Project Overview

In the traditional government hospital OPD process, patients often have to arrive early, register manually, obtain a queue number, and wait for a long period before meeting a doctor.

This system aims to digitize and simplify the OPD process by introducing:

- Online patient registration
- Appointment booking
- Digital queue management
- Barcode/QR-based queue identification
- Doctor and clinic management
- Real-time queue status
- Notifications and appointment reminders
- Administrative management
- Hospital OPD monitoring

The system is designed to be accessible to **Sinhala, Tamil, and English-speaking users**.

---

## 🎯 Objectives

- Reduce long waiting times for patients.
- Reduce overcrowding in government hospital OPDs.
- Provide an efficient appointment booking process.
- Digitize the traditional OPD queue system.
- Allow patients to monitor their queue status.
- Improve hospital staff and doctor workflow.
- Provide administrators with centralized system management.
- Improve the overall patient experience.

---

## 👥 User Roles

The system consists of four main user roles:

### 👤 1. Patient

Patients can:

- Register and create an account.
- Manage their profile.
- Search for available clinics/doctors.
- Book appointments.
- View appointment details.
- Receive a digital queue number.
- Scan/use barcode or QR code.
- Track queue status.
- Receive notifications.
- View appointment history.
- Cancel appointments when applicable.

---

### 👨‍⚕️ 2. Doctor

Doctors can:

- Login to the system.
- View their daily appointments.
- View patient details.
- Manage consultation queues.
- Call the next patient.
- Update consultation status.
- View previous appointments.
- Manage availability according to the system rules.

---

### 👨‍💼 3. Admin

Hospital administrators can:

- Manage patients.
- Manage doctors.
- Manage clinics.
- Manage OPD sessions.
- Manage appointments.
- Manage queues.
- Monitor daily OPD activities.
- Manage hospital-related information.
- Generate reports.
- Monitor system activities.

---

### 👑 4. Super Admin

The Super Admin has system-level privileges.

Super Admin can:

- Manage hospital administrators.
- Manage system users and roles.
- Manage hospitals/branches.
- Configure system-wide settings.
- Monitor overall system activity.
- Manage permissions.
- View system-wide reports.
- Maintain overall system security.

---

## 🔄 OPD Process

### Traditional Process

```text
Patient Arrives
      ↓
Registration
      ↓
Obtain Queue Number
      ↓
Wait in Queue
      ↓
Doctor Consultation
      ↓
End of OPD Visit
```

---

## 🔒 Git & Branching Strategy Rules

To maintain code quality and stability:

- **Direct Push Restricted:** Direct push to `main` and `stagingv2` is blocked for general team members.
- **Pull Request Required:** All changes targeting `main` or `stagingv2` must be submitted via Pull Request (PR).
- **Code Owner Approval:** Every PR targeting `main` or `stagingv2` requires mandatory review and confirmation/approval from **`chaninduisuranga`** before merging.
