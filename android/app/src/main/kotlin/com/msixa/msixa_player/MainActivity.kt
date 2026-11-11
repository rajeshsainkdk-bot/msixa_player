package com.msixa.msixa_player

import android.content.Context
import android.content.Intent
import android.content.ContentUris
import android.net.Uri
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.MediaStore
import android.view.WindowManager
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "com.msixa.player/app_share"
    private var wakeLock: PowerManager.WakeLock? = null
    private var initialMediaUri: String? = null
    private var initialMediaMime: String? = null
    private var initialMediaName: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIncomingIntent(intent)
    }

    private fun handleIncomingIntent(inIntent: Intent?) {
        if (inIntent == null) return
        val action = inIntent.action
        val data: Uri? = inIntent.data
        if (Intent.ACTION_VIEW == action && data != null) {
            initialMediaUri = data.toString()
            initialMediaMime = inIntent.type ?: contentResolver.getType(data)
            initialMediaName = data.lastPathSegment ?: "Media File"
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ctx: Context = applicationContext

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "keepScreenOn" -> {
                    val enable = call.argument<Boolean>("enable") ?: true
                    runOnUiThread {
                        if (enable) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                    }
                    result.success(true)
                }
                "setScreenBrightness" -> {
                    val brightness = call.argument<Double>("brightness")?.toFloat() ?: -1.0f
                    runOnUiThread {
                        val lp = window.attributes
                        lp.screenBrightness = brightness.coerceIn(0.01f, 1.0f)
                        window.attributes = lp
                    }
                    result.success(true)
                }
                "getScreenBrightness" -> {
                    val brightness = window.attributes.screenBrightness
                    result.success(if (brightness < 0) 0.5 else brightness.toDouble())
                }
                "setDeviceVolume" -> {
                    try {
                        val volumePercent = call.argument<Double>("volume") ?: 0.5
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                        val maxVol = audioManager.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC)
                        val targetVol = (volumePercent * maxVol).toInt().coerceIn(0, maxVol)
                        audioManager.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, targetVol, 0)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("VOL_ERROR", e.message, null)
                    }
                }
                "getDeviceVolume" -> {
                    try {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                        val maxVol = audioManager.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC)
                        val curVol = audioManager.getStreamVolume(android.media.AudioManager.STREAM_MUSIC)
                        result.success(if (maxVol > 0) curVol.toDouble() / maxVol.toDouble() else 0.5)
                    } catch (e: Exception) {
                        result.success(0.5)
                    }
                }
                "enterPipMode" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val params = android.app.PictureInPictureParams.Builder()
                                .setAspectRatio(android.util.Rational(16, 9))
                                .build()
                            enterPictureInPictureMode(params)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "getInitialMediaUri" -> {
                    if (initialMediaUri != null) {
                        val uriStr = initialMediaUri ?: ""
                        val mime = initialMediaMime ?: ""
                        val isVideo = mime.startsWith("video") ||
                                uriStr.endsWith(".mp4", ignoreCase = true) ||
                                uriStr.endsWith(".mkv", ignoreCase = true) ||
                                uriStr.endsWith(".webm", ignoreCase = true) ||
                                uriStr.endsWith(".3gp", ignoreCase = true) ||
                                uriStr.endsWith(".avi", ignoreCase = true)
                        val isAudio = mime.startsWith("audio") ||
                                uriStr.endsWith(".mp3", ignoreCase = true) ||
                                uriStr.endsWith(".m4a", ignoreCase = true) ||
                                uriStr.endsWith(".wav", ignoreCase = true) ||
                                uriStr.endsWith(".aac", ignoreCase = true) ||
                                uriStr.endsWith(".flac", ignoreCase = true)

                        val map = mapOf(
                            "uri" to uriStr,
                            "mimeType" to mime,
                            "displayName" to (initialMediaName ?: "Media File"),
                            "isVideo" to isVideo,
                            "isAudio" to isAudio
                        )
                        initialMediaUri = null
                        result.success(map)
                    } else {
                        result.success(null)
                    }
                }
                "queryDeviceVideos" -> {
                    try {
                        val videoList = mutableListOf<Map<String, Any?>>()
                        val projection = arrayOf(
                            MediaStore.Video.Media._ID,
                            MediaStore.Video.Media.TITLE,
                            MediaStore.Video.Media.DISPLAY_NAME,
                            MediaStore.Video.Media.DATA,
                            MediaStore.Video.Media.DURATION,
                            MediaStore.Video.Media.SIZE,
                            MediaStore.Video.Media.RESOLUTION,
                            MediaStore.Video.Media.BUCKET_DISPLAY_NAME,
                            MediaStore.Video.Media.DATE_ADDED
                        )
                        val uri = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                        val cursor = ctx.contentResolver.query(
                            uri,
                            projection,
                            null,
                            null,
                            "${MediaStore.Video.Media.DATE_ADDED} DESC"
                        )
                        cursor?.use { c ->
                            val idCol = c.getColumnIndex(MediaStore.Video.Media._ID)
                            val titleCol = c.getColumnIndex(MediaStore.Video.Media.TITLE)
                            val nameCol = c.getColumnIndex(MediaStore.Video.Media.DISPLAY_NAME)
                            val pathCol = c.getColumnIndex(MediaStore.Video.Media.DATA)
                            val durCol = c.getColumnIndex(MediaStore.Video.Media.DURATION)
                            val sizeCol = c.getColumnIndex(MediaStore.Video.Media.SIZE)
                            val resCol = c.getColumnIndex(MediaStore.Video.Media.RESOLUTION)
                            val bucketCol = c.getColumnIndex(MediaStore.Video.Media.BUCKET_DISPLAY_NAME)
                            val dateCol = c.getColumnIndex(MediaStore.Video.Media.DATE_ADDED)

                            while (c.moveToNext()) {
                                val id = if (idCol != -1) c.getLong(idCol) else 0L
                                val title = if (titleCol != -1) c.getString(titleCol) else null
                                val name = if (nameCol != -1) c.getString(nameCol) else null
                                val path = if (pathCol != -1) c.getString(pathCol) else ""
                                val duration = if (durCol != -1) c.getLong(durCol) else 0L
                                val size = if (sizeCol != -1) c.getLong(sizeCol) else 0L
                                val resolution = if (resCol != -1) c.getString(resCol) else null
                                val folder = if (bucketCol != -1) c.getString(bucketCol) else null
                                val dateAdded = if (dateCol != -1) c.getLong(dateCol) else 0L

                                val item = mutableMapOf<String, Any?>()
                                item["id"] = id.toString()
                                item["title"] = title ?: name ?: "Video"
                                item["displayName"] = name ?: "Video"
                                item["path"] = path ?: ""
                                item["duration"] = duration
                                item["size"] = size
                                item["resolution"] = resolution ?: "HD"
                                item["folder"] = folder ?: "Videos"
                                item["dateAdded"] = dateAdded
                                videoList.add(item)
                            }
                        }
                        result.success(videoList)
                    } catch (e: Exception) {
                        result.error("VIDEO_QUERY_ERR", e.localizedMessage, null)
                    }
                }
                "openVideoWithApp" -> {
                    try {
                        val path = call.argument<String>("path") ?: ""
                        val idStr = call.argument<String>("id")
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            if (!idStr.isNullOrEmpty() && idStr.toLongOrNull() != null) {
                                val u = ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, idStr.toLong())
                                setDataAndType(u, "video/*")
                            } else {
                                setDataAndType(Uri.parse(path), "video/*")
                            }
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        val chooser = Intent.createChooser(intent, "Play Video With").apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        ctx.startActivity(chooser)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_VIDEO_ERR", e.localizedMessage, null)
                    }
                }
                "acquireWakeLock" -> {
                    try {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                        if (wakeLock == null) {
                            wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Msixa:BulkUploadWakeLock")
                        }
                        if (wakeLock?.isHeld != true) {
                            wakeLock?.acquire(45 * 60 * 1000L)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WAKELOCK_ERR", e.localizedMessage, null)
                    }
                }
                "releaseWakeLock" -> {
                    try {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        if (wakeLock?.isHeld == true) {
                            wakeLock?.release()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WAKELOCK_RELEASE_ERR", e.localizedMessage, null)
                    }
                }
                "showUploadNotification" -> {
                    try {
                        val title = call.argument<String>("title") ?: "Msixa Bulk Upload"
                        val message = call.argument<String>("message") ?: "Upload Completed!"
                        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        val channelId = "msixa_upload_channel"
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val channel = NotificationChannel(
                                channelId,
                                "Msixa Upload Status",
                                NotificationManager.IMPORTANCE_HIGH
                            )
                            notificationManager.createNotificationChannel(channel)
                        }
                        val builder = androidx.core.app.NotificationCompat.Builder(this, channelId)
                            .setSmallIcon(android.R.drawable.stat_sys_upload_done)
                            .setContentTitle(title)
                            .setContentText(message)
                            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_HIGH)
                            .setAutoCancel(true)
                        notificationManager.notify(101, builder.build())
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NOTIF_ERR", e.localizedMessage, null)
                    }
                }
                "shareApk" -> {
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
                            putExtra(Intent.EXTRA_TEXT, "Download & Install Msixa Player - Enjoy 100% Free Indian Music & HD Video Player!")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(Intent.createChooser(intent, "Share Msixa Player APK"))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.localizedMessage, null)
                    }
                }
                "installApk" -> {
                    try {
                        val filePath = call.argument<String>("filePath") ?: throw IllegalArgumentException("filePath required")
                        val file = File(filePath)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            if (!packageManager.canRequestPackageInstalls()) {
                                val permIntent = Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                    data = Uri.parse("package:$packageName")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(permIntent)
                                result.error("NEED_PERMISSION", "Please allow installing apps from Msixa Player in Settings", null)
                                return@setMethodCallHandler
                            }
                        }
                        val apkUri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.localizedMessage, null)
                    }
                }
                "getAppVersion" -> {
                    try {
                        val pInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            packageManager.getPackageInfo(packageName, 0).longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageInfo(packageName, 0).versionCode.toLong()
                        }
                        val versionName = packageManager.getPackageInfo(packageName, 0).versionName ?: "1.0.0"
                        result.success(mapOf(
                            "versionCode" to pInfo,
                            "versionName" to versionName
                        ))
                    } catch (e: Exception) {
                        result.error("VERSION_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
