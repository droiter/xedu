package com.xedu.xedu

import android.net.Uri
import android.provider.BaseColumns
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "xedu/picker")
            .setMethodCallHandler { call, result ->
                if (call.method != "displayName") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val uri = call.argument<String>("uri")
                // 查内容提供者可能要等一会儿，别占着主线程。
                Thread {
                    val name = displayNameOf(uri)
                    runOnUiThread {
                        try {
                            result.success(name)
                        } catch (_: Exception) {
                            // 界面已经退掉了，这个结果没人要了。
                        }
                    }
                }.start()
            }
    }

    /// 文件在「文件管理 / 相册」里显示的名字；查不到就返回 null 交给上层兜底。
    ///
    /// 选择器插件自己也会查一次，但它只问 `display_name` 一列，问不到就退回
    /// 拿地址最后一段当名字——相册给的地址 `content://media/.../1234` 最后一段
    /// 是编号，于是家长看到的就是一串数字。
    private fun displayNameOf(raw: String?): String? {
        if (raw.isNullOrBlank()) return null
        val uri = Uri.parse(raw)
        if (uri.scheme == "file") return uri.lastPathSegment
        if (uri.scheme != "content") return null

        // 不同提供者认的列名不一样，常用的都问一遍。
        return queryName(uri, OpenableColumns.DISPLAY_NAME)
            ?: queryName(uri, MediaStore.MediaColumns.DISPLAY_NAME)
            ?: queryName(uri, MediaStore.MediaColumns.TITLE)
            ?: nameById(uri)
    }

    private fun queryName(
        uri: Uri,
        column: String,
        selection: String? = null,
        args: Array<String>? = null,
    ): String? =
        try {
            contentResolver.query(uri, arrayOf(column), selection, args, null)?.use { cursor ->
                if (cursor.moveToFirst() && !cursor.isNull(0)) {
                    cursor.getString(0)?.takeIf { it.isNotBlank() }
                } else {
                    null
                }
            }
        } catch (_: Exception) {
            // 没有权限、提供者不认识这一列……都当没问出来。
            null
        }

    /// 地址只给到 `content://media/.../1234` 时，拿这个编号去媒体库里再查一遍。
    private fun nameById(uri: Uri): String? {
        val id = uri.lastPathSegment?.takeIf { it.isNotEmpty() && it.all(Char::isDigit) }
            ?: return null
        val tables = listOf(
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            MediaStore.Files.getContentUri("external"),
        )
        for (table in tables) {
            val name = queryName(
                table,
                MediaStore.MediaColumns.DISPLAY_NAME,
                "${BaseColumns._ID} = ?",
                arrayOf(id),
            )
            if (name != null) return name
        }
        return null
    }
}
