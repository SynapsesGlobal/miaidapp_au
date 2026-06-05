package com.em.bright.miaid

import io.flutter.app.FlutterApplication
import io.flutter.plugin.common.PluginRegistry
//import com.huawei.hms.flutter.push.PushPlugin;

class MainApplication : FlutterApplication(), PluginRegistry.PluginRegistrantCallback {

    override fun onCreate() {
        super.onCreate()
//        PushPlugin.setPluginRegistrant(this)
    }

    override fun
            registerWith(registry: PluginRegistry) {
//        if (!registry!!.hasPlugin("com.huawei.hms.flutter.push.PushPlugin")) {
//            PushPlugin.registerWith(registry?.registrarFor("com.huawei.hms.flutter.push.PushPlugin"))
//        }
    }
}
