package com.example.harupan

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.io.File

class MainActivity : FlutterActivity() {
	private val CHANNEL = "harupan/onnx"
	private var env: OrtEnvironment? = null
	private var session: OrtSession? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"loadModel" -> {
					val assetPath = call.argument<String>("assetPath") ?: ""
					val ok = try { loadModelFromAssets(assetPath) } catch (e: Exception) { e.printStackTrace(); false }
					if (ok) result.success(true) else result.error("load_failed", "Failed to load model", null)
				}
				"run" -> {
					val bytes = call.argument<ByteArray>("imageBytes")
					val imgsz = call.argument<Int>("imgsz") ?: 640
					if (bytes == null) {
						result.error("bad_args", "Missing imageBytes", null)
						return@setMethodCallHandler
					}
					try {
						val out = runInference(bytes, imgsz)
						result.success(out)
					} catch (e: Exception) {
						e.printStackTrace()
						result.error("run_failed", e.message, null)
					}
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun loadModelFromAssets(assetPath: String): Boolean {
		if (assetPath.isEmpty()) return false
		if (env == null) env = OrtEnvironment.getEnvironment()
		val fileName = File(assetPath).name
		val outFile = File(filesDir, fileName)
		if (!outFile.exists()) {
			assets.open(assetPath).use { input ->
				outFile.outputStream().use { output -> input.copyTo(output) }
			}
		}
		session?.close()
		session = env!!.createSession(outFile.absolutePath, OrtSession.SessionOptions())
		return true
	}

	private fun runInference(imageBytes: ByteArray, imgsz: Int): List<Float> {
		val bmp = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size) ?: throw Exception("Failed to decode image")
		val scaled = Bitmap.createScaledBitmap(bmp, imgsz, imgsz, true)

		// Prepare NCHW float array normalized to [0,1]
		val nchw = FloatArray(1 * 3 * imgsz * imgsz)
		var idx = 0
		for (c in 0 until 3) {
			for (y in 0 until imgsz) {
				for (x in 0 until imgsz) {
					val px = scaled.getPixel(x, y)
					val v = when (c) {
						0 -> Color.red(px)
						1 -> Color.green(px)
						else -> Color.blue(px)
					}
					nchw[idx++] = v / 255.0f
				}
			}
		}

		val shape = longArrayOf(1, 3, imgsz.toLong(), imgsz.toLong())
		val tensor = OnnxTensor.createTensor(env, java.nio.FloatBuffer.wrap(nchw), shape)
		val results = session?.run(listOf(tensor)) ?: throw Exception("Session not loaded")
		val first = results[0].value
		val outList = mutableListOf<Float>()
		when (first) {
			is Array<*> -> {
				// flatten recursively
				fun flatten(a: Any?) {
					when (a) {
						is Float -> outList.add(a)
						is Double -> outList.add(a.toFloat())
						is Array<*> -> a.forEach { flatten(it) }
						is FloatArray -> a.forEach { outList.add(it) }
						is DoubleArray -> a.forEach { outList.add(it.toFloat()) }
					}
				}
				flatten(first)
			}
			is FloatArray -> first.forEach { outList.add(it) }
			is DoubleArray -> first.forEach { outList.add(it.toFloat()) }
			else -> throw Exception("Unsupported output type: ${first::class}")
		}
		// release resources
		results.forEach { it.close() }
		tensor.close()
		return outList
	}
}
