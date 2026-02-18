package com.droid.webcam.streaming

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.droid.webcam.MainActivity
import com.droid.webcam.R
import com.droid.webcam.camera.CameraManager
import com.droid.webcam.network.UsbStreamer
import com.droid.webcam.network.WifiStreamer
import kotlinx.coroutines.*

/**
 * Foreground service that manages camera capture and video streaming.
 * Coordinates between CameraManager (capture/encode) and the active
 * transport (WifiStreamer or UsbStreamer).
 */
class StreamingService : Service(), FrameCallback {

    private val TAG = "StreamingService"
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val binder = LocalBinder()

    private lateinit var cameraManager: CameraManager
    private var wifiStreamer: WifiStreamer? = null
    private var usbStreamer: UsbStreamer? = null

    var isStreaming = false
        private set

    var connectionMode = ConnectionMode.NONE
        private set

    enum class ConnectionMode { NONE, WIFI, USB }

    // Listener for UI updates
    var statusListener: StatusListener? = null

    interface StatusListener {
        fun onConnectionChanged(mode: ConnectionMode, connectedHost: String?)
        fun onError(message: String)
    }

    inner class LocalBinder : Binder() {
        fun getService(): StreamingService = this@StreamingService
    }

    override fun onCreate() {
        super.onCreate()
        cameraManager = CameraManager(this, this)
        startForeground(NOTIFICATION_ID, buildNotification("Ready to stream"))
    }

    override fun onBind(intent: Intent): IBinder = binder

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_WIFI -> startWifiStreaming()
            ACTION_START_USB -> startUsbStreaming()
            ACTION_STOP -> stopStreaming()
        }
        return START_STICKY
    }

    fun startWifiStreaming() {
        if (isStreaming) stopStreaming()
        connectionMode = ConnectionMode.WIFI

        wifiStreamer = WifiStreamer(
            onClientConnected = { host ->
                Log.d(TAG, "WiFi client connected: $host")
                cameraManager.start()
                isStreaming = true
                updateNotification("Streaming via WiFi to $host")
                statusListener?.onConnectionChanged(ConnectionMode.WIFI, host)
            },
            onClientDisconnected = {
                Log.d(TAG, "WiFi client disconnected")
                cameraManager.stop()
                isStreaming = false
                updateNotification("Ready to stream")
                statusListener?.onConnectionChanged(ConnectionMode.NONE, null)
                // Auto-restart server to accept new connections
                wifiStreamer?.startServer()
            },
            onError = { msg ->
                Log.e(TAG, "WiFi error: $msg")
                statusListener?.onError(msg)
            }
        )

        serviceScope.launch { wifiStreamer?.startServer() }
    }

    fun startUsbStreaming() {
        if (isStreaming) stopStreaming()
        connectionMode = ConnectionMode.USB

        usbStreamer = UsbStreamer(
            onClientConnected = { host ->
                Log.d(TAG, "USB client connected: $host")
                cameraManager.start()
                isStreaming = true
                updateNotification("Streaming via USB")
                statusListener?.onConnectionChanged(ConnectionMode.USB, host)
            },
            onClientDisconnected = {
                Log.d(TAG, "USB client disconnected")
                cameraManager.stop()
                isStreaming = false
                updateNotification("Ready to stream")
                statusListener?.onConnectionChanged(ConnectionMode.NONE, null)
                usbStreamer?.startServer()
            },
            onError = { msg ->
                Log.e(TAG, "USB error: $msg")
                statusListener?.onError(msg)
            }
        )

        serviceScope.launch { usbStreamer?.startServer() }
    }

    fun stopStreaming() {
        cameraManager.stop()
        wifiStreamer?.stop()
        usbStreamer?.stop()
        wifiStreamer = null
        usbStreamer = null
        isStreaming = false
        connectionMode = ConnectionMode.NONE
        updateNotification("Ready to stream")
        statusListener?.onConnectionChanged(ConnectionMode.NONE, null)
    }

    fun applySettings(resolution: CameraManager.Resolution, fps: Int, bitrate: Int) {
        val wasStreaming = isStreaming
        val mode = connectionMode
        if (wasStreaming) stopStreaming()

        cameraManager.resolution = resolution
        cameraManager.frameRate = fps
        cameraManager.bitrate = bitrate

        if (wasStreaming) {
            when (mode) {
                ConnectionMode.WIFI -> startWifiStreaming()
                ConnectionMode.USB -> startUsbStreaming()
                ConnectionMode.NONE -> {}
            }
        }
    }

    fun flipCamera() {
        cameraManager.flipCamera()
    }

    // FrameCallback — called from encoder thread
    override fun onFrame(data: ByteArray, presentationTimeUs: Long, isKeyFrame: Boolean) {
        wifiStreamer?.sendFrame(data, presentationTimeUs, isKeyFrame)
        usbStreamer?.sendFrame(data, presentationTimeUs, isKeyFrame)
    }

    override fun onDestroy() {
        stopStreaming()
        serviceScope.cancel()
        super.onDestroy()
    }

    // ── Notification ──────────────────────────────────────────────────────────

    private fun buildNotification(text: String): Notification {
        val channelId = "streaming_channel"
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(channelId) == null) {
            nm.createNotificationChannel(
                NotificationChannel(channelId, "Streaming", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val intent = Intent(this, MainActivity::class.java)
        val pi = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("Droid Camera")
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_camera_notification)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(text: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, buildNotification(text))
    }

    companion object {
        const val NOTIFICATION_ID = 1001
        const val ACTION_START_WIFI = "com.droid.webcam.START_WIFI"
        const val ACTION_START_USB = "com.droid.webcam.START_USB"
        const val ACTION_STOP = "com.droid.webcam.STOP"
    }
}
