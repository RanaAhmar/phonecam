package com.droid.webcam.network

import android.util.Log
import com.droid.webcam.streaming.Protocol
import kotlinx.coroutines.*
import java.io.BufferedInputStream
import java.io.IOException
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.atomic.AtomicInteger

/**
 * USB streaming server — identical protocol to WifiStreamer.
 * In USB mode, the Mac runs `adb forward tcp:7878 tcp:7878` which tunnels
 * the Mac's localhost:7878 to this server on the Android device.
 *
 * The Android device acts as a TCP server on port 7878 in both modes.
 * The only difference is that USB connections come from localhost (127.0.0.1)
 * via ADB port forwarding.
 */
class UsbStreamer(
    private val onClientConnected: (host: String) -> Unit,
    private val onClientDisconnected: () -> Unit,
    private val onError: (String) -> Unit
) {
    private val TAG = "UsbStreamer"
    private val seqNum = AtomicInteger(0)

    private var serverSocket: ServerSocket? = null
    private var clientSocket: Socket? = null
    private var running = false

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /**
     * Start listening. ADB-forwarded connections arrive on the same port.
     * USB connections are identified by source IP being loopback (127.0.0.1).
     */
    suspend fun startServer() {
        running = true
        try {
            // Bind only to loopback for USB mode — ADB forward delivers to 127.0.0.1
            serverSocket = ServerSocket(Protocol.PORT_VIDEO).also { server ->
                server.reuseAddress = true
                Log.d(TAG, "USB server listening on port ${Protocol.PORT_VIDEO}")

                while (running) {
                    try {
                        val client = server.accept()
                        // Only accept loopback connections in USB mode
                        val isLoopback = client.inetAddress.isLoopbackAddress
                        if (!isLoopback) {
                            Log.w(TAG, "USB mode: rejecting non-loopback connection from ${client.inetAddress}")
                            client.close()
                            continue
                        }
                        handleClient(client)
                    } catch (e: IOException) {
                        if (running) Log.e(TAG, "Accept error: ${e.message}")
                    }
                }
            }
        } catch (e: IOException) {
            if (running) onError("Failed to start USB server: ${e.message}")
        }
    }

    private suspend fun handleClient(socket: Socket) = withContext(Dispatchers.IO) {
        clientSocket = socket
        Log.d(TAG, "USB client connected (ADB forwarded)")

        try {
            socket.tcpNoDelay = true
            socket.setSoTimeout(10_000)

            val input = BufferedInputStream(socket.getInputStream())
            val output = socket.getOutputStream()

            // Read HELLO
            val headerBuf = ByteArray(Protocol.HEADER_SIZE)
            readFully(input, headerBuf)
            val header = Protocol.parseHeader(headerBuf) ?: run {
                Log.e(TAG, "Invalid header")
                socket.close()
                return@withContext
            }

            if (header.type != Protocol.TYPE_HELLO) {
                socket.close()
                return@withContext
            }

            val helloPayload = ByteArray(header.payloadLen)
            if (header.payloadLen > 0) readFully(input, helloPayload)

            // Send HELLO_ACK
            val ackJson = """{"version":1,"accepted":true,"requestedResolution":"1080p","requestedFps":60}"""
            Protocol.writePacket(
                output,
                Protocol.TYPE_HELLO_ACK,
                seqNum.getAndIncrement(),
                System.currentTimeMillis() * 1000L,
                ackJson.toByteArray()
            )

            onClientConnected("USB")

            // Keepalive ping
            val pingJob = scope.launch {
                while (isActive && !socket.isClosed) {
                    delay(2000)
                    try {
                        Protocol.writePacket(
                            output,
                            Protocol.TYPE_PING,
                            seqNum.getAndIncrement(),
                            System.currentTimeMillis() * 1000L
                        )
                    } catch (e: IOException) { break }
                }
            }

            try {
                while (running && !socket.isClosed) {
                    val hdr = ByteArray(Protocol.HEADER_SIZE)
                    readFully(input, hdr)
                    val h = Protocol.parseHeader(hdr) ?: break
                    val payload = ByteArray(h.payloadLen)
                    if (h.payloadLen > 0) readFully(input, payload)

                    when (h.type) {
                        Protocol.TYPE_PONG -> { /* ok */ }
                        Protocol.TYPE_DISCONNECT -> break
                        Protocol.TYPE_SETTINGS -> {
                            Protocol.writePacket(
                                output,
                                Protocol.TYPE_SETTINGS_ACK,
                                seqNum.getAndIncrement(),
                                System.currentTimeMillis() * 1000L
                            )
                        }
                        else -> {}
                    }
                }
            } catch (e: IOException) {
                Log.d(TAG, "USB read loop ended: ${e.message}")
            } finally {
                pingJob.cancel()
            }

        } catch (e: Exception) {
            Log.e(TAG, "USB client error: ${e.message}")
        } finally {
            socket.close()
            clientSocket = null
            onClientDisconnected()
        }
    }

    fun sendFrame(data: ByteArray, presentationTimeUs: Long, isKeyFrame: Boolean) {
        val socket = clientSocket ?: return
        if (socket.isClosed) return
        try {
            Protocol.writePacket(
                socket.getOutputStream(),
                Protocol.TYPE_VIDEO,
                seqNum.getAndIncrement(),
                presentationTimeUs,
                data
            )
        } catch (e: IOException) {
            Log.w(TAG, "Failed to send USB frame: ${e.message}")
        }
    }

    fun stop() {
        running = false
        scope.cancel()
        try {
            clientSocket?.close()
            serverSocket?.close()
        } catch (e: IOException) {
            Log.e(TAG, "Error stopping USB streamer: ${e.message}")
        }
        clientSocket = null
        serverSocket = null
    }

    private fun readFully(input: BufferedInputStream, buf: ByteArray) {
        var offset = 0
        while (offset < buf.size) {
            val read = input.read(buf, offset, buf.size - offset)
            if (read == -1) throw IOException("Stream closed")
            offset += read
        }
    }
}
