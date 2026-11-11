package com.melliqui.quimica_pura

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    // Instalador de actualizaciones (fix3, punto 20): la app descarga
    // el APK desde GitHub (no está en Google Play) y pide instalarlo
    // con el instalador del sistema. Canal "com.melliqui/
    // update_installer", métodos:
    //  - canInstallUnknownSources: ¿tiene Melli-Qui activado
    //    "Instalar apps desconocidas"? (Android 8+; antes, siempre sí)
    //  - installApk(path): abre el instalador del sistema con el APK
    //    (FileProvider, autoridad <applicationId>.fileprovider).
    //  - openUnknownSourcesSettings: abre los ajustes del sistema en
    //    "Instalar apps desconocidas" para Melli-Qui.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.melliqui/update_installer"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstallUnknownSources" -> {
                    val can = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else {
                        true
                    }
                    result.success(can)
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val file = File(path)
                    if (!file.exists()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = FileProvider.getUriForFile(
                            this, "$packageName.fileprovider", file
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "openUnknownSourcesSettings" -> {
                    try {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName")
                        )
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
