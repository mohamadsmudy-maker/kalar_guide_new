package com.muhammad.kalar.kalar_guide

import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 📤 «شێرکردن بۆ ڕێبەری کەلار»: دەق / لینک / وێنە لە ئەپەکانی تر (Facebook...)
 * وەردەگرێت و بە کەناڵی kalar/share دەیدات بە Flutter. Flutter بڕیار دەدات
 * (تەنها ئەدمین فۆرمی هەواڵی پڕکراو دەبینێت).
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kalar/share").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialShare" -> {
                        result.success(pending)
                        pending = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        pending = readShare(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val share = readShare(intent) ?: return
        val ch = channel
        if (ch != null) ch.invokeMethod("onShare", share) else pending = share
    }

    private fun readShare(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        val action = intent.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return null
        val uris = mutableListOf<Uri>()
        if (action == Intent.ACTION_SEND) {
            streamExtra(intent)?.let { uris.add(it) }
        } else {
            uris.addAll(streamListExtra(intent))
        }
        val images = uris.take(4).mapIndexedNotNull { i, u -> copyToCache(u, i) }
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        if (text.isNullOrBlank() && images.isEmpty()) return null
        // یەکجار بەکاربێت: دووبارە کردنەوەی ئەپ هەمان شێر نەهێنێتەوە
        intent.action = Intent.ACTION_MAIN
        return mapOf("text" to text, "subject" to subject, "images" to images)
    }

    @Suppress("DEPRECATION")
    private fun streamExtra(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri

    @Suppress("DEPRECATION")
    private fun streamListExtra(intent: Intent): List<Uri> =
        (if (Build.VERSION.SDK_INT >= 33) intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)) ?: emptyList()

    private fun copyToCache(uri: Uri, index: Int): String? = try {
        val dir = File(cacheDir, "shared").apply { mkdirs() }
        val out = File(dir, "share_${System.currentTimeMillis()}_$index.jpg")
        contentResolver.openInputStream(uri)?.use { input ->
            out.outputStream().use { input.copyTo(it) }
        }
        if (out.length() > 0) out.absolutePath else null
    } catch (e: Exception) {
        null
    }
}
