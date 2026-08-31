import Flutter
import UIKit
import GoogleMaps
import CoreLocation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
#if canImport(AlarmKit)
import AlarmKit
import SwiftUI
#endif

extension AppDelegate: CLLocationManagerDelegate {
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard let result = pendingAlwaysPermissionResult else { return }
    switch manager.authorizationStatus {
    case .authorizedAlways:
      pendingAlwaysPermissionResult = nil
      result(true)
    case .denied, .restricted:
      pendingAlwaysPermissionResult = nil
      result(false)
    default:
      break
    }
  }

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    captureAutomaticAttendanceEvent("enter", region: region)
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    // Exit is evidence only. The server owns return grace, approved-permission
    // exceptions, break windows and the eventual checkout decision.
    captureAutomaticAttendanceEvent("exit", region: region)
  }

  func locationManager(
    _ manager: CLLocationManager,
    didDetermineState state: CLRegionState,
    for region: CLRegion
  ) {
    // Enabling while already at the branch may check in, but enabling away from
    // it must not create a checkout.
    if state == .inside {
      captureAutomaticAttendanceEvent("enter", region: region)
    }
  }

  fileprivate func captureAutomaticAttendanceEvent(_ event: String, region: CLRegion) {
    guard region.identifier.hasPrefix("zawolf_") else { return }
    pendingAttendanceEvent = event
    pendingAttendanceLocationId = String(region.identifier.dropFirst("zawolf_".count))
    if attendanceBackgroundTask == .invalid {
      attendanceBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "ZaWolfAttendance") {
        self.finishAttendanceBackgroundTask()
      }
    }
    if let location = attendanceLocationManager.location,
       abs(location.timestamp.timeIntervalSinceNow) < 120 {
      writeAutomaticAttendanceSignal(event: event, location: location)
    } else {
      attendanceLocationManager.requestLocation()
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let event = pendingAttendanceEvent, let location = locations.last else { return }
    writeAutomaticAttendanceSignal(event: event, location: location)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    pendingAttendanceEvent = nil
    finishAttendanceBackgroundTask()
  }

  fileprivate func writeAutomaticAttendanceSignal(event: String, location: CLLocation) {
    pendingAttendanceEvent = nil
    let defaults = UserDefaults.standard
    guard defaults.bool(forKey: "auto_attendance_enabled"),
          let configuredUserId = defaults.string(forKey: "auto_attendance_userId"),
          !configuredUserId.isEmpty else {
      finishAttendanceBackgroundTask()
      return
    }

    if FirebaseApp.app() == nil { FirebaseApp.configure() }
    guard Auth.auth().currentUser?.uid == configuredUserId else {
      finishAttendanceBackgroundTask()
      return
    }
    let locationId = pendingAttendanceLocationId ?? defaults.string(forKey: "auto_attendance_locationId") ?? ""
    pendingAttendanceLocationId = nil
    let metadata = automaticAttendanceLocations().first {
      ($0["locationId"] as? String) == locationId
    } ?? [:]
    var values: [String: Any] = [
      "userId": configuredUserId,
      "employeeId": defaults.string(forKey: "auto_attendance_employeeId") ?? "",
      "deviceId": defaults.string(forKey: "auto_attendance_deviceId") ?? "",
      "deviceLabel": defaults.string(forKey: "auto_attendance_deviceLabel") ?? "",
      "locationId": locationId,
      "locationName": metadata["locationName"] as? String ?? defaults.string(forKey: "auto_attendance_locationName") ?? "",
      "event": event,
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
      "accuracyMeters": max(location.horizontalAccuracy, 0),
      "capturedAtMillis": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios_region",
      "status": "pending",
      "locationMocked": false,
      "createdAt": FieldValue.serverTimestamp(),
    ]
    if let assignmentId = metadata["assignmentId"] as? String, !assignmentId.isEmpty {
      values["assignmentId"] = assignmentId
    }
    if let assignmentVersion = metadata["assignmentVersion"] as? NSNumber,
       assignmentVersion.intValue > 0 {
      values["assignmentVersion"] = assignmentVersion.intValue
    }
    Firestore.firestore().collection("autoAttendanceSignals").addDocument(data: values) { _ in
      self.finishAttendanceBackgroundTask()
    }
  }

  fileprivate func finishAttendanceBackgroundTask() {
    guard attendanceBackgroundTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(attendanceBackgroundTask)
    attendanceBackgroundTask = .invalid
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  fileprivate let attendanceLocationManager = CLLocationManager()
  fileprivate var pendingAttendanceEvent: String?
  fileprivate var pendingAttendanceLocationId: String?
  fileprivate var attendanceBackgroundTask: UIBackgroundTaskIdentifier = .invalid
  fileprivate var pendingAlwaysPermissionResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyDl5bO63kW9ukQkEEyqdg40oSFh1R8mOSM")
    GeneratedPluginRegistrant.register(with: self)
    configurePersonalAlarmChannel()
    configureAutomaticAttendanceChannel()
    restoreAutomaticAttendanceMonitor()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureAutomaticAttendanceChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    attendanceLocationManager.delegate = self
    let channel = FlutterMethodChannel(
      name: "zawolf_hr/automatic_attendance",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "requestIosAlwaysPermission":
        if self.attendanceLocationManager.authorizationStatus == .authorizedAlways {
          result(true)
        } else if self.attendanceLocationManager.authorizationStatus == .denied ||
                    self.attendanceLocationManager.authorizationStatus == .restricted {
          result(false)
        } else {
          self.pendingAlwaysPermissionResult = result
          self.attendanceLocationManager.requestAlwaysAuthorization()
        }
      case "configureIosGeofence":
        guard self.attendanceLocationManager.authorizationStatus == .authorizedAlways else {
          result(FlutterError(
            code: "BACKGROUND_LOCATION_REQUIRED",
            message: "فعّل الموقع دائماً للحضور التلقائي من إعدادات iPhone.",
            details: nil
          ))
          return
        }
        guard let data = call.arguments as? [String: Any],
              let userId = data["userId"] as? String, !userId.isEmpty,
              let deviceId = data["deviceId"] as? String, !deviceId.isEmpty else {
          result(FlutterError(code: "INVALID_GEOFENCE", message: "بيانات فرع الحضور غير مكتملة.", details: nil))
          return
        }
        let rawLocations = (data["locations"] as? [[String: Any]]) ?? [data]
        let locations = Array(rawLocations.prefix(20)).compactMap { raw -> [String: Any]? in
          guard let locationId = raw["locationId"] as? String, !locationId.isEmpty,
                let latitude = (raw["latitude"] as? NSNumber)?.doubleValue,
                let longitude = (raw["longitude"] as? NSNumber)?.doubleValue,
                let requestedRadius = (raw["radiusMeters"] as? NSNumber)?.doubleValue,
                requestedRadius > 0 else { return nil }
          var normalized = raw
          normalized["locationId"] = locationId
          normalized["latitude"] = latitude
          normalized["longitude"] = longitude
          normalized["radiusMeters"] = min(max(requestedRadius, 100), self.attendanceLocationManager.maximumRegionMonitoringDistance)
          return normalized
        }
        guard !locations.isEmpty else {
          result(FlutterError(code: "INVALID_GEOFENCE", message: "لا توجد مواقع حضور صالحة للتسجيل.", details: nil))
          return
        }
        let defaults = UserDefaults.standard
        data.forEach { key, value in
          if value is String || value is NSNumber { defaults.set(value, forKey: "auto_attendance_\(key)") }
        }
        if let encoded = try? JSONSerialization.data(withJSONObject: locations) {
          defaults.set(encoded, forKey: "auto_attendance_locations")
        }
        if let first = locations.first {
          defaults.set(first["locationId"], forKey: "auto_attendance_locationId")
          defaults.set(first["locationName"], forKey: "auto_attendance_locationName")
          defaults.set(first["latitude"], forKey: "auto_attendance_latitude")
          defaults.set(first["longitude"], forKey: "auto_attendance_longitude")
          defaults.set(first["radiusMeters"], forKey: "auto_attendance_radiusMeters")
        }
        defaults.set(true, forKey: "auto_attendance_enabled")
        self.startAttendanceMonitors(locations)
        result(true)
      case "disableIosGeofence":
        self.stopAttendanceMonitors()
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("auto_attendance_") {
          defaults.removeObject(forKey: key)
        }
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  fileprivate func startAttendanceMonitor(
    locationId: String,
    latitude: CLLocationDegrees,
    longitude: CLLocationDegrees,
    radius: CLLocationDistance
  ) {
    guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
    let region = CLCircularRegion(
      center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
      radius: radius,
      identifier: "zawolf_\(locationId)"
    )
    region.notifyOnEntry = true
    // An exit is sent to the backend as evidence only. The backend applies the
    // HR-owned policy rather than allowing the device to alter payroll state.
    region.notifyOnExit = true
    attendanceLocationManager.startMonitoring(for: region)
    attendanceLocationManager.requestState(for: region)
  }

  fileprivate func startAttendanceMonitors(_ locations: [[String: Any]]) {
    stopAttendanceMonitors()
    for raw in locations.prefix(20) {
      guard let locationId = raw["locationId"] as? String,
            let latitude = (raw["latitude"] as? NSNumber)?.doubleValue,
            let longitude = (raw["longitude"] as? NSNumber)?.doubleValue,
            let radius = (raw["radiusMeters"] as? NSNumber)?.doubleValue else { continue }
      startAttendanceMonitor(
        locationId: locationId,
        latitude: latitude,
        longitude: longitude,
        radius: radius
      )
    }
  }

  fileprivate func automaticAttendanceLocations() -> [[String: Any]] {
    guard let data = UserDefaults.standard.data(forKey: "auto_attendance_locations"),
          let object = try? JSONSerialization.jsonObject(with: data),
          let decoded = object as? [[String: Any]] else {
      return []
    }
    return decoded
  }

  fileprivate func stopAttendanceMonitors() {
    attendanceLocationManager.monitoredRegions
      .filter { $0.identifier.hasPrefix("zawolf_") }
      .forEach(attendanceLocationManager.stopMonitoring)
  }

  private func restoreAutomaticAttendanceMonitor() {
    attendanceLocationManager.delegate = self
    let defaults = UserDefaults.standard
    guard defaults.bool(forKey: "auto_attendance_enabled") else { return }
    let locations = automaticAttendanceLocations()
    if !locations.isEmpty {
      startAttendanceMonitors(locations)
    } else if let locationId = defaults.string(forKey: "auto_attendance_locationId") {
      startAttendanceMonitor(
        locationId: locationId,
        latitude: defaults.double(forKey: "auto_attendance_latitude"),
        longitude: defaults.double(forKey: "auto_attendance_longitude"),
        radius: defaults.double(forKey: "auto_attendance_radiusMeters")
      )
    }
  }

  private func configurePersonalAlarmChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "zawolf_hr/personal_alarm",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "iosAlarmAvailability":
        if #available(iOS 26.0, *) {
          #if canImport(AlarmKit)
          result(true)
          #else
          result(false)
          #endif
        } else {
          result(false)
        }
      case "iosAlarmStatus":
        var status: [String: Any] = [
          "systemVersion": UIDevice.current.systemVersion,
          "alarmKitCompiled": false,
          "available": false,
          "authorization": "unavailable",
        ]
        if #available(iOS 26.0, *) {
          #if canImport(AlarmKit)
          status["alarmKitCompiled"] = true
          status["available"] = true
          switch AlarmManager.shared.authorizationState {
          case .notDetermined:
            status["authorization"] = "notDetermined"
          case .authorized:
            status["authorization"] = "authorized"
          case .denied:
            status["authorization"] = "denied"
          @unknown default:
            status["authorization"] = "unknown"
          }
          #endif
        }
        result(status)
      case "scheduleIosWorkAlarm":
        guard let arguments = call.arguments as? [String: Any],
              let hour = arguments["hour"] as? Int,
              let minute = arguments["minute"] as? Int else {
          result(FlutterError(code: "invalid_alarm", message: "وقت المنبه غير صالح.", details: nil))
          return
        }
        if #available(iOS 26.0, *) {
          #if canImport(AlarmKit)
          Task { @MainActor in
            do {
              let alarmID = try await self.scheduleWorkAlarm(
                existingID: arguments["alarmId"] as? String,
                hour: hour,
                minute: minute
              )
              result(["alarmId": alarmID.uuidString])
            } catch {
              result(FlutterError(code: "alarmkit_failed", message: "تعذر تفعيل منبه iPhone. تأكد من السماح بالمنبهات في الإعدادات.", details: error.localizedDescription))
            }
          }
          #else
          result(FlutterError(code: "alarmkit_unavailable", message: "AlarmKit غير متاح في هذا البناء.", details: nil))
          #endif
        } else {
          result(FlutterError(code: "alarmkit_unavailable", message: "سيتم استخدام تذكير iPhone المحلي بدلاً من منبه النظام.", details: nil))
        }
      case "cancelIosWorkAlarm":
        if #available(iOS 26.0, *) {
          #if canImport(AlarmKit)
          if let arguments = call.arguments as? [String: Any],
             let rawID = arguments["alarmId"] as? String,
             let alarmID = UUID(uuidString: rawID) {
            do {
              try AlarmManager.shared.cancel(id: alarmID)
            } catch {
              result(FlutterError(code: "alarmkit_cancel_failed", message: "تعذر إلغاء منبه iPhone.", details: error.localizedDescription))
              return
            }
          }
          #endif
        }
        result(nil)
      case "scheduleIosDatedAlarms":
        guard let arguments = call.arguments as? [String: Any],
              let rawAlarms = arguments["alarms"] as? [[String: Any]] else {
          result(FlutterError(code: "invalid_alarm", message: "بيانات منبهات الحضور غير مكتملة.", details: nil))
          return
        }
        if #available(iOS 26.0, *) {
          #if canImport(AlarmKit)
          Task { @MainActor in
            do {
              let ids = try await self.scheduleDatedWorkAlarms(
                existingIDs: arguments["alarmIds"] as? [String] ?? [],
                rawAlarms: rawAlarms
              )
              result(["alarmIds": ids.map(\.uuidString)])
            } catch {
              result(FlutterError(code: "alarmkit_failed", message: "تعذر تفعيل منبهات الحضور على iPhone.", details: error.localizedDescription))
            }
          }
          #else
          result(FlutterError(code: "alarmkit_unavailable", message: "AlarmKit غير متاح في هذا البناء.", details: nil))
          #endif
        } else {
          result(FlutterError(code: "alarmkit_unavailable", message: "AlarmKit يتطلب iOS 26 أو أحدث.", details: nil))
        }
      case "cancelIosDatedAlarms":
        if #available(iOS 26.0, *) {
          #if canImport(AlarmKit)
          if let arguments = call.arguments as? [String: Any],
             let rawIDs = arguments["alarmIds"] as? [String] {
            for rawID in rawIDs {
              if let alarmID = UUID(uuidString: rawID) {
                try? AlarmManager.shared.cancel(id: alarmID)
              }
            }
          }
          #endif
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  #if canImport(AlarmKit)
  @available(iOS 26.0, *)
  @MainActor
  private func scheduleWorkAlarm(existingID: String?, hour: Int, minute: Int) async throws -> UUID {
    let manager = AlarmManager.shared
    let authorization: AlarmManager.AuthorizationState
    if manager.authorizationState == .notDetermined {
      authorization = try await manager.requestAuthorization()
    } else {
      authorization = manager.authorizationState
    }
    guard authorization == .authorized else {
      throw WorkAlarmError.authorizationDenied
    }

    if let rawID = existingID, let oldID = UUID(uuidString: rawID) {
      try? manager.cancel(id: oldID)
    }

    let alarmID = UUID()
    let time = Alarm.Schedule.Relative.Time(
      hour: min(max(hour, 0), 23),
      minute: min(max(minute, 0), 59)
    )
    let recurrence = Alarm.Schedule.Relative.Recurrence.weekly([
      .monday, .tuesday, .wednesday, .thursday, .saturday, .sunday,
    ])
    let schedule = Alarm.Schedule.relative(
      Alarm.Schedule.Relative(time: time, repeats: recurrence)
    )
    let stopButton = AlarmButton(
      text: "إيقاف",
      textColor: .white,
      systemImageName: "stop.circle"
    )
    let alert = AlarmPresentation.Alert(
      title: "منبه الدوام - ZaWolf HR",
      stopButton: stopButton
    )
    let attributes = AlarmAttributes<WorkAlarmMetadata>(
      presentation: AlarmPresentation(alert: alert),
      metadata: WorkAlarmMetadata(),
      tintColor: Color(red: 0.0, green: 0.83, blue: 0.88)
    )
    let configuration: AlarmManager.AlarmConfiguration<WorkAlarmMetadata> = .alarm(
      schedule: schedule,
      attributes: attributes,
      sound: .named("wolf_alarm.wav")
    )
    _ = try await manager.schedule(id: alarmID, configuration: configuration)
    return alarmID
  }

  @available(iOS 26.0, *)
  @MainActor
  private func scheduleDatedWorkAlarms(
    existingIDs: [String],
    rawAlarms: [[String: Any]]
  ) async throws -> [UUID] {
    let manager = AlarmManager.shared
    let authorization: AlarmManager.AuthorizationState
    if manager.authorizationState == .notDetermined {
      authorization = try await manager.requestAuthorization()
    } else {
      authorization = manager.authorizationState
    }
    guard authorization == .authorized else {
      throw WorkAlarmError.authorizationDenied
    }

    var scheduledIDs: [UUID] = []
    do {
      for rawAlarm in rawAlarms {
        guard let millis = rawAlarm["triggerAtMillis"] as? NSNumber else { continue }
        let triggerDate = Date(timeIntervalSince1970: millis.doubleValue / 1000)
        guard triggerDate > Date() else { continue }

        let alarmID = UUID()
        let schedule = Alarm.Schedule.fixed(triggerDate)
        let stopButton = AlarmButton(
          text: "إيقاف",
          textColor: .white,
          systemImageName: "stop.circle"
        )
        let alert = AlarmPresentation.Alert(
          title: "منبه تسجيل الحضور - ZaWolf HR",
          stopButton: stopButton
        )
        let attributes = AlarmAttributes<WorkAlarmMetadata>(
          presentation: AlarmPresentation(alert: alert),
          metadata: WorkAlarmMetadata(),
          tintColor: Color(red: 0.0, green: 0.83, blue: 0.88)
        )
        let configuration: AlarmManager.AlarmConfiguration<WorkAlarmMetadata> = .alarm(
          schedule: schedule,
          attributes: attributes,
          sound: .named("wolf_alarm.wav")
        )
        _ = try await manager.schedule(id: alarmID, configuration: configuration)
        scheduledIDs.append(alarmID)
      }
    } catch {
      for alarmID in scheduledIDs {
        try? manager.cancel(id: alarmID)
      }
      throw error
    }
    for rawID in existingIDs {
      if let alarmID = UUID(uuidString: rawID) {
        try? manager.cancel(id: alarmID)
      }
    }
    return scheduledIDs
  }
  #endif
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct WorkAlarmMetadata: AlarmMetadata {}

private enum WorkAlarmError: LocalizedError {
  case authorizationDenied

  var errorDescription: String? {
    "لم يتم السماح لتطبيق ZaWolf HR بإنشاء منبهات النظام."
  }
}
#endif
