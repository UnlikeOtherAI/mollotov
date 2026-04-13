package com.kelpie.browser.network

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.util.Log
import com.kelpie.browser.device.DeviceInfo

class MDNSAdvertiser(
    private val context: Context,
    private val deviceInfo: DeviceInfo,
) {
    private var nsdManager: NsdManager? = null
    private var registrationInFlight = false
    private var shouldBeRegistered = false
    var isRegistered = false
        private set

    private val registrationListener =
        object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(serviceInfo: NsdServiceInfo) {
                registrationInFlight = false
                isRegistered = true
                Log.i("MDNSAdvertiser", "Registered: ${serviceInfo.serviceName}")
            }

            override fun onRegistrationFailed(
                serviceInfo: NsdServiceInfo,
                errorCode: Int,
            ) {
                registrationInFlight = false
                isRegistered = false
                Log.e("MDNSAdvertiser", "Registration failed: $errorCode")
            }

            override fun onServiceUnregistered(serviceInfo: NsdServiceInfo) {
                registrationInFlight = false
                isRegistered = false
                Log.i("MDNSAdvertiser", "Unregistered: ${serviceInfo.serviceName}")
                if (shouldBeRegistered) {
                    registerService()
                }
            }

            override fun onUnregistrationFailed(
                serviceInfo: NsdServiceInfo,
                errorCode: Int,
            ) {
                registrationInFlight = false
                Log.e("MDNSAdvertiser", "Unregistration failed: $errorCode")
            }
        }

    fun ensureRegistered() {
        shouldBeRegistered = true
        if (isRegistered || registrationInFlight) {
            return
        }

        registerService()
    }

    private fun registerService() {
        val serviceInfo =
            NsdServiceInfo().apply {
                serviceName = deviceInfo.name
                serviceType = "_kelpie._tcp"
                port = deviceInfo.port
                setAttribute("id", deviceInfo.id)
                setAttribute("name", deviceInfo.name)
                setAttribute("model", deviceInfo.model)
                setAttribute("platform", "android")
                setAttribute("width", deviceInfo.width.toString())
                setAttribute("height", deviceInfo.height.toString())
                setAttribute("port", deviceInfo.port.toString())
                setAttribute("version", deviceInfo.version)
                setAttribute("engine", "webview")
            }

        registrationInFlight = true
        nsdManager =
            (context.getSystemService(Context.NSD_SERVICE) as NsdManager).also {
                it.registerService(serviceInfo, NsdManager.PROTOCOL_DNS_SD, registrationListener)
            }
    }

    fun unregister() {
        shouldBeRegistered = false
        if (!isRegistered && !registrationInFlight) {
            return
        }

        try {
            nsdManager?.unregisterService(registrationListener)
        } catch (e: Exception) {
            Log.w("MDNSAdvertiser", "Unregister error: ${e.message}")
            registrationInFlight = false
        }
        nsdManager = null
        isRegistered = false
    }
}
