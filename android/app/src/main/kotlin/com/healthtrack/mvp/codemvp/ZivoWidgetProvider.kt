package com.healthtrack.mvp.codemvp

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class ZivoWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == "com.healthtrack.mvp.codemvp.ACTION_ADD_WATER") {
            // Read from Shared Preferences
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val currentWater = prefs.getInt("water_logged", 0)
            val currentSync = prefs.getInt("water_to_sync", 0)
            
            val updatedWater = currentWater + 250
            val updatedSync = currentSync + 250
            
            // Save back
            prefs.edit()
                .putInt("water_logged", updatedWater)
                .putInt("water_to_sync", updatedSync)
                .apply()
                
            // Trigger update to refresh layout immediately
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, ZivoWidgetProvider::class.java)
            val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (widgetId in allWidgetIds) {
                updateAppWidget(context, appWidgetManager, widgetId)
            }
        }
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.zivo_widget_layout)

            // Read preferences updated by Flutter
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val streak = prefs.getInt("streak", 0)
            val calories = prefs.getInt("calories_logged", 0)
            val calorieGoal = prefs.getInt("calorie_goal", 2200)
            val water = prefs.getInt("water_logged", 0)
            val waterGoal = prefs.getInt("water_goal", 3000)
            val workoutActive = prefs.getBoolean("workout_active", false)
            val workoutTimer = prefs.getString("workout_timer", "")

            // Populate layout views
            views.setTextViewText(R.id.widget_streak, "🔥 $streak days")
            views.setTextViewText(R.id.widget_calories, "$calories / $calorieGoal kcal")
            views.setTextViewText(R.id.widget_water, "💧 Water logged: $water / $waterGoal ml")

            if (workoutActive && !workoutTimer.isNullOrEmpty()) {
                views.setTextViewText(R.id.widget_title, "ZIVO: GYM LIVE")
            } else {
                views.setTextViewText(R.id.widget_title, "ZIVOFIT")
            }

            // Calculate progress bar percentage
            val progress = if (calorieGoal > 0) {
                (calories.toFloat() / calorieGoal.toFloat() * 100).toInt()
            } else {
                0
            }
            views.setProgressBar(R.id.widget_calorie_progress, 100, progress, false)

            // 1. Setup "+250ml Water" background receiver click
            val waterIntent = Intent(context, ZivoWidgetProvider::class.java).apply {
                action = "com.healthtrack.mvp.codemvp.ACTION_ADD_WATER"
            }
            val pendingWater = PendingIntent.getBroadcast(
                context,
                1,
                waterIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_add_water, pendingWater)

            // 2. Setup "Open Zivo" main app click
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
            val pendingOpen = PendingIntent.getActivity(
                context,
                0,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_open_app, pendingOpen)
            views.setOnClickPendingIntent(R.id.widget_title, pendingOpen)

            if (workoutActive && !workoutTimer.isNullOrEmpty()) {
                views.setTextViewText(R.id.btn_open_app, "Active: $workoutTimer")
            } else {
                views.setTextViewText(R.id.btn_open_app, "Open Zivo")
            }

            // Instruct the widget manager to update the widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
