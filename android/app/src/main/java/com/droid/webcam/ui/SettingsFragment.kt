package com.droid.webcam.ui

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.IBinder
import androidx.preference.ListPreference
import androidx.preference.PreferenceFragmentCompat
import androidx.preference.SeekBarPreference
import androidx.preference.SwitchPreferenceCompat
import com.droid.webcam.R
import com.droid.webcam.camera.CameraManager
import com.droid.webcam.streaming.StreamingService

/**
 * Settings screen using PreferenceFragmentCompat.
 * Preferences are stored in SharedPreferences and applied to the streaming service.
 */
class SettingsFragment : PreferenceFragmentCompat() {

    private var streamingService: StreamingService? = null
    private var serviceBound = false

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            streamingService = (binder as StreamingService.LocalBinder).getService()
            serviceBound = true
        }
        override fun onServiceDisconnected(name: ComponentName) {
            streamingService = null
            serviceBound = false
        }
    }

    override fun onCreatePreferences(savedInstanceState: Bundle?, rootKey: String?) {
        setPreferencesFromResource(R.xml.preferences, rootKey)

        val serviceIntent = Intent(requireContext(), StreamingService::class.java)
        requireContext().bindService(serviceIntent, serviceConnection, Context.BIND_AUTO_CREATE)

        // Resolution
        findPreference<ListPreference>("resolution")?.setOnPreferenceChangeListener { _, value ->
            val resolution = when (value as String) {
                "720p" -> CameraManager.Resolution.RES_720P
                "4K" -> CameraManager.Resolution.RES_4K
                else -> CameraManager.Resolution.RES_1080P
            }
            val fps = findPreference<ListPreference>("frame_rate")?.value?.toIntOrNull() ?: 60
            val bitrate = findPreference<SeekBarPreference>("bitrate")?.value?.times(1_000_000) ?: 8_000_000
            streamingService?.applySettings(resolution, fps, bitrate)
            true
        }

        // Frame rate
        findPreference<ListPreference>("frame_rate")?.setOnPreferenceChangeListener { _, value ->
            val fps = (value as String).toIntOrNull() ?: 60
            val resStr = findPreference<ListPreference>("resolution")?.value ?: "1080p"
            val resolution = when (resStr) {
                "720p" -> CameraManager.Resolution.RES_720P
                "4K" -> CameraManager.Resolution.RES_4K
                else -> CameraManager.Resolution.RES_1080P
            }
            val bitrate = findPreference<SeekBarPreference>("bitrate")?.value?.times(1_000_000) ?: 8_000_000
            streamingService?.applySettings(resolution, fps, bitrate)
            true
        }

        // Keep screen on
        findPreference<SwitchPreferenceCompat>("keep_screen_on")?.setOnPreferenceChangeListener { _, value ->
            activity?.window?.let { window ->
                if (value as Boolean) {
                    window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
            }
            true
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        if (serviceBound) {
            requireContext().unbindService(serviceConnection)
            serviceBound = false
        }
    }
}
