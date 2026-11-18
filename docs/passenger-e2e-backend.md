# Passenger E2E backend

The normal Passenger build keeps its existing platform defaults:

- Android emulator: `http://10.0.2.2:8080`
- Other local targets: `http://localhost:8080`

The isolated Android E2E backend can only be selected in a debug build,
with both compile-time defines set to the expected values. From PowerShell, run:

```powershell
flutter run -d emulator-5554 --dart-define=CITY6_PASSENGER_E2E=true --dart-define=CITY6_BACKEND_URL=http://10.0.2.2:8082
```

The E2E backend URL is deliberately restricted to `http://10.0.2.2:8082`.
Missing or different URLs fail closed; they never fall back to port 8080.
Profile and release builds reject E2E mode and ignore a URL define unless E2E
mode is also requested, in which case startup is refused.

Secure Storage credentials and local active rides use separate `e2e` keys in
this mode. Existing default-backend Secure Storage keys and Passenger 1/2 ride
data are left in place and remain available to normal builds. The app does not
copy or send those credentials to the isolated backend.

The isolated backend must itself be configured for `city6_test:5433` and Mock
SMS before this command is used. This client configuration does not change the
server, database, emulator data, or SMS provider.
