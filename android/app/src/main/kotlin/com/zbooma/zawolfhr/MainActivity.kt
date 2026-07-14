package com.zbooma.zawolfhr

import android.content.Intent
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.provider.AlarmClock
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val personalAlarmChannel = "zawolf_hr/personal_alarm"
    private val autoAttendanceChannel = "zawolf_hr/automatic_attendance"
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
                        val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                            putExtra(AlarmClock.EXTRA_HOUR, hour)
                            putExtra(AlarmClock.EXTRA_MINUTES, minute)
                            putExtra(AlarmClock.EXTRA_MESSAGE, message)
                            // Keep the Clock app visible so the employee can confirm
                            // the alarm and choose its repeat behavior.
                            putExtra(AlarmClock.EXTRA_SKIP_UI, false)
                        }
                        try {
                            startActivity(intent)
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("CLOCK_UNAVAILABLE", "تعذر فتح تطبيق الساعة على هذا الجهاز.", error.message)
                        }
                    }
                    "showSystemAlarms" -> {
                        try {
                            startActivity(Intent(AlarmClock.ACTION_SHOW_ALARMS))
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("CLOCK_UNAVAILABLE", "تعذر فتح تطبيق الساعة على هذا الجهاز.", error.message)
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
    }

    private fun configureAndroidGeofence(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val userId = call.argument<String>("userId")
        val employeeId = call.argument<String>("employeeId") ?: ""
        val deviceId = call.argument<String>("deviceId") ?: ""
        val deviceLabel = call.argument<String>("deviceLabel") ?: ""
        val locationId = call.argument<String>("locationId")
        val locationName = call.argument<String>("locationName") ?: ""
        val latitude = call.argument<Double>("latitude")
        val longitude = call.argument<Double>("longitude")
        val radius = call.argument<Double>("radiusMeters")
        if (userId.isNullOrEmpty() || deviceId.isEmpty() || locationId.isNullOrEmpty() || latitude == null || longitude == null || radius == null) {
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
        prefs.edit()
            .putString("userId", userId)
            .putString("employeeId", employeeId)
            .putString("deviceId", deviceId)
            .putString("deviceLabel", deviceLabel)
            .putString("locationId", locationId)
            .putString("locationName", locationName)
            .apply()
        val geofence = Geofence.Builder()
            .setRequestId("zawolf_$locationId")
            .setCircularRegion(latitude, longitude, radius.toFloat())
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
            .setNotificationResponsiveness(10_000)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .build()
        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofence(geofence)
            .build()
        geofencingClient.removeGeofences(geofencePendingIntent()).continueWithTask {
            geofencingClient.addGeofences(request, geofencePendingIntent())
        }.addOnSuccessListener { result.success(true) }
            .addOnFailureListener { error -> result.error("GEOFENCE_FAILED", error.message, null) }
    }

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
