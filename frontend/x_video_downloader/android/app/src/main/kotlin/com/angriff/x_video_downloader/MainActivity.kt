package com.angriff.x_video_downloader

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.angriff.x_video_downloader/media_scanner"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "scanFile") {
                val path = call.argument<String>("path")
                path?.let {
                    val file = File(it)
                    val uri = Uri.fromFile(file)
                    val intent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE, uri)
                    sendBroadcast(intent)
                    result.success(null)
                } ?: result.error("NULL_PATH", "File path is null", null)
            } else {
                result.notImplemented()
            }
        }
    }
}
