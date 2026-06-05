package com.em.bright.miaid

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        Log.d("BootReceiver", "设备重启广播接收")
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED && context != null) {
            val svcIntent = Intent(context, LocationForegroundService::class.java)
            ContextCompat.startForegroundService(context, svcIntent)
        }
    }
}
