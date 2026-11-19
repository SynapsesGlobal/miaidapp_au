package com.em.bright.miaid

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * 智能戒指后台同步的前台服务。
 *
 * 本身不做任何事，只挂一条常驻通知，让进程在 App 退到后台后不被系统回收；
 * 主 isolate 里的 SmartRingService / RingCloudSync 由此得以继续保持蓝牙连接、定时同步并上传。
 * 由 Dart 侧（RingKeepAlive）在绑定戒指后启动、解绑后停止。
 */
class RingSyncService : Service() {

    companion object {
        const val CHANNEL_ID = "ring_sync"
        const val NOTIFICATION_ID = 7301
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_CHANNEL_NAME = "channel_name"

        @Volatile
        var running = false
            private set

        fun start(context: Context, title: String, text: String, channelName: String) {
            val intent = Intent(context, RingSyncService::class.java)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_TEXT, text)
                .putExtra(EXTRA_CHANNEL_NAME, channelName)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, RingSyncService::class.java))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "MiAid"
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: ""
        ensureChannel(intent?.getStringExtra(EXTRA_CHANNEL_NAME) ?: title)
        val notification = buildNotification(title, text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        running = true
        // 被系统杀掉后重建；Dart 侧回到前台会再次按绑定状态校正
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    private fun ensureChannel(name: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_LOW).apply {
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(title: String, text: String): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        val pending = launch?.let { PendingIntent.getActivity(this, 0, it, flags) }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .apply { if (pending != null) setContentIntent(pending) }
            .build()
    }
}
