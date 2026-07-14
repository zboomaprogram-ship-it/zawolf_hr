import Flutter
import UIKit
import GoogleMaps
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let automaticAttendance = AutomaticAttendanceRegionDelegate()
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyDl5bO63kW9ukQkEEyqdg40oSFh1R8mOSM")
    GeneratedPluginRegistrant.register(with: self)
    configurePersonalAlarmChannel()
    configureAutomaticAttendanceChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
        result(false)
      case "scheduleIosWorkAlarm":
        // The Flutter local-notification fallback is used on iOS. AlarmKit's
        // public API is still changing across Xcode releases, so compiling it
        // into a production HR app would make releases unnecessarily fragile.
        result(FlutterError(code: "alarmkit_unavailable", message: "سيتم استخدام تذكير iPhone المحلي بدلاً من منبه النظام.", details: nil))
      case "cancelIosWorkAlarm":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureAutomaticAttendanceChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "zawolf_hr/automatic_attendance",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "configureIosRegion":
        guard let arguments = call.arguments as? [String: Any],
              let userId = arguments["userId"] as? String,
              let employeeId = arguments["employeeId"] as? String,
              let deviceId = arguments["deviceId"] as? String,
              let locationId = arguments["locationId"] as? String,
              let locationName = arguments["locationName"] as? String,
              let latitude = arguments["latitude"] as? Double,
              let longitude = arguments["longitude"] as? Double,
              let radius = arguments["radiusMeters"] as? Double else {
          result(FlutterError(code: "invalid_geofence", message: "بيانات فرع الحضور غير مكتملة.", details: nil))
          return
        }
        guard CLLocationManager.authorizationStatus() == .authorizedAlways else {
          result(FlutterError(code: "always_location_required", message: "فعّل الموقع دائماً (Always) للحضور التلقائي.", details: nil))
          return
        }
        self?.automaticAttendance.configure(
          userId: userId,
          employeeId: employeeId,
          deviceId: deviceId,
          deviceLabel: arguments["deviceLabel"] as? String ?? "",
          locationId: locationId,
          locationName: locationName,
          latitude: latitude,
          longitude: longitude,
          radius: radius
        )
        result(true)
      case "disableIosRegion":
        self?.automaticAttendance.disable()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

private final class AutomaticAttendanceRegionDelegate: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private let configKey = "zawolf_auto_attendance_config"
  private var pendingEvent: String?

  override init() {
    super.init()
    manager.delegate = self
    manager.allowsBackgroundLocationUpdates = true
    manager.pausesLocationUpdatesAutomatically = true
    restoreMonitoring()
  }

  func configure(
    userId: String,
    employeeId: String,
    deviceId: String,
    deviceLabel: String,
    locationId: String,
    locationName: String,
    latitude: Double,
    longitude: Double,
    radius: Double
  ) {
    let config: [String: Any] = [
      "userId": userId,
      "employeeId": employeeId,
      "deviceId": deviceId,
      "deviceLabel": deviceLabel,
      "locationId": locationId,
      "locationName": locationName,
      "latitude": latitude,
      "longitude": longitude,
      "radius": radius,
    ]
    UserDefaults.standard.set(config, forKey: configKey)
    monitor(config)
  }

  func disable() {
    for region in manager.monitoredRegions {
      if region.identifier.hasPrefix("zawolf_") {
        manager.stopMonitoring(for: region)
      }
    }
    UserDefaults.standard.removeObject(forKey: configKey)
    pendingEvent = nil
  }

  private func restoreMonitoring() {
    guard let config = UserDefaults.standard.dictionary(forKey: configKey) else { return }
    monitor(config)
  }

  private func monitor(_ config: [String: Any]) {
    guard let locationId = config["locationId"] as? String,
          let latitude = config["latitude"] as? Double,
          let longitude = config["longitude"] as? Double,
          let radius = config["radius"] as? Double else { return }
    for region in manager.monitoredRegions where region.identifier.hasPrefix("zawolf_") {
      manager.stopMonitoring(for: region)
    }
    let region = CLCircularRegion(
      center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
      radius: min(max(radius, 10), manager.maximumRegionMonitoringDistance),
      identifier: "zawolf_\(locationId)"
    )
    region.notifyOnEntry = true
    region.notifyOnExit = true
    manager.startMonitoring(for: region)
    manager.requestState(for: region)
  }

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    capture(event: "enter", region: region)
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    capture(event: "exit", region: region)
  }

  func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
    // Initial state can recover an app restart, but is only treated as entry.
    if state == .inside { capture(event: "enter", region: region) }
  }

  private func capture(event: String, region: CLRegion) {
    guard region.identifier.hasPrefix("zawolf_") else { return }
    pendingEvent = event
    manager.requestLocation()
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let event = pendingEvent,
          let location = locations.last,
          location.horizontalAccuracy > 0,
          let config = UserDefaults.standard.dictionary(forKey: configKey),
          let userId = config["userId"] as? String,
          Auth.auth().currentUser?.uid == userId else {
      pendingEvent = nil
      return
    }
    pendingEvent = nil
    let data: [String: Any] = [
      "userId": userId,
      "employeeId": config["employeeId"] as? String ?? "",
      "deviceId": config["deviceId"] as? String ?? "",
      "deviceLabel": config["deviceLabel"] as? String ?? "",
      "locationId": config["locationId"] as? String ?? "",
      "locationName": config["locationName"] as? String ?? "",
      "event": event,
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
      "accuracyMeters": location.horizontalAccuracy,
      "capturedAtMillis": Int64(Date().timeIntervalSince1970 * 1000),
      "source": "ios_region",
      "status": "pending",
      "createdAt": FieldValue.serverTimestamp(),
    ]
    Firestore.firestore().collection("autoAttendanceSignals").addDocument(data: data)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    pendingEvent = nil
  }
}
