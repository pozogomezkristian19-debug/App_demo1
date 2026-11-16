// Respaldo sin web de otp_web_fetch.dart: en el móvil no existe el
// fetch del navegador. Nunca se llama, porque sendCode solo usa
// postOtpNoFollow en web (kIsWeb).
Future<bool> postOtpNoFollow(String url, String body) =>
    throw UnsupportedError('postOtpNoFollow solo existe en web');
