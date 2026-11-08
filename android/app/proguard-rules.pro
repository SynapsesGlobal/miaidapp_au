# =============================
# CometChat RTC 保留规则
# =============================
-keep class com.cometchat.pro.rtc.** { *; }
-keep class com.cometchat.pro.rtc.model.** { *; }
-keepclassmembers class com.cometchat.pro.rtc.** { *; }

# =============================
# Stripe PushProvisioning 保留规则
# =============================
-keep class com.stripe.android.pushProvisioning.** { *; }
-keepclassmembers class com.stripe.android.pushProvisioning.** { *; }

# =============================
# 保留反射注解
# =============================
-keepattributes *Annotation*

# =============================
# 保留所有类名（可选）
# =============================
-keepnames class com.cometchat.pro.** { *; }
-keepnames class com.stripe.android.** { *; }

-dontwarn com.cometchat.pro.rtc.CometChatRTCView$CometChatRTCViewBuilder
-dontwarn com.cometchat.pro.rtc.CometChatRTCView
-dontwarn com.cometchat.pro.rtc.CometChatRTCViewListener
-dontwarn com.cometchat.pro.rtc.model.AnalyticsSettings
-dontwarn com.cometchat.pro.rtc.model.AudioMode
-dontwarn com.cometchat.pro.rtc.model.CallSwitchRequestInfo
-dontwarn com.cometchat.pro.rtc.model.MainVideoContainerSetting
-dontwarn com.cometchat.pro.rtc.model.RTCCallback
-dontwarn com.cometchat.pro.rtc.model.RTCMutedUser
-dontwarn com.cometchat.pro.rtc.model.RTCReceiver
-dontwarn com.cometchat.pro.rtc.model.RTCRecordingInfo
-dontwarn com.cometchat.pro.rtc.model.RTCUser
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider

-keep class org.bouncycastle.** { *; }
-keepclassmembers class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**
# =============================
# 智能戒指 rwfit_ble 保留规则
# =============================
# 原生 SDK AAR 自带 consumer 规则（保留 bean/callback 等公开面）；桥接层用 fastjson 反射
# 构造 SDK 入参/出参，fastjson 自身没有 consumer 规则，debug 构建开了 minify，这里兜底
-keep class com.rwfit.rwfit_ble.** { *; }
-keep class com.alibaba.fastjson.** { *; }
-dontwarn com.alibaba.fastjson.**
