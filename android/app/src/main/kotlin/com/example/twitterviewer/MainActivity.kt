package com.example.twitterviewer

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {
    companion object {
        private const val callbackScheme = "xviewer"
        private const val callbackHost = "auth"
        private const val callbackPath = "/callback"
        private const val authChannel = "xviewer/auth_callback"
        private const val authEventChannel = "xviewer/auth_callback/events"
        private const val galleryChannel = "xviewer/gallery"
        private const val logTag = "XviewerOAuth"
    }

    private var pendingCallbackUrl: String? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            authChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingCallbackUrl" -> {
                    result.success(pendingCallbackUrl)
                    pendingCallbackUrl = null
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            galleryChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveImageToGallery" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType") ?: "image/jpeg"
                    val albumName = call.argument<String>("albumName") ?: "Xviewer"

                    if (bytes == null || fileName.isNullOrBlank()) {
                        result.error("invalid_args", "Image bytes or file name is missing", null)
                        return@setMethodCallHandler
                    }

                    try {
                        result.success(saveImageToGallery(bytes, fileName, mimeType, albumName))
                    } catch (error: Exception) {
                        result.error("gallery_save_failed", error.message, null)
                    }
                }
                "deleteImageFromGallery" -> {
                    val contentUri = call.argument<String>("contentUri")
                    if (contentUri.isNullOrBlank()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }

                    try {
                        contentResolver.delete(Uri.parse(contentUri), null, null)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("gallery_delete_failed", error.message, null)
                    }
                }
                "openGalleryApp" -> {
                    try {
                        openGalleryApp()
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("gallery_open_failed", error.message, null)
                    }
                }
                "getAndroidSdkInt" -> result.success(Build.VERSION.SDK_INT)
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            authEventChannel,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    pendingCallbackUrl?.let { url ->
                        events?.success(url)
                        pendingCallbackUrl = null
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )

        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val callbackUrl = intent?.dataString ?: return
        val uri = intent.data
        Log.d(
            logTag,
            "handleIntent callbackUrl=$callbackUrl scheme=${uri?.scheme} host=${uri?.host} path=${uri?.path} state=${uri?.getQueryParameter("state")} hasCode=${!uri?.getQueryParameter("code").isNullOrEmpty()} error=${uri?.getQueryParameter("error")}",
        )
        if (uri?.scheme != callbackScheme ||
            uri.host != callbackHost ||
            uri.path != callbackPath
        ) {
            Log.d(logTag, "Ignoring non-matching callback URL: $callbackUrl")
            return
        }

        val sink = eventSink
        if (sink != null) {
            Log.d(logTag, "Delivering callback URL to EventChannel: $callbackUrl")
            sink.success(callbackUrl)
        } else {
            Log.d(logTag, "Storing pending callback URL: $callbackUrl")
            pendingCallbackUrl = callbackUrl
        }
    }

    private fun saveImageToGallery(
        bytes: ByteArray,
        fileName: String,
        mimeType: String,
        albumName: String,
    ): Map<String, String> {
        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/$albumName",
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            } else {
                val picturesDir = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_PICTURES,
                )
                val albumDir = java.io.File(picturesDir, albumName)
                if (!albumDir.exists()) {
                    albumDir.mkdirs()
                }
                put(
                    MediaStore.Images.Media.DATA,
                    java.io.File(albumDir, fileName).absolutePath,
                )
            }
        }

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }

        val uri = resolver.insert(collection, values)
            ?: throw IOException("Could not create gallery record")

        try {
            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
                stream.flush()
            } ?: throw IOException("Could not open gallery output stream")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val readyValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
                resolver.update(uri, readyValues, null, null)
            }

            return mapOf(
                "contentUri" to uri.toString(),
                "savedPath" to "Pictures/$albumName/$fileName",
                "displayName" to fileName,
            )
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    private fun openGalleryApp() {
        val intents = listOf(
            Intent(Intent.ACTION_VIEW, MediaStore.Images.Media.EXTERNAL_CONTENT_URI),
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_APP_GALLERY),
        )

        val launchIntent = intents.firstOrNull { intent ->
            intent.resolveActivity(packageManager) != null
        } ?: throw IOException("No gallery app available")

        startActivity(launchIntent)
    }
}
