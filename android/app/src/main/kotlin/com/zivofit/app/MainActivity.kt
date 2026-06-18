package com.zivofit.app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.healthtrack.mvp/workout_notification"
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "workout_live_channel_v2"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1002)
                        }
                    }
                    result.success(true)
                }
                "startNotification" -> {
                    val title = call.argument<String>("title") ?: "Active Workout"
                    val body = call.argument<String>("body") ?: "Workout in progress..."
                    val startTimeMillis = call.argument<Long>("startTimeMillis") ?: System.currentTimeMillis()
                    
                    showWorkoutNotification(title, body, startTimeMillis, true)
                    result.success(null)
                }
                "pauseNotification" -> {
                    val title = call.argument<String>("title") ?: "Workout Paused"
                    val body = call.argument<String>("body") ?: "Paused"
                    
                    showWorkoutNotification(title, body, System.currentTimeMillis(), false)
                    result.success(null)
                }
                "stopNotification" -> {
                    cancelWorkoutNotification()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun showWorkoutNotification(title: String, body: String, startTimeMillis: Long, isRunning: Boolean) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Delete old low-importance channel to prevent conflict
            notificationManager.deleteNotificationChannel("workout_live_channel")

            val channel = NotificationChannel(
                CHANNEL_ID,
                "Live Workout Tracking",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Shows real-time ticking workout duration on lockscreen"
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)
        }

        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Using the app's launcher icon to comply with Android notification guidelines
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)

        if (isRunning) {
            builder.setUsesChronometer(true)
            builder.setWhen(startTimeMillis)
        } else {
            builder.setUsesChronometer(false)
        }

        notificationManager.notify(NOTIFICATION_ID, builder.build())
    }

    private fun cancelWorkoutNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
    }
}
