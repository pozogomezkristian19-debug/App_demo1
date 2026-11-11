package com.melliqui.quimica_pura

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
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
        // Ajustes de batería / inicio automático (ronda #6, punto 2):
        // en Xiaomi/MIUI el ahorro de batería y el inicio automático
        // denegado pueden bloquear los avisos aunque el permiso esté
        // dado. Canal "com.melliqui/battery_settings", métodos:
        //  - isIgnoringBatteryOptimizations: ¿está la app exenta de
        //    la optimización de batería? (PowerManager, API 23+)
        //  - openBatteryOptimizationSettings: abre la lista del
        //    sistema con la optimización de batería por app
        //    (abrirla no necesita ningún permiso).
        //  - openAutostartSettings: intenta abrir el "Inicio
        //    automático" de MIUI (intent sin documentar, puede no
        //    existir) y, si no, cae en la pantalla de batería.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.melliqui/battery_settings"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    val ignoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        pm.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    result.success(ignoring)
                }
                "openBatteryOptimizationSettings" -> {
                    try {
                        val intent = Intent(
                            Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                        )
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "openAutostartSettings" -> {
                    try {
                        val intent = Intent().apply {
                            component = ComponentName(
                                "com.miui.securitycenter",
                                "com.miui.permcenter.autostart.AutoStartManagementActivity"
                            )
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(
                                Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                            )
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.success(false)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
