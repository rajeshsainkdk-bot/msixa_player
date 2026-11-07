package com.msixa.player

import android.content.Intent
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "com.msixa.player/app_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "shareApk") {
                try {
                    val appInfo = applicationContext.applicationInfo
                    val srcApk = File(appInfo.sourceDir)
                    val destApk = File(cacheDir, "MsixaPlayer.apk")
                    FileInputStream(srcApk).use { input ->
                        FileOutputStream(destApk).use { output ->
                            input.copyTo(output)
                        }
                    }

                    val apkUri = FileProvider.getUriForFile(
                        this,
                        "${applicationContext.packageName}.fileprovider",
                        destApk
                    )

                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "application/vnd.android.package-archive"
                        putExtra(Intent.EXTRA_STREAM, apkUri)
                        putExtra(Intent.EXTRA_SUBJECT, "Msixa Player APK")
                        putExtra(Intent.EXTRA_TEXT, "Download & Install Msixa Player - Enjoy 100% Free Indian Music & Offline Player!")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }

                    startActivity(Intent.createChooser(intent, "Share Msixa Player APK"))
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SHARE_ERROR", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
