class Consts {
  // marketing / chatbot 的 host 和 key 按环境区分，已移入 ApiSettings
  //（lib/config/api_settings.dart），通过 getIt<ApiSettings>() 获取。
  static String AIVideoConsultation = 'mcp_video_consultation';
  static String AIBookHospitals = 'mcp_appoint_hospital';
  static String AIAppointInterpreter = 'mcp_appoint_interpreter';
  static String AINotifyFamilyOrCompany = 'LEVEL4';

  static String QrCodeToken='AhKTMk9D9ydtUgGqRRE8lBRbanVqX10zMAtv';
  static String CheckInQrcode='checkin';
  static String RedemptionQrcode='redemption';

  static String MiSpaceAirLine='SERKO_SERVICE';
}