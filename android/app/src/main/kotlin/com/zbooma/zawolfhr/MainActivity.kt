package com.zbooma.zawolfhr

import android.content.Intent
import android.provider.AlarmClock
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val personalAlarmChannel = "zawolf_hr/personal_alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
    }
}
