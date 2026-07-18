import Flutter
import UIKit
import GoogleMaps
#if canImport(AlarmKit)
import AlarmKit
import SwiftUI
#endif

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyDl5bO63kW9ukQkEEyqdg40oSFh1R8mOSM")
    GeneratedPluginRegistrant.register(with: self)
    configurePersonalAlarmChannel()
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
