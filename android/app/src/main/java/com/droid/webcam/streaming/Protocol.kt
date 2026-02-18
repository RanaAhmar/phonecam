package com.droid.webcam.streaming

import java.io.OutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Implements the Droid Camera binary streaming protocol.
 * See /protocol/PROTOCOL.md for full specification.
 *
 * Packet format:
 *   [DROID (5)] [Type (1)] [SeqNum (4)] [Timestamp (8)] [PayloadLen (4)] [Payload (N)]
 *   Total header = 22 bytes
 */
object Protocol {

    const val MAGIC = "DROID"
    const val PORT_VIDEO = 7878
    const val PORT_DISCOVERY = 7879
    const val HEADER_SIZE = 22

    // Frame types
    const val TYPE_HELLO: Byte = 0x01
    const val TYPE_HELLO_ACK: Byte = 0x02
    const val TYPE_SETTINGS: Byte = 0x03
    const val TYPE_SETTINGS_ACK: Byte = 0x04
    const val TYPE_VIDEO: Byte = 0x10
    const val TYPE_PING: Byte = 0x20
    const val TYPE_PONG: Byte = 0x21
    const val TYPE_DISCONNECT: Byte = 0xFF.toByte()

    private val MAGIC_BYTES = MAGIC.toByteArray(Charsets.US_ASCII)

    /**
     * Build a complete protocol packet.
     */
    fun buildPacket(
        type: Byte,
        seqNum: Int,
        timestampUs: Long,
        payload: ByteArray = ByteArray(0)
    ): ByteArray {
        val buf = ByteBuffer.allocate(HEADER_SIZE + payload.size)
            .order(ByteOrder.BIG_ENDIAN)
        buf.put(MAGIC_BYTES)
        buf.put(type)
        buf.putInt(seqNum)
        buf.putLong(timestampUs)
        buf.putInt(payload.size)
        if (payload.isNotEmpty()) buf.put(payload)
        return buf.array()
    }

    /**
     * Write a packet directly to an OutputStream.
     */
    fun writePacket(
        out: OutputStream,
        type: Byte,
        seqNum: Int,
        timestampUs: Long,
        payload: ByteArray = ByteArray(0)
    ) {
        out.write(buildPacket(type, seqNum, timestampUs, payload))
        out.flush()
    }

    /**
     * Parse the header from a 22-byte buffer.
     * Returns null if magic bytes don't match.
     */
    data class Header(
        val type: Byte,
        val seqNum: Int,
        val timestampUs: Long,
        val payloadLen: Int
    )

    fun parseHeader(headerBytes: ByteArray): Header? {
        if (headerBytes.size < HEADER_SIZE) return null
        val buf = ByteBuffer.wrap(headerBytes).order(ByteOrder.BIG_ENDIAN)

        val magic = ByteArray(5)
        buf.get(magic)
        if (!magic.contentEquals(MAGIC_BYTES)) return null

        val type = buf.get()
        val seqNum = buf.int
        val timestamp = buf.long
        val payloadLen = buf.int

        return Header(type, seqNum, timestamp, payloadLen)
    }
}
