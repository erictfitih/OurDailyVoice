# OurDailyVoice

A SwiftUI iOS app that helps Boys & Girls Club staff understand how kids are feeling. Youth tap an emoji to check in when they arrive and when they leave, and staff use the results to spot trends across rooms, days, and club locations.

Built with SwiftUI and Firebase, and deployed at Boys & Girls Club locations nationwide.

---

## About This Project

OurDailyVoice was built through **Club Next Code Academy**, a Boys & Girls Club program, by a team of six interns. I served as **Lead Software Developer** and co-led the team through design, development, and deployment.

The goal was simple: give club staff a fast, kid-friendly way to hear how their members are doing each day, and turn those check-ins into data they can act on.

## My Role

- Co-led a six-person intern team through planning, development, and deployment
- Architected the app's real-time data flow in Swift, syncing mood check-ins to Firebase so staff dashboards update without a manual refresh
- Structured the Firestore data model for multi-location reporting, so each club site sees its own trends without mixing data with other sites
- Designed the child-facing, icon-based interface to keep check-ins fast and accessible for younger users

---

## Screenshots

<img width="220" alt="preview" src="https://github.com/user-attachments/assets/16912853-b630-4803-b849-bca528776a2a" />
<img width="220" alt="preview-4" src="https://github.com/user-attachments/assets/6a3ca64c-1dac-48af-83b6-3441359806ce" />
<img width="220" alt="preview-3" src="https://github.com/user-attachments/assets/7693233d-d096-40cb-8eb6-011ec04836fc" />
<img width="220" alt="preview-2" src="https://github.com/user-attachments/assets/195941fa-411f-41f4-87d2-8b53d7f350d9" />

---

## Features

### For Youth
- One-tap emoji mood check-ins on a simple 1–9 scale
- Separate "Coming In" and "Leaving" check-ins
- Haptic feedback for a quick, satisfying response

### For Staff and Administrators
- **Multi-club support:** select a club site and room, with each site's data kept separate
- **Entry and exit comparisons:** daily averages for arrival and departure moods, plus the change between them
- **Club schedules:** configurable entry and exit windows for summer and the school year, including one-day exceptions
- **Staff review:** check-ins that need a staff decision are flagged, with an audible staff alert
- **Custom emoji palettes:** clubs can set their own emoji sets, including temporary palettes for specific date ranges
- **Club analytics:** daily and room-level summaries and mood distributions
- **Organization analytics:** a cross-club view with weighted calculations across locations

---

## Tech Stack

- **Swift / SwiftUI**
- **Firebase Authentication** (anonymous sign-in)
- **Cloud Firestore** for real-time cloud storage
- **MVVM** architecture
- **CocoaPods** for dependency management
- iOS 17+

---

## Architecture

| Layer     | Responsibility                          |
| --------- | --------------------------------------- |
| View      | UI rendering (SwiftUI)                  |
| ViewModel | UI state and presentation logic         |
| Service   | Firestore reads, writes, and listeners  |
| Model     | Data structures (sites, moods, sessions, schedules) |

### Data Model

Each club site owns its own data, which keeps locations isolated from one another:

```
registered_sites/{clubId}
├── moods/{entryId}
├── moodResponses/{responseId}
├── sessions/{sessionId}
└── settings/
    ├── entryExitSchedule
    └── emojiPalette
```

---

## Project Structure

```
OurDailyVoice
├── App        # App entry point and app state
├── Core       # Constants, theme, haptics, staff alerts, local stores
├── Models     # Site, MoodEntry, MoodOption, SessionDay, ClubSchedule, ...
├── Services   # MoodService (Firestore) and MoodViewModel
├── Views      # Check-in, club picker, rooms, schedule editor, analytics
└── Assets
```

---

## Running Locally

1. Clone the repo and install dependencies:
   ```
   git clone https://github.com/erictfitih/OurDailyVoice.git
   cd OurDailyVoice
   pod install
   open OurDailyVoice.xcworkspace
   ```
2. Create your own Firebase project and add an iOS app with a matching bundle identifier.
3. Download your own `GoogleService-Info.plist` and add it to the Xcode project. This file is intentionally excluded from the repo via `.gitignore`.
4. In the Firebase console, enable **Anonymous** sign-in under Authentication.
5. Select a simulator or device and press **Run**.

### Security Note

This app handles data about young people, so Firestore should never run with open rules. At a minimum, require authentication before allowing reads or writes, and scope access to the club the user belongs to:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /registered_sites/{clubId}/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## Team

Built by a team of six interns at Club Next Code Academy (Boys & Girls Club).
