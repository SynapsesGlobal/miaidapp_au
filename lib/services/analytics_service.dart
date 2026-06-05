/*
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService{
   final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

   FirebaseAnalyticsObserver getAnalyticsObserver() => FirebaseAnalyticsObserver(analytics: _analytics);
}*/


import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
   final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

   // 获取 FirebaseAnalyticsObserver
   FirebaseAnalyticsObserver getAnalyticsObserver() {
      return FirebaseAnalyticsObserver(analytics: _analytics);
   }

   // 跟踪事件
   Future<void> trackEvent(String name) async {
      await _analytics.logEvent(name: name);
   }
}
