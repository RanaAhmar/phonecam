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
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.findNavController
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.droid.webcam.R
import com.droid.webcam.databinding.FragmentHomeBinding
import com.droid.webcam.databinding.ItemDeviceBinding
import com.droid.webcam.discovery.MdnsDiscovery
import com.droid.webcam.streaming.StreamingService
import kotlinx.coroutines.launch

/**
 * Home screen — shows discovered Mac devices and connection status.
 * Starts the streaming service and navigates to CameraFragment on connect.
 */
class HomeFragment : Fragment() {

    private var _binding: FragmentHomeBinding? = null
    private val binding get() = _binding!!

    private lateinit var mdnsDiscovery: MdnsDiscovery
    private var streamingService: StreamingService? = null
    private var serviceBound = false

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            streamingService = (binder as StreamingService.LocalBinder).getService()
            serviceBound = true
            updateConnectionStatus()
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
        _binding = FragmentHomeBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Bind to streaming service
        val serviceIntent = Intent(requireContext(), StreamingService::class.java)
        requireContext().startForegroundService(serviceIntent)
        requireContext().bindService(serviceIntent, serviceConnection, Context.BIND_AUTO_CREATE)

        // Setup mDNS discovery
        mdnsDiscovery = MdnsDiscovery(requireContext())
        mdnsDiscovery.startRegistration(7878)
        mdnsDiscovery.startDiscovery()

        // Device list
        val adapter = DeviceAdapter { device ->
            // User tapped a Mac device — start WiFi streaming to it
            streamingService?.startWifiStreaming()
            findNavController().navigate(R.id.action_home_to_camera)
        }
        binding.recyclerDevices.layoutManager = LinearLayoutManager(requireContext())
        binding.recyclerDevices.adapter = adapter

        // Observe discovered devices
        viewLifecycleOwner.lifecycleScope.launch {
            mdnsDiscovery.discoveredDevices.collect { devices ->
                adapter.submitList(devices)
                binding.textNoDevices.visibility =
                    if (devices.isEmpty()) View.VISIBLE else View.GONE
            }
        }

        // USB connect button
        binding.btnConnectUsb.setOnClickListener {
            streamingService?.startUsbStreaming()
            findNavController().navigate(R.id.action_home_to_camera)
        }

        // Settings
        binding.btnSettings.setOnClickListener {
            findNavController().navigate(R.id.action_home_to_settings)
        }
    }

    private fun updateConnectionStatus() {
        val mode = streamingService?.connectionMode ?: StreamingService.ConnectionMode.NONE
        binding.textStatus.text = when (mode) {
            StreamingService.ConnectionMode.WIFI -> "Connected via WiFi"
            StreamingService.ConnectionMode.USB -> "Connected via USB"
            StreamingService.ConnectionMode.NONE -> "Not connected"
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        mdnsDiscovery.stop()
        if (serviceBound) {
            requireContext().unbindService(serviceConnection)
            serviceBound = false
        }
        _binding = null
    }

    // ── Device list adapter ───────────────────────────────────────────────────

    inner class DeviceAdapter(
        private val onDeviceClick: (MdnsDiscovery.DiscoveredDevice) -> Unit
    ) : RecyclerView.Adapter<DeviceAdapter.ViewHolder>() {

        private var devices: List<MdnsDiscovery.DiscoveredDevice> = emptyList()

        fun submitList(list: List<MdnsDiscovery.DiscoveredDevice>) {
            devices = list
            notifyDataSetChanged()
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val binding = ItemDeviceBinding.inflate(
                LayoutInflater.from(parent.context), parent, false
            )
            return ViewHolder(binding)
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            holder.bind(devices[position])
        }

        override fun getItemCount() = devices.size

        inner class ViewHolder(private val b: ItemDeviceBinding) :
            RecyclerView.ViewHolder(b.root) {
            fun bind(device: MdnsDiscovery.DiscoveredDevice) {
                b.textDeviceName.text = device.name
                b.textDeviceHost.text = device.host
                b.root.setOnClickListener { onDeviceClick(device) }
            }
        }
    }
}
