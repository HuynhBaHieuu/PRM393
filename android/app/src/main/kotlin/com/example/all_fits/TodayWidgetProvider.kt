package com.example.all_fits

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * The "Today" home screen widget: today's outfit, the weather, and one
 * action (mark as worn, save the idea, add clothes).
 *
 * The app works out what to show (see `TodayWidgetSync` in Dart) and saves
 * it through the home_widget plugin; this class only draws it. Taps open
 * the app with an `allfits://widget/...` link the app handles.
 */
class TodayWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, build(context, widgetData))
        }
    }

    private fun build(context: Context, data: SharedPreferences): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.today_widget)
        val state = data.getString("today_state", null)
        val day = data.getString("today_day", null)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

        // Never opened, or the outfit is from an earlier day: the app hasn't
        // run since midnight, so ask the user to open it. The app saves this
        // text in its own language, which can differ from the phone's.
        val current = state == "signedOut" || (state != null && day == today)
        if (!current) {
            views.setTextViewText(R.id.today_heading, data.getString("today_open_heading", null) ?: context.getString(R.string.today_widget_heading))
            views.setTextViewText(R.id.today_title, data.getString("today_open_title", null) ?: context.getString(R.string.today_widget_open))
            views.setViewVisibility(R.id.today_weather, View.GONE)
            views.setViewVisibility(R.id.today_subtitle, View.GONE)
            views.setViewVisibility(R.id.today_action, View.GONE)
            views.setViewVisibility(R.id.today_picture, View.GONE)
            views.setOnClickPendingIntent(R.id.today_root, launch(context, HOME_LINK))
            return views
        }

        views.setTextViewText(R.id.today_heading, data.getString("today_heading", ""))
        views.setTextViewText(R.id.today_title, data.getString("today_title", ""))
        setOptionalText(views, R.id.today_weather, data.getString("today_weather", null))
        setOptionalText(views, R.id.today_subtitle, data.getString("today_subtitle", null))

        val picture = data.getString("today_picture", null)
            ?.let { BitmapFactory.decodeFile(it) }
        if (picture != null) {
            views.setImageViewBitmap(R.id.today_picture, picture)
            views.setViewVisibility(R.id.today_picture, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.today_picture, View.GONE)
        }

        val action = data.getString("today_action", null)
        val actionLink = data.getString("today_action_link", null)
        if (action != null && actionLink != null) {
            views.setTextViewText(R.id.today_action, action)
            views.setViewVisibility(R.id.today_action, View.VISIBLE)
            views.setOnClickPendingIntent(R.id.today_action, launch(context, actionLink))
        } else {
            views.setViewVisibility(R.id.today_action, View.GONE)
        }

        val openLink = data.getString("today_open_link", null) ?: HOME_LINK
        views.setOnClickPendingIntent(R.id.today_root, launch(context, openLink))
        return views
    }

    private fun setOptionalText(views: RemoteViews, id: Int, text: String?) {
        if (text.isNullOrEmpty()) {
            views.setViewVisibility(id, View.GONE)
        } else {
            views.setTextViewText(id, text)
            views.setViewVisibility(id, View.VISIBLE)
        }
    }

    /** Opens the app with [link]; distinct links get distinct intents. */
    private fun launch(context: Context, link: String) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(link))

    private companion object {
        const val HOME_LINK = "allfits://widget/home"
    }
}
