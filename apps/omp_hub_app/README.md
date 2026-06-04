# OMP Pi Hub Mobile Companion

Flutter Android client for `omp-pi-hub-mobile-server` v2.1.0. It connects to the shared hub server and controls both `omp` and `pi` sessions.

## Run from source

```bash
cd apps/omp_hub_app
flutter pub get
flutter run
```

## Build APK

```bash
flutter build apk --release
```

APK outputs are written under:

```text
build/app/outputs/flutter-apk/
```

## Connect

Start the shared hub from either CLI first:

```text
/hub start
```

Then enter the hub URL and token in the app. The app adds `http://` automatically if you enter only `host:port`.

Common URLs:

- Android emulator: `http://10.0.2.2:18000`
- Physical phone on LAN: `http://<hub-host-lan-ip>:18000`
- VPN or other routed network: `http://<hub-host-ip>:18000`

Token file on the hub host:

```text
~/.hub-dashboard/server/config.json
```

The app shows a CLI picker on New Session only when the server reports both `omp` and `pi` in `availableClis`.

## Test

```bash
flutter analyze
flutter test
```
