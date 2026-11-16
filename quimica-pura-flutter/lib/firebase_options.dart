// Configuración web de Firebase (Quemia 2026-11-15): la app web
// "Quemia web" del proyecto quemia-8410a. Generada desde
// `firebase apps:sdkconfig` (la clave es pública: identifica el
// proyecto, como la de google-services.json; la seguridad la ponen
// las reglas de Firestore/Auth, no la clave). SOLO web: el móvil
// sigue usando google-services.json (main.dart llama a
// Firebase.initializeApp() sin opciones en Android).
library;

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC5CYUkTWajjfBO-DOqKedxEUKJqSKlkeI',
    appId: '1:898001909401:web:5915ce834cc01b7a076a08',
    messagingSenderId: '898001909401',
    projectId: 'quemia-8410a',
    authDomain: 'quemia-8410a.firebaseapp.com',
    storageBucket: 'quemia-8410a.firebasestorage.app',
  );
}
