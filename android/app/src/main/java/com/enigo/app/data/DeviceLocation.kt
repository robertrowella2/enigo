package com.enigo.app.data

import android.annotation.SuppressLint
import android.content.Context
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import kotlinx.coroutines.suspendCancellableCoroutine

/** One-shot location fetch for the "Share my rough location" toggle —
 * Enigo never tracks location continuously. Caller must already hold
 * ACCESS_COARSE_LOCATION before calling this. */
object DeviceLocation {
    @SuppressLint("MissingPermission")
    suspend fun getCurrentCoordinates(context: Context): Pair<Double, Double>? {
        val client = LocationServices.getFusedLocationProviderClient(context)
        val cancellationTokenSource = CancellationTokenSource()
        return suspendCancellableCoroutine { continuation ->
            client.getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, cancellationTokenSource.token)
                .addOnSuccessListener { location ->
                    continuation.resumeWith(Result.success(location?.let { it.latitude to it.longitude }))
                }
                .addOnFailureListener {
                    continuation.resumeWith(Result.success(null))
                }
            continuation.invokeOnCancellation { cancellationTokenSource.cancel() }
        }
    }
}
