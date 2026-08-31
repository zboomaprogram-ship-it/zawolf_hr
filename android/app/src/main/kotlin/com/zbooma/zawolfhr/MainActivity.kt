package com.zbooma.zawolfhr

import android.content.Intent
import android.app.PendingIntent
import android.app.AlarmManager
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterFragmentActivity() {
    private val personalAlarmChannel = "zawolf_hr/personal_alarm"
    private val autoAttendanceChannel = "zawolf_hr/automatic_attendance"
    private val deviceSecurityChannel = "zawolf_hr/device_security"
    private lateinit var geofencingClient: GeofencingClient

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        geofencingClient = LocationServices.getGeofencingClient(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, personalAlarmChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSystemAlarm" -> {
                        val hour = call.argument<Int>("hour") ?: 8
                        val minute = call.argument<Int>("minute") ?: 45
                        val message = call.argument<String>("message") ?: "ZaWolf HR"
                        val userId = call.argument<String>("userId")
                        if (userId.isNullOrBlank()) {
                            result.error("INVALID_ALARM", "بيانات منبه الدوام غير مكتملة.", null)
                            return@setMethodCallHandler
                        }
                        try {
                            PersonalAlarmScheduler.schedule(this, userId, hour, minute, message)
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("ALARM_UNAVAILABLE", "تعذر جدولة منبه الدوام على هذا الجهاز.", error.message)
                        }
                    }
                    "setDatedSystemAlarms" -> {
                        val ownerId = call.argument<String>("ownerId")
                        val rawAlarms = call.argument<List<Map<String, Any>>>("alarms")
                        if (ownerId.isNullOrBlank() || rawAlarms == null) {
                            result.error("INVALID_ALARM", "بيانات منبهات الحضور غير مكتملة.", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val alarms = rawAlarms.mapNotNull { item ->
                                val key = item["key"] as? String
                                val triggerAtMillis = item["triggerAtMillis"] as? Number
                                if (key.isNullOrBlank() || triggerAtMillis == null) null else
                                    DatedAlarm(
                                        key = key,
                                        triggerAtMillis = triggerAtMillis.toLong(),
                                        message = item["message"] as? String ?: "حان وقت تسجيل الحضور في ZaWolf HR",
                                    )
                            }
                            PersonalAlarmScheduler.replaceDated(this, ownerId, alarms)
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("ALARM_UNAVAILABLE", "تعذر جدولة منبهات الحضور.", error.message)
                        }
                    }
                    "cancelSystemAlarm" -> {
                        val userId = call.argument<String>("userId")
                        if (userId.isNullOrBlank()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        try {
                            PersonalAlarmScheduler.cancel(this, userId)
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("ALARM_UNAVAILABLE", "تعذر إيقاف منبه الدوام.", error.message)
                        }
                    }
                    "canUseSystemAlarm" -> {
                        val notificationsEnabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
                        val notificationPermissionGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                            ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        val exactAlarmGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()
                        result.success(notificationsEnabled && notificationPermissionGranted && exactAlarmGranted)
                    }
                    "requestExactAlarmPermission" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        if (alarmManager.canScheduleExactAlarms()) {
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        try {
                            startActivity(
                                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                    data = Uri.parse("package:$packageName")
                                },
                            )
                            result.success(false)
                        } catch (error: Exception) {
                            startActivity(
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:$packageName")
                                },
                            )
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, autoAttendanceChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "configureAndroidGeofence" -> configureAndroidGeofence(call, result)
                    "disableAndroidGeofence" -> disableAndroidGeofence(result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceSecurityChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSecuritySignals" -> {
                        val developerOptionsEnabled = Settings.Global.getInt(
                            contentResolver,
                            Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                            0,
                        ) == 1
                        val adbEnabled = Settings.Global.getInt(
                            contentResolver,
                            Settings.Global.ADB_ENABLED,
                            0,
                        ) == 1
                        result.success(
                            mapOf(
                                "developerOptionsEnabled" to developerOptionsEnabled,
                                "adbEnabled" to adbEnabled,
                            ),
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun configureAndroidGeofence(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val userId = call.argument<String>("userId")
        val employeeId = call.argument<String>("employeeId") ?: ""
        val deviceId = call.argument<String>("deviceId") ?: ""
        val deviceLabel = call.argument<String>("deviceLabel") ?: ""
        val rawLocations = call.argument<List<Map<String, Any?>>>("locations")
            ?: listOfNotNull(call.arguments as? Map<String, Any?>)
        val locations = rawLocations.take(20).mapNotNull { raw ->
            val id = raw["locationId"] as? String
            val latitude = (raw["latitude"] as? Number)?.toDouble()
            val longitude = (raw["longitude"] as? Number)?.toDouble()
            val radius = (raw["radiusMeters"] as? Number)?.toDouble()
            if (id.isNullOrBlank() || latitude == null || longitude == null || radius == null || radius <= 0) null
            else AttendanceRegion(
                locationId = id,
                locationName = raw["locationName"] as? String ?: "",
                latitude = latitude,
                longitude = longitude,
                radiusMeters = radius,
                assignmentId = raw["assignmentId"] as? String ?: "",
                assignmentVersion = (raw["assignmentVersion"] as? Number)?.toInt() ?: 0,
            )
        }
        if (userId.isNullOrEmpty() || deviceId.isEmpty() || locations.isEmpty()) {
            result.error("INVALID_GEOFENCE", "بيانات فرع الحضور غير مكتملة.", null)
            return
        }
        val hasFine = ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val hasBackground = android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!hasFine || !hasBackground) {
            result.error("BACKGROUND_LOCATION_REQUIRED", "فعّل الموقع الدائم (Always allow) للحضور التلقائي.", null)
            return
        }
        val prefs = getSharedPreferences("auto_attendance", Context.MODE_PRIVATE)
        val locationMetadata = JSONObject()
        locations.forEach { location ->
            locationMetadata.put(location.locationId, JSONObject().apply {
                put("locationName", location.locationName)
                put("assignmentId", location.assignmentId)
                put("assignmentVersion", location.assignmentVersion)
            })
        }
        prefs.edit()
            .putString("userId", userId)
            .putString("employeeId", employeeId)
            .putString("deviceId", deviceId)
            .putString("deviceLabel", deviceLabel)
            .putString("locationMetadata", locationMetadata.toString())
            .apply()
        val geofences = locations.map { location -> Geofence.Builder()
            .setRequestId("zawolf_${location.locationId}")
            .setCircularRegion(location.latitude, location.longitude, location.radiusMeters.toFloat())
            // Check-in and exit evidence are both handled server-side.  The
            // server applies HR's checkout policy and return-grace rules; the
            // device never decides payroll or permission exceptions.
            .setTransitionTypes(
                Geofence.GEOFENCE_TRANSITION_ENTER or
                    Geofence.GEOFENCE_TRANSITION_EXIT
            )
            .setNotificationResponsiveness(10_000)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .build()
        }
        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofences(geofences)
            .build()
        geofencingClient.removeGeofences(geofencePendingIntent()).continueWithTask {
            geofencingClient.addGeofences(request, geofencePendingIntent())
        }.addOnSuccessListener { result.success(true) }
            .addOnFailureListener { error -> result.error("GEOFENCE_FAILED", error.message, null) }
    }

    private data class AttendanceRegion(
        val locationId: String,
        val locationName: String,
        val latitude: Double,
        val longitude: Double,
        val radiusMeters: Double,
        val assignmentId: String,
        val assignmentVersion: Int,
    )

    private fun disableAndroidGeofence(result: MethodChannel.Result) {
        geofencingClient.removeGeofences(geofencePendingIntent())
            .addOnCompleteListener {
                getSharedPreferences("auto_attendance", Context.MODE_PRIVATE).edit().clear().apply()
                result.success(true)
            }
    }

    private fun geofencePendingIntent(): PendingIntent {
        val intent = Intent(this, AttendanceGeofenceReceiver::class.java)
        return PendingIntent.getBroadcast(
            this,
            4488,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
    }
}
