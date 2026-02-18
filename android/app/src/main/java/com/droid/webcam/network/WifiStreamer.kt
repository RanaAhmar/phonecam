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
 * WiFi TCP streaming server.
 * Listens on [Protocol.PORT_VIDEO] for incoming Mac connections.
 * Implements the Droid Camera protocol (see PROTOCOL.md).
 */
class WifiStreamer(
    private val onClientConnected: (host: String) -> Unit,
    private val onClientDisconnected: () -> Unit,
    private val onError: (String) -> Unit
) {
    private val TAG = "WifiStreamer"
    private val seqNum = AtomicInteger(0)

    private var serverSocket: ServerSocket? = null
    private var clientSocket: Socket? = null
    private var running = false

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    suspend fun startServer() {
        running = true
        try {
            serverSocket = ServerSocket(Protocol.PORT_VIDEO).also { server ->
                server.reuseAddress = true
                Log.d(TAG, "WiFi server listening on port ${Protocol.PORT_VIDEO}")

                while (running) {
                    try {
                        val client = server.accept()
                        handleClient(client)
                    } catch (e: IOException) {
                        if (running) Log.e(TAG, "Accept error: ${e.message}")
                    }
                }
            }
        } catch (e: IOException) {
            if (running) onError("Failed to start WiFi server: ${e.message}")
        }
    }

    private suspend fun handleClient(socket: Socket) = withContext(Dispatchers.IO) {
        clientSocket = socket
        val host = socket.inetAddress.hostAddress ?: "unknown"
        Log.d(TAG, "Client connected: $host")

        try {
            socket.tcpNoDelay = true
            socket.setSoTimeout(10_000) // 10s read timeout for keepalive

            val input = BufferedInputStream(socket.getInputStream())
            val output = socket.getOutputStream()

            // Read HELLO
            val headerBuf = ByteArray(Protocol.HEADER_SIZE)
            readFully(input, headerBuf)
            val header = Protocol.parseHeader(headerBuf)

            if (header?.type != Protocol.TYPE_HELLO) {
                Log.e(TAG, "Expected HELLO, got: ${header?.type}")
                socket.close()
                return@withContext
            }

            val helloPayload = ByteArray(header.payloadLen)
            if (header.payloadLen > 0) readFully(input, helloPayload)
            Log.d(TAG, "HELLO received: ${String(helloPayload)}")

            // Send HELLO_ACK
            val ackJson = """{"version":1,"accepted":true,"requestedResolution":"1080p","requestedFps":60}"""
            Protocol.writePacket(
                output,
                Protocol.TYPE_HELLO_ACK,
                seqNum.getAndIncrement(),
                System.currentTimeMillis() * 1000L,
                ackJson.toByteArray()
            )

            onClientConnected(host)

            // Start keepalive ping job
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
                    } catch (e: IOException) {
                        break
                    }
                }
            }

            // Read loop (handle PONG, SETTINGS, DISCONNECT)
            try {
                while (running && !socket.isClosed) {
                    val hdr = ByteArray(Protocol.HEADER_SIZE)
                    readFully(input, hdr)
                    val h = Protocol.parseHeader(hdr) ?: break
                    val payload = ByteArray(h.payloadLen)
                    if (h.payloadLen > 0) readFully(input, payload)

                    when (h.type) {
                        Protocol.TYPE_PONG -> { /* keepalive ok */ }
                        Protocol.TYPE_DISCONNECT -> break
                        Protocol.TYPE_SETTINGS -> {
                            Log.d(TAG, "Settings received: ${String(payload)}")
                            Protocol.writePacket(
                                output,
                                Protocol.TYPE_SETTINGS_ACK,
                                seqNum.getAndIncrement(),
                                System.currentTimeMillis() * 1000L
                            )
                        }
                        else -> Log.w(TAG, "Unknown frame type: ${h.type}")
                    }
                }
            } catch (e: IOException) {
                Log.d(TAG, "Client read loop ended: ${e.message}")
            } finally {
                pingJob.cancel()
            }

        } catch (e: Exception) {
            Log.e(TAG, "Client handler error: ${e.message}")
        } finally {
            socket.close()
            clientSocket = null
            onClientDisconnected()
        }
    }

    /**
     * Send an encoded H.264 frame to the connected Mac client.
     * Called from the encoder thread — must be thread-safe.
     */
    fun sendFrame(data: ByteArray, presentationTimeUs: Long, isKeyFrame: Boolean) {
        val socket = clientSocket ?: return
        if (socket.isClosed) return
        try {
            val out = socket.getOutputStream()
            Protocol.writePacket(
                out,
                Protocol.TYPE_VIDEO,
                seqNum.getAndIncrement(),
                presentationTimeUs,
                data
            )
        } catch (e: IOException) {
            Log.w(TAG, "Failed to send frame: ${e.message}")
        }
    }

    fun stop() {
        running = false
        scope.cancel()
        try {
            clientSocket?.close()
            serverSocket?.close()
        } catch (e: IOException) {
            Log.e(TAG, "Error stopping: ${e.message}")
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
