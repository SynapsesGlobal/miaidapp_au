### 登录时获取设备的token不稳定的问题：
- lib/notifications/notifications_token_provider.dart — token 由 late final 改成普通可写 String，并新增 ensurePushToken() 工具函数（处理 iOS APNS
  轮询、权限校验、失败日志）。
- lib/view/user/sign_in/sign_in.dart:533-541 — 把原来那段 try/catch 替换成 await ensurePushToken(tokenProvider)；print 改成
  debugPrint；顺带移除了不再用到的 firebase_messaging import。
