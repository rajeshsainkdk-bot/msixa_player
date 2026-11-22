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
import android.media.MediaPlayer
import android.media.MediaExtractor
import android.media.MediaFormat
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
    private var syncAudioPlayer: MediaPlayer? = null
    private var isVideoPlaying = false
    private var appShareChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        resetBrightnessToDefault()
        handleIncomingIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        if (!isVideoPlaying) {
            resetBrightnessToDefault()
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && !isVideoPlaying) {
            resetBrightnessToDefault()
        }
    }

    private fun resetBrightnessToDefault() {
        runOnUiThread {
            try {
                val lp = window.attributes
                lp.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                window.attributes = lp
            } catch (_: Exception) {}
        }
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

        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        appShareChannel = ch
        ch.setMethodCallHandler { call, result ->
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
                        if (brightness < 0) {
                            isVideoPlaying = false
                            lp.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                        } else {
                            isVideoPlaying = true
                            lp.screenBrightness = brightness.coerceIn(0.01f, 1.0f)
                        }
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
                                var duration = if (durCol != -1) c.getLong(durCol) else 0L
                                val size = if (sizeCol != -1) c.getLong(sizeCol) else 0L
                                val resolution = if (resCol != -1) c.getString(resCol) else null
                                val folder = if (bucketCol != -1) c.getString(bucketCol) else null
                                val dateAdded = if (dateCol != -1) c.getLong(dateCol) else 0L

                                // Fallback duration retrieval for movies/MKVs if MediaStore reports 0 duration
                                if (duration <= 0L && path.isNotEmpty()) {
                                    try {
                                        val mmr = MediaMetadataRetriever()
                                        mmr.setDataSource(path)
                                        val durStr = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                                        duration = durStr?.toLongOrNull() ?: 0L
                                        mmr.release()
                                    } catch (_: Throwable) {}
                                }

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
                    // Strictly pure in-app playback: external applications disabled as per user instruction
                    result.success(true)
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
                "shareToWhatsAppStatus" -> {
                    try {
                        val videoPath = call.argument<String>("videoPath") ?: ""
                        val videoFile = File(videoPath)
                        if (!videoFile.exists()) {
                            result.error("FILE_NOT_FOUND", "Video file not found at $videoPath", null)
                            return@setMethodCallHandler
                        }
                        val videoUri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            videoFile
                        )
                        val pm = packageManager
                        var targetPkg = "com.whatsapp"
                        var isInstalled = try {
                            pm.getPackageInfo("com.whatsapp", 0)
                            true
                        } catch (_: Exception) {
                            false
                        }
                        if (!isInstalled) {
                            isInstalled = try {
                                pm.getPackageInfo("com.whatsapp.w4b", 0)
                                targetPkg = "com.whatsapp.w4b"
                                true
                            } catch (_: Exception) {
                                false
                            }
                        }

                        if (isInstalled) {
                            val waIntent = Intent(Intent.ACTION_SEND).apply {
                                type = "video/*"
                                setPackage(targetPkg)
                                putExtra(Intent.EXTRA_STREAM, videoUri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(waIntent)
                            result.success(true)
                        } else {
                            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                                type = "video/*"
                                putExtra(Intent.EXTRA_STREAM, videoUri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(shareIntent, "Share Video Status"))
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("STATUS_SHARE_ERR", e.localizedMessage, null)
                    }
                }
                "scanMediaFile" -> {
                    try {
                        val path = call.argument<String>("path") ?: ""
                        if (path.isNotEmpty()) {
                            android.media.MediaScannerConnection.scanFile(
                                applicationContext,
                                arrayOf(path),
                                arrayOf("video/mp4"),
                                null
                            )
                        }
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                "captureVideoScreenshot" -> {
                    try {
                        val path = call.argument<String>("path") ?: ""
                        val posMs = call.argument<Int>("positionMs") ?: 0
                        val retriever = android.media.MediaMetadataRetriever()
                        if (path.startsWith("http://") || path.startsWith("https://")) {
                            retriever.setDataSource(path, HashMap<String, String>())
                        } else {
                            retriever.setDataSource(path)
                        }
                        val timeMicros = posMs.toLong() * 1000L
                        val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                            retriever.getScaledFrameAtTime(timeMicros, android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC, 1280, 720) 
                                ?: retriever.getFrameAtTime(timeMicros)
                        } else {
                            retriever.getFrameAtTime(timeMicros)
                        }
                        retriever.release()

                        if (bitmap != null) {
                            val picturesDir = android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_PICTURES)
                            val appDir = java.io.File(picturesDir, "Msixa_Screenshots")
                            if (!appDir.exists()) appDir.mkdirs()
                            val fileName = "Screenshot_${System.currentTimeMillis()}.jpg"
                            val file = java.io.File(appDir, fileName)
                            val fos = java.io.FileOutputStream(file)
                            bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 92, fos)
                            fos.flush()
                            fos.close()

                            android.media.MediaScannerConnection.scanFile(
                                applicationContext,
                                arrayOf(file.absolutePath),
                                arrayOf("image/jpeg"),
                                null
                            )

                            result.success(mapOf("success" to true, "path" to file.absolutePath))
                        } else {
                            result.success(mapOf("success" to false, "error" to "Frame extraction failed"))
                        }
                    } catch (e: Exception) {
                        result.error("SCREENSHOT_ERROR", e.localizedMessage, null)
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
                "getVideoThumbnail" -> {
                    val path = call.argument<String>("path") ?: ""
                    val idStr = call.argument<String>("id")
                    val id = idStr?.toLongOrNull()

                    Thread {
                        try {
                            var bitmap: android.graphics.Bitmap? = null

                            // 1. Android Q+ (API 29+) MediaStore thumbnail
                            if (id != null && id > 0 && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                try {
                                    val contentUri = ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id)
                                    bitmap = contentResolver.loadThumbnail(contentUri, android.util.Size(320, 240), null)
                                } catch (_: Throwable) {}
                            }

                            // 2. MediaMetadataRetriever (universal for any file path, mp4, mkv, avi, webm, etc.)
                            if (bitmap == null && path.isNotEmpty()) {
                                val retriever = android.media.MediaMetadataRetriever()
                                try {
                                    if (path.startsWith("content://")) {
                                        retriever.setDataSource(applicationContext, Uri.parse(path))
                                    } else {
                                        retriever.setDataSource(path)
                                    }
                                    bitmap = retriever.getFrameAtTime(1000000, android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                                        ?: retriever.frameAtTime
                                } catch (_: Throwable) {
                                } finally {
                                    try { retriever.release() } catch (_: Throwable) {}
                                }
                            }

                            // 3. Fallback for older Android (ThumbnailUtils)
                            if (bitmap == null && path.isNotEmpty() && !path.startsWith("content://")) {
                                try {
                                    @Suppress("DEPRECATION")
                                    bitmap = android.media.ThumbnailUtils.createVideoThumbnail(
                                        path,
                                        MediaStore.Images.Thumbnails.MINI_KIND
                                    )
                                } catch (_: Throwable) {}
                            }

                            val bmp = bitmap
                            if (bmp != null) {
                                val stream = java.io.ByteArrayOutputStream()
                                bmp.compress(android.graphics.Bitmap.CompressFormat.JPEG, 75, stream)
                                val bytes = stream.toByteArray()
                                bmp.recycle()
                                runOnUiThread { result.success(bytes) }
                            } else {
                                runOnUiThread { result.success(null) }
                            }
                        } catch (_: Throwable) {
                            runOnUiThread { result.success(null) }
                        }
                    }.start()
                }
                "captureVideoScreenshot" -> {
                    val path = call.argument<String>("path") ?: ""
                    val positionMs = (call.argument<Number>("positionMs"))?.toLong() ?: 0L
                    Thread {
                        try {
                            var bitmap: android.graphics.Bitmap? = null
                            if (path.isNotEmpty()) {
                                val retriever = android.media.MediaMetadataRetriever()
                                try {
                                    if (path.startsWith("content://")) {
                                        retriever.setDataSource(applicationContext, Uri.parse(path))
                                    } else {
                                        retriever.setDataSource(path)
                                    }
                                    val timeUs = positionMs * 1000L
                                    bitmap = retriever.getFrameAtTime(timeUs, android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                                        ?: retriever.getFrameAtTime(timeUs)
                                } catch (_: Throwable) {
                                } finally {
                                    try { retriever.release() } catch (_: Throwable) {}
                                }
                            }

                            if (bitmap != null) {
                                val fileName = "Msixa_${System.currentTimeMillis()}.jpg"
                                var saved = false
                                var savedPath = ""

                                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                                    val values = android.content.ContentValues().apply {
                                        put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                                        put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                                        put(MediaStore.Images.Media.RELATIVE_PATH, android.os.Environment.DIRECTORY_PICTURES + "/Msixa")
                                        put(MediaStore.Images.Media.IS_PENDING, 1)
                                    }
                                    val uri = applicationContext.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                                    if (uri != null) {
                                        applicationContext.contentResolver.openOutputStream(uri)?.use { out ->
                                            bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 95, out)
                                        }
                                        values.clear()
                                        values.put(MediaStore.Images.Media.IS_PENDING, 0)
                                        applicationContext.contentResolver.update(uri, values, null, null)
                                        saved = true
                                        savedPath = "Pictures/Msixa/$fileName"
                                    }
                                } else {
                                    @Suppress("DEPRECATION")
                                    val dir = java.io.File(android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_PICTURES), "Msixa")
                                    if (!dir.exists()) dir.mkdirs()
                                    val file = java.io.File(dir, fileName)
                                    java.io.FileOutputStream(file).use { out ->
                                        bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 95, out)
                                    }
                                    android.media.MediaScannerConnection.scanFile(applicationContext, arrayOf(file.absolutePath), arrayOf("image/jpeg"), null)
                                    saved = true
                                    savedPath = file.absolutePath
                                }
                                bitmap.recycle()
                                runOnUiThread { result.success(mapOf("success" to saved, "path" to savedPath)) }
                            } else {
                                runOnUiThread { result.success(mapOf("success" to false)) }
                            }
                        } catch (e: Throwable) {
                            runOnUiThread { result.success(mapOf("success" to false, "error" to e.localizedMessage)) }
                        }
                    }.start()
                }
                "getVideoAudioTracks" -> {
                    val path = call.argument<String>("path") ?: ""
                    Thread {
                        val trackList = mutableListOf<Map<String, Any?>>()
                        if (path.isNotEmpty()) {
                            val extractor = MediaExtractor()
                            try {
                                if (path.startsWith("content://")) {
                                    extractor.setDataSource(applicationContext, Uri.parse(path), null)
                                } else {
                                    extractor.setDataSource(path)
                                }
                                val count = extractor.trackCount
                                var audioIdx = 0
                                for (i in 0 until count) {
                                    val format = extractor.getTrackFormat(i)
                                    val mime = if (format.containsKey(MediaFormat.KEY_MIME)) format.getString(MediaFormat.KEY_MIME) else ""
                                    if (mime?.startsWith("audio/") == true) {
                                        val lang = if (format.containsKey(MediaFormat.KEY_LANGUAGE)) format.getString(MediaFormat.KEY_LANGUAGE) else "und"
                                        val channels = if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) format.getInteger(MediaFormat.KEY_CHANNEL_COUNT) else 2
                                        val sampleRate = if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) format.getInteger(MediaFormat.KEY_SAMPLE_RATE) else 44100
                                        val title = if (format.containsKey("title")) (try { format.getString("title") } catch (_: Throwable) { null }) ?: "" else ""

                                        val isDolby = mime.contains("eac3") || mime.contains("ac3") || mime.contains("dts")
                                        val channelLabel = when (channels) {
                                            6 -> "5.1 Surround"
                                            8 -> "7.1 Surround"
                                            1 -> "Mono"
                                            else -> "Stereo 2.0"
                                        }
                                        val langName = when (lang?.lowercase()) {
                                            "hin" -> "Hindi"
                                            "eng" -> "English"
                                            "tam" -> "Tamil"
                                            "tel" -> "Telugu"
                                            "mal" -> "Malayalam"
                                            "kan" -> "Kannada"
                                            "pan" -> "Punjabi"
                                            "ben" -> "Bengali"
                                            "mar" -> "Marathi"
                                            "guj" -> "Gujarati"
                                            "spa" -> "Spanish"
                                            "fra" -> "French"
                                            "deu", "ger" -> "German"
                                            "und", "", null -> if (title.isNotEmpty()) title else "Track ${audioIdx + 1}"
                                            else -> lang?.uppercase() ?: "Track ${audioIdx + 1}"
                                        }

                                        val codecLabel = when {
                                            mime.contains("eac3") -> "Dolby Digital Plus (E-AC3)"
                                            mime.contains("ac3") -> "Dolby Digital (AC-3)"
                                            mime.contains("mp4a") || mime.contains("aac") -> "AAC"
                                            mime.contains("opus") -> "Opus"
                                            mime.contains("vorbis") -> "Vorbis"
                                            mime.contains("dts") -> "DTS Surround"
                                            mime.contains("flac") -> "FLAC"
                                            else -> mime.replace("audio/", "").uppercase()
                                        }

                                        val displayName = if (title.isNotEmpty()) {
                                            "$title ($codecLabel, $channelLabel)"
                                        } else {
                                            "Track ${audioIdx + 1}: $langName ($codecLabel $channelLabel)"
                                        }

                                        trackList.add(mapOf(
                                            "index" to i,
                                            "audioIndex" to audioIdx,
                                            "name" to displayName,
                                            "language" to (lang ?: "und"),
                                            "mime" to mime,
                                            "channels" to channels,
                                            "sampleRate" to sampleRate,
                                            "isDolby" to isDolby
                                        ))
                                        audioIdx++
                                    }
                                }
                            } catch (_: Throwable) {
                            } finally {
                                try { extractor.release() } catch (_: Throwable) {}
                            }
                        }
                        runOnUiThread { result.success(trackList) }
                    }.start()
                }
                "playSyncAudio" -> {
                    val path = call.argument<String>("path") ?: ""
                    val trackIndex = call.argument<Int>("trackIndex")
                    val positionMs = (call.argument<Number>("positionMs"))?.toLong() ?: 0L
                    val volume = call.argument<Double>("volume") ?: 1.0

                    Thread {
                        try {
                            syncAudioPlayer?.stop()
                            syncAudioPlayer?.release()
                            syncAudioPlayer = null

                            val player = MediaPlayer()
                            if (path.startsWith("content://")) {
                                player.setDataSource(applicationContext, Uri.parse(path))
                            } else {
                                player.setDataSource(path)
                            }
                            player.setOnPreparedListener { mp ->
                                try {
                                    if (trackIndex != null && trackIndex >= 0) {
                                        val trackInfos = mp.trackInfo
                                        for (i in trackInfos.indices) {
                                            if (trackInfos[i].trackType == MediaPlayer.TrackInfo.MEDIA_TRACK_TYPE_AUDIO) {
                                                if (i == trackIndex) {
                                                    mp.selectTrack(i)
                                                    break
                                                }
                                            }
                                        }
                                    }
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                        mp.seekTo(positionMs, MediaPlayer.SEEK_CLOSEST_SYNC)
                                    } else {
                                        mp.seekTo(positionMs.toInt())
                                    }
                                    val vol = volume.toFloat().coerceIn(0f, 1f)
                                    mp.setVolume(vol, vol)
                                    mp.start()
                                    syncAudioPlayer = mp
                                } catch (_: Throwable) {}
                            }
                            player.setOnErrorListener { mp, what, extra ->
                                try { mp.release() } catch (_: Throwable) {}
                                syncAudioPlayer = null
                                runOnUiThread {
                                    appShareChannel?.invokeMethod("onSyncAudioError", mapOf("what" to what, "extra" to extra))
                                }
                                true
                            }
                            player.prepareAsync()
                            runOnUiThread { result.success(true) }
                        } catch (e: Throwable) {
                            runOnUiThread { result.error("AUDIO_SYNC_ERROR", e.localizedMessage, null) }
                        }
                    }.start()
                }
                "seekSyncAudio" -> {
                    val positionMs = (call.argument<Number>("positionMs"))?.toLong() ?: 0L
                    try {
                        syncAudioPlayer?.let { p ->
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                p.seekTo(positionMs, MediaPlayer.SEEK_CLOSEST_SYNC)
                            } else {
                                p.seekTo(positionMs.toInt())
                            }
                        }
                        result.success(true)
                    } catch (e: Throwable) {
                        result.success(false)
                    }
                }
                "pauseSyncAudio" -> {
                    try {
                        syncAudioPlayer?.pause()
                        result.success(true)
                    } catch (e: Throwable) {
                        result.success(false)
                    }
                }
                "resumeSyncAudio" -> {
                    try {
                        syncAudioPlayer?.start()
                        result.success(true)
                    } catch (e: Throwable) {
                        result.success(false)
                    }
                }
                "stopSyncAudio" -> {
                    try {
                        syncAudioPlayer?.stop()
                        syncAudioPlayer?.release()
                        syncAudioPlayer = null
                        result.success(true)
                    } catch (e: Throwable) {
                        result.success(false)
                    }
                }
                "setSyncAudioVolume" -> {
                    val volume = call.argument<Double>("volume") ?: 1.0
                    try {
                        val vol = volume.toFloat().coerceIn(0f, 1f)
                        syncAudioPlayer?.setVolume(vol, vol)
                        result.success(true)
                    } catch (e: Throwable) {
                        result.success(false)
                    }
                }
                "getVideoDuration" -> {
                    val path = call.argument<String>("path") ?: ""
                    Thread {
                        var durationMs = 0L
                        try {
                            if (path.isNotEmpty()) {
                                val mmr = MediaMetadataRetriever()
                                if (path.startsWith("content://")) {
                                    mmr.setDataSource(applicationContext, Uri.parse(path))
                                } else {
                                    mmr.setDataSource(path)
                                }
                                val durStr = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                                durationMs = durStr?.toLongOrNull() ?: 0L
                                mmr.release()
                            }
                        } catch (_: Throwable) {}
                        runOnUiThread { result.success(durationMs) }
                    }.start()
                }
                "decryptSaavnUrl" -> {
                    try {
                        val enc = call.argument<String>("encrypted") ?: ""
                        if (enc.isEmpty()) {
                            result.success("")
                        } else {
                            val keyBytes = "38346591".toByteArray(Charsets.UTF_8)
                            val keySpec = javax.crypto.spec.SecretKeySpec(keyBytes, "DES")
                            val cipher = javax.crypto.Cipher.getInstance("DES/ECB/PKCS5Padding")
                            cipher.init(javax.crypto.Cipher.DECRYPT_MODE, keySpec)
                            val decoded = android.util.Base64.decode(enc, android.util.Base64.DEFAULT)
                            val decryptedBytes = cipher.doFinal(decoded)
                            var url = String(decryptedBytes, Charsets.UTF_8)
                            if (url.contains("_96.mp4")) {
                                url = url.replace("_96.mp4", "_320.mp4")
                            } else if (url.contains("_160.mp4")) {
                                url = url.replace("_160.mp4", "_320.mp4")
                            }
                            result.success(url)
                        }
                    } catch (e: Exception) {
                        result.error("DECRYPT_ERROR", e.localizedMessage, null)
                    }
                }
                "decryptSaavnUrls" -> {
                    try {
                        val list = call.argument<List<String>>("encryptedList") ?: emptyList()
                        val keyBytes = "38346591".toByteArray(Charsets.UTF_8)
                        val keySpec = javax.crypto.spec.SecretKeySpec(keyBytes, "DES")
                        val cipher = javax.crypto.Cipher.getInstance("DES/ECB/PKCS5Padding")
                        cipher.init(javax.crypto.Cipher.DECRYPT_MODE, keySpec)
                        val res = list.map { enc ->
                            try {
                                if (enc.isEmpty()) ""
                                else {
                                    val decoded = android.util.Base64.decode(enc, android.util.Base64.DEFAULT)
                                    val decryptedBytes = cipher.doFinal(decoded)
                                    var url = String(decryptedBytes, Charsets.UTF_8)
                                    if (url.contains("_96.mp4")) url = url.replace("_96.mp4", "_320.mp4")
                                    else if (url.contains("_160.mp4")) url = url.replace("_160.mp4", "_320.mp4")
                                    url
                                }
                            } catch (_: Throwable) { "" }
                        }
                        result.success(res)
                    } catch (e: Exception) {
                        result.error("DECRYPT_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            syncAudioPlayer?.stop()
            syncAudioPlayer?.release()
            syncAudioPlayer = null
        } catch (_: Throwable) {}
    }
}
