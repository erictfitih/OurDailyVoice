# OurDailyVoice

A SwiftUI iOS app for logging daily moods using emoji-based ratings and storing entries in Firebase Firestore.

---

## Overview

OurDailyVoice lets users quickly log how they feel each day using a simple 1–9 emoji scale. Entries are saved per user and organized by date. The app calculates statistics such as daily average mood and most frequent emoji.

---

## Features

* Emoji-based mood logging
* Daily filtering
* Automatic averages
* Most frequent mood detection
* Firebase authentication (anonymous)
* Firestore cloud storage
* Haptic feedback
* Clean SwiftUI UI

---

## Tech Stack

* SwiftUI
* Firebase Auth
* Firebase Firestore
* MVVM architecture
* CocoaPods dependency management

---

## Project Structure

```
OurDailyVoice
├── App
│   └── OurDailyVoiceApp.swift
├── Core
│   ├── Constant.swift
│   ├── Haptics.swift
│   └── Theme.swift
├── Models
│   ├── MoodEntry.swift
│   └── MoodOption.swift
├── Services
│   ├── MoodService.swift
│   └── MoodViewModel.swift
├── Views
│   └── ContentView.swift
└── Assets
```

---

## Setup Instructions

### 1. Clone repo

```
git clone <repo-url>
cd OurDailyVoice
```

### 2. Install dependencies

```
pod install
```

Open workspace (not project):

```
open OurDailyVoice.xcworkspace
```

---

### 3. Firebase Setup

1. Create Firebase project
2. Add iOS app
3. Download **GoogleService-Info.plist**
4. Drag into Xcode project root
5. Ensure bundle identifier matches Firebase console

---

### 4. Enable Authentication

Firebase Console → Authentication → Sign-in Method → Enable:

* Anonymous

---

### 5. Firestore Rules (dev)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

---

## Running

Select simulator or device → Press Run.

---

## Database Schema

```
users/{uid}/moods/{entryId}
```

Mood document:

```
emoji: String
value: Int
day: Timestamp
timestamp: Timestamp
```

---

## Architecture

MVVM separation:

| Layer     | Responsibility         |
| --------- | ---------------------- |
| View      | UI rendering           |
| ViewModel | UI logic + state       |
| Service   | Firebase communication |
| Model     | Data structure         |

---

## Troubleshooting

### No data appears

Check:

* Bundle ID matches plist
* Firebase configured
* Internet connection
* Firestore rules allow reads

---

### Query requires index

Open console link shown in error log and create index.

---

### Build fails

Try:

```
Cmd + Shift + K
```

or delete DerivedData.

---

## Future Improvements

* Club/site grouping
* User login system
* Analytics dashboard
* Mood trends chart
* Push reminders

---
