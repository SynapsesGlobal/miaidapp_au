package com.em.bright.miaid

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterFragmentActivity

import android.os.Build
import android.view.ViewTreeObserver
import android.view.WindowManager

class MainActivity: FlutterFragmentActivity() {
}

/*import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.miaid.location"
    private val REQ_CODE_FINE_LOCATION = 1001
    private val REQ_CODE_BACKGROUND_LOCATION = 1002

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterEngineCache.getInstance().put("my_engine", flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLocationService" -> {
                    if (checkFineLocationPermission()) {
                        requestBackgroundLocationPermissionIfNeeded(result)
                    } else {
                        requestFineLocationPermission(result)
                    }
                }
                "stopLocationService" -> {
                    stopLocationService()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun checkFineLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun checkBackgroundLocationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
        } else true
    }

    private var pendingResult: MethodChannel.Result? = null

    private fun requestFineLocationPermission(result: MethodChannel.Result) {
        pendingResult = result
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.ACCESS_FINE_LOCATION), REQ_CODE_FINE_LOCATION)
    }

    private fun requestBackgroundLocationPermissionIfNeeded(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !checkBackgroundLocationPermission()) {
            pendingResult = result
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), REQ_CODE_BACKGROUND_LOCATION)
        } else {
            startLocationService()
            result.success(null)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        when (requestCode) {
            REQ_CODE_FINE_LOCATION -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    // 请求后台权限
                    requestBackgroundLocationPermissionIfNeeded(pendingResult ?: return)
                } else {
                    pendingResult?.error("PERMISSION_DENIED", "前台定位权限被拒绝", null)
                }
                pendingResult = null
            }
            REQ_CODE_BACKGROUND_LOCATION -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    startLocationService()
                    pendingResult?.success(null)
                } else {
                    pendingResult?.error("PERMISSION_DENIED", "后台定位权限被拒绝", null)
                }
                pendingResult = null
            }
            else -> super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    private fun startLocationService() {
        val intent = Intent(this, LocationForegroundService::class.java)
        ContextCompat.startForegroundService(this, intent)
    }

    private fun stopLocationService() {
        val intent = Intent(this, LocationForegroundService::class.java)
        stopService(intent)
    }
}*/

