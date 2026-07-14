package com.zbooma.zawolfhr

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore

class AttendanceGeofenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        val event = GeofencingEvent.fromIntent(intent) ?: run {
            pending.finish()
            return
        }
        if (event.hasError()) {
            pending.finish()
            return
        }
        val transition = when (event.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> "enter"
            Geofence.GEOFENCE_TRANSITION_EXIT -> "exit"
            else -> {
                pending.finish()
                return
            }
        }
        val prefs = context.getSharedPreferences("auto_attendance", Context.MODE_PRIVATE)
        val configuredUserId = prefs.getString("userId", null)
        val firebaseUser = FirebaseAuth.getInstance().currentUser
        val location = event.triggeringLocation
        if (configuredUserId.isNullOrEmpty() || firebaseUser?.uid != configuredUserId || location == null) {
            pending.finish()
            return
        }
        val data = hashMapOf<String, Any>(
            "userId" to configuredUserId,
            "employeeId" to (prefs.getString("employeeId", "") ?: ""),
            "deviceId" to (prefs.getString("deviceId", "") ?: ""),
            "deviceLabel" to (prefs.getString("deviceLabel", "") ?: ""),
            "locationId" to (prefs.getString("locationId", "") ?: ""),
            "locationName" to (prefs.getString("locationName", "") ?: ""),
            "event" to transition,
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "accuracyMeters" to location.accuracy.toDouble(),
            "capturedAtMillis" to System.currentTimeMillis(),
            "source" to "android_geofence",
            "status" to "pending",
            "createdAt" to FieldValue.serverTimestamp(),
        )
        FirebaseFirestore.getInstance().collection("autoAttendanceSignals")
            .add(data)
            .addOnCompleteListener { pending.finish() }
    }
}
