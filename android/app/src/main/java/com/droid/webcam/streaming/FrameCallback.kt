package com.droid.webcam.streaming

/**
 * Callback interface for encoded video frames from the camera encoder.
 */
interface FrameCallback {
    /**
     * Called when a new H.264 NAL unit is ready.
     * @param data Raw H.264 bytes (Annex B format with start codes)
     * @param presentationTimeUs Presentation timestamp in microseconds
     * @param isKeyFrame True if this is an IDR (keyframe)
     */
    fun onFrame(data: ByteArray, presentationTimeUs: Long, isKeyFrame: Boolean)
}
