// Versión de la app (antes en update_check.dart): se sacó a su
// propio archivo para que la vista previa web del inicio pueda
// leerla sin importar update_check.dart, que usa dart:io (HttpClient
// y archivos del APK) y no compila en web. update_check.dart la
// re-exporta, así que nada cambia para quien la importaba de ahí.
///
/// Versión actual: ÚNICA fuente de verdad en el código. Debe
/// coincidir con `latest` de version.json en la build que se
/// publica, para que no salga un aviso falso nada más instalar.
const String kAppVersion = '7.7';

/// Versión PÚBLICA que se enseña dentro de la app (Quemia 7.3):
/// lo que ve Kristian es 1.0; la 7.3 es solo el número interno de
/// las pruebas (kAppVersion + version.json). El comprobador de
/// actualizaciones compara SIEMPRE kAppVersion (interna), nunca
/// esta: cambiar la pública no afecta a las actualizaciones.
const String kDisplayVersion = '1.0';
