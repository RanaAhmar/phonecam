package com.droid.webcam.camera

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.util.Size
import android.view.Surface
import com.droid.webcam.streaming.FrameCallback
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit

/**
 * Manages Camera2 capture and H.264 encoding via MediaCodec.
 * Encoded NAL units are delivered via [FrameCallback].
 */
class CameraManager(
    private val context: Context,
    private val frameCallback: FrameCallback
) {
    private val TAG = "DroidCameraManager"

    // Camera state
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private val cameraOpenCloseLock = Semaphore(1)

    // Background thread for camera ops
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null

    // Encoder
    private var encoder: MediaCodec? = null
    private var encoderSurface: Surface? = null

    // Settings
    var resolution: Resolution = Resolution.RES_1080P
    var frameRate: Int = 60
    var bitrate: Int = 8_000_000  // 8 Mbps default
    var useFrontCamera: Boolean = false

    enum class Resolution(val width: Int, val height: Int, val label: String) {
        RES_720P(1280, 720, "720p"),
        RES_1080P(1920, 1080, "1080p"),
        RES_4K(3840, 2160, "4K")
    }

    fun start() {
        startBackgroundThread()
        setupEncoder()
        openCamera()
    }

    fun stop() {
        closeCamera()
        stopEncoder()
        stopBackgroundThread()
    }

    fun flipCamera() {
        useFrontCamera = !useFrontCamera
        stop()
        start()
    }

    private fun setupEncoder() {
        val format = MediaFormat.createVideoFormat(
            MediaFormat.MIMETYPE_VIDEO_AVC,
            resolution.width,
            resolution.height
        ).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, frameRate)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2) // Keyframe every 2 seconds
            setInteger(MediaFormat.KEY_PROFILE,
                MediaCodecInfo.CodecProfileLevel.AVCProfileBaseline)
            setInteger(MediaFormat.KEY_LEVEL,
                MediaCodecInfo.CodecProfileLevel.AVCLevel41)
            // Low latency mode
            setInteger(MediaFormat.KEY_LATENCY, 0)
            setInteger(MediaFormat.KEY_PRIORITY, 0) // real-time priority
        }

        encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC).also { codec ->
            codec.setCallback(object : MediaCodec.Callback() {
                override fun onInputBufferAvailable(codec: MediaCodec, index: Int) {
                    // Surface-based encoder — no input buffers needed
                }

                override fun onOutputBufferAvailable(
                    codec: MediaCodec,
                    index: Int,
                    info: MediaCodec.BufferInfo
                ) {
                    val buffer = codec.getOutputBuffer(index) ?: return
                    if (info.size > 0 && (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0) {
                        val data = ByteArray(info.size)
                        buffer.position(info.offset)
                        buffer.get(data, 0, info.size)
                        val isKeyFrame = (info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME) != 0
                        frameCallback.onFrame(data, info.presentationTimeUs, isKeyFrame)
                    }
                    codec.releaseOutputBuffer(index, false)
                }

                override fun onError(codec: MediaCodec, e: MediaCodec.CodecException) {
                    Log.e(TAG, "Encoder error: ${e.message}")
                }

                override fun onOutputFormatChanged(codec: MediaCodec, format: MediaFormat) {
                    Log.d(TAG, "Encoder output format changed: $format")
                }
            }, backgroundHandler)

            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoderSurface = codec.createInputSurface()
            codec.start()
        }
    }

    @SuppressLint("MissingPermission")
    private fun openCamera() {
        val manager = context.getSystemService(Context.CAMERA_SERVICE) as android.hardware.camera2.CameraManager
        val cameraId = selectCamera(manager) ?: run {
            Log.e(TAG, "No suitable camera found")
            return
        }

        try {
            if (!cameraOpenCloseLock.tryAcquire(2500, TimeUnit.MILLISECONDS)) {
                throw RuntimeException("Timeout waiting to lock camera opening.")
            }
            manager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraOpenCloseLock.release()
                    cameraDevice = camera
                    createCaptureSession()
                }

                override fun onDisconnected(camera: CameraDevice) {
                    cameraOpenCloseLock.release()
                    camera.close()
                    cameraDevice = null
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    cameraOpenCloseLock.release()
                    camera.close()
                    cameraDevice = null
                    Log.e(TAG, "Camera error: $error")
                }
            }, backgroundHandler)
        } catch (e: CameraAccessException) {
            Log.e(TAG, "Cannot access camera: ${e.message}")
        }
    }

    private fun selectCamera(manager: android.hardware.camera2.CameraManager): String? {
        val facing = if (useFrontCamera)
            CameraCharacteristics.LENS_FACING_FRONT
        else
            CameraCharacteristics.LENS_FACING_BACK

        return manager.cameraIdList.firstOrNull { id ->
            val chars = manager.getCameraCharacteristics(id)
            chars.get(CameraCharacteristics.LENS_FACING) == facing
        }
    }

    private fun createCaptureSession() {
        val surface = encoderSurface ?: return
        val device = cameraDevice ?: return

        try {
            device.createCaptureSession(
                listOf(surface),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        captureSession = session
                        startRepeatingCapture(session)
                    }

                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        Log.e(TAG, "Capture session configuration failed")
                    }
                },
                backgroundHandler
            )
        } catch (e: CameraAccessException) {
            Log.e(TAG, "Failed to create capture session: ${e.message}")
        }
    }

    private fun startRepeatingCapture(session: CameraCaptureSession) {
        val surface = encoderSurface ?: return
        try {
            val request = session.device.createCaptureRequest(CameraDevice.TEMPLATE_RECORD).apply {
                addTarget(surface)
                set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO)
                set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO)
                set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE,
                    android.util.Range(frameRate, frameRate))
            }.build()

            session.setRepeatingRequest(request, null, backgroundHandler)
        } catch (e: CameraAccessException) {
            Log.e(TAG, "Failed to start repeating capture: ${e.message}")
        }
    }

    private fun closeCamera() {
        try {
            cameraOpenCloseLock.acquire()
            captureSession?.close()
            captureSession = null
            cameraDevice?.close()
            cameraDevice = null
        } finally {
            cameraOpenCloseLock.release()
        }
    }

    private fun stopEncoder() {
        try {
            encoder?.stop()
            encoder?.release()
            encoder = null
            encoderSurface?.release()
            encoderSurface = null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping encoder: ${e.message}")
        }
    }

    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("CameraBackground").also { it.start() }
        backgroundHandler = Handler(backgroundThread!!.looper)
    }

    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        try {
            backgroundThread?.join()
            backgroundThread = null
            backgroundHandler = null
        } catch (e: InterruptedException) {
            Log.e(TAG, "Interrupted stopping background thread: ${e.message}")
        }
    }
}
