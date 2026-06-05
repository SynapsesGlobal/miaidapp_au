package com.em.bright.miaid

import android.app.*
import android.content.Context
import android.content.Intent
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.util.*

class LocationForegroundService : Service(), LocationListener {

    private val CHANNEL = "com.miaid.location"
    private var lastLocation: Location? = null
    private lateinit var locationManager: LocationManager
    private var timer: Timer? = null

    override fun onCreate() {
        super.onCreate()
        startForegroundService()

        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager

        try {
            locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 60_000L, 10f, this)
            locationManager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 60_000L, 10f, this)
        } catch (ex: SecurityException) {
            Log.e("LocationService", "缺少定位权限")
        }

        timer = Timer()
        timer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                uploadLocation()
            }
        }, 0, 1800* 1000) // 5分钟上传一次，测试时可调大或调小
    }

    private fun startForegroundService() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("location_channel", "后台定位服务", NotificationManager.IMPORTANCE_LOW)
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, "location_channel")
            .setContentTitle("Backend location")
            .setContentText("Uploading backend location information")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .build()

        startForeground(1, notification)
    }

    override fun onLocationChanged(location: Location) {
        Log.d("LocationService", "定位变化: ${location.latitude}, ${location.longitude}")
        lastLocation = location
    }

    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) {}
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

    private fun uploadLocation() {
        lastLocation?.let {
            val engine = FlutterEngineCache.getInstance().get("my_engine")
            if (engine != null) {
                val mainHandler = android.os.Handler(mainLooper)
                mainHandler.post {
                    MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("uploadLocation", mapOf(
                        "lat" to it.latitude,
                        "lng" to it.longitude,
                        "ts" to System.currentTimeMillis() / 1000
                    ))
                }
            }
        } ?: Log.d("LocationService", "无可用定位")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        locationManager.removeUpdates(this)
        timer?.cancel()
        Log.d("LocationService", "Service 销毁")
    }
}
