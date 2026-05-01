# MedReminder Flutter

Flutter mobile client for the MedReminder backend in this repository.

## Features

- Gmail-only signup and login
- Family setup and management (create, join, add member, leave)
- Reminder list, creation, and deletion
- Barcode scanning and medication auto-fill
- Reminder polling for due medication alerts while app is open
- Email testing tools (status, Gmail OAuth test, template test send)

## Backend Requirement

Run the Flask backend from the project root:

```bash
python app.py
```

Default backend URL is expected at `http://10.0.2.2:3006` for Android emulator.

## Configure API Base URL

Override API URL at runtime with `--dart-define`:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3006
```

Common values:

- Android emulator: `http://10.0.2.2:3006`
- iOS simulator / desktop: `http://127.0.0.1:3006`
- Real device: `http://<YOUR_PC_LAN_IP>:3006`

## Run

```bash
flutter pub get
flutter run
```

## Web Testing Notes (Chrome)

- To keep your login saved between runs, use a fixed web port (same origin):

```bash
flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://127.0.0.1:3006
```

- Browsers may block auto-playing audio until you interact with the page.
  Use Settings -> Test Sound once to allow reminder sounds.

## Notes

- Camera permission is required for barcode scanning.
- The app uses the new token-based backend APIs under `/api/v1/*`.

/*/*dark mode 
profiles system 
ester egg to have a tittle in the profile 
edit reminder
splash screen
كتابة _xotk في شاشة الـ Backend Configuration يفعّل “Developer Aura” ويظهر Debug badges.
,
some basic settings in any apps


