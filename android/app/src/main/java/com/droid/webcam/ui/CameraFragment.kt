package com.droid.webcam.ui

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.IBinder
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.navigation.fragment.findNavController
import com.droid.webcam.databinding.FragmentCameraBinding
import com.droid.webcam.streaming.StreamingService

/**
 * Camera view shown while streaming is active.
 * Shows live camera preview, flip button, resolution selector, and disconnect.
 */
class CameraFragment : Fragment() {

    private var _binding: FragmentCameraBinding? = null
    private val binding get() = _binding!!

    private var streamingService: StreamingService? = null
    private var serviceBound = false

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            streamingService = (binder as StreamingService.LocalBinder).getService()
            serviceBound = true
            updateUI()

            streamingService?.statusListener = object : StreamingService.StatusListener {
                override fun onConnectionChanged(
                    mode: StreamingService.ConnectionMode,
                    connectedHost: String?
                ) {
                    activity?.runOnUiThread { updateUI() }
                }
                override fun onError(message: String) {
                    activity?.runOnUiThread {
                        binding.textConnectionStatus.text = "Error: $message"
                    }
                }
            }
        }

        override fun onServiceDisconnected(name: ComponentName) {
            streamingService = null
            serviceBound = false
        }
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentCameraBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        val serviceIntent = Intent(requireContext(), StreamingService::class.java)
        requireContext().bindService(serviceIntent, serviceConnection, Context.BIND_AUTO_CREATE)

        // Flip camera
        binding.btnFlipCamera.setOnClickListener {
            streamingService?.flipCamera()
        }

        // Disconnect
        binding.btnDisconnect.setOnClickListener {
            streamingService?.stopStreaming()
            findNavController().navigateUp()
        }

        // Settings
        binding.btnSettingsGear.setOnClickListener {
            findNavController().navigate(
                com.droid.webcam.R.id.action_camera_to_settings
            )
        }

        // Resolution selector
        binding.chipGroup.setOnCheckedStateChangeListener { group, checkedIds ->
            val resolution = when (checkedIds.firstOrNull()) {
                com.droid.webcam.R.id.chip720p ->
                    com.droid.webcam.camera.CameraManager.Resolution.RES_720P
                com.droid.webcam.R.id.chip4k ->
                    com.droid.webcam.camera.CameraManager.Resolution.RES_4K
                else ->
                    com.droid.webcam.camera.CameraManager.Resolution.RES_1080P
            }
            streamingService?.applySettings(resolution, 60, 8_000_000)
        }
    }

    private fun updateUI() {
        val service = streamingService ?: return
        val mode = service.connectionMode
        binding.textConnectionStatus.text = when (mode) {
            StreamingService.ConnectionMode.USB -> "🔴 Live — USB"
            StreamingService.ConnectionMode.WIFI -> "🔴 Live — WiFi"
            StreamingService.ConnectionMode.NONE -> "Not streaming"
        }
        binding.btnDisconnect.isEnabled = service.isStreaming
    }

    override fun onDestroyView() {
        super.onDestroyView()
        streamingService?.statusListener = null
        if (serviceBound) {
            requireContext().unbindService(serviceConnection)
            serviceBound = false
        }
        _binding = null
    }
}
