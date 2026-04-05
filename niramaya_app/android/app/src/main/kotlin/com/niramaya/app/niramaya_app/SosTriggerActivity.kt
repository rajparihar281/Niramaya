package com.niramaya.app.niramaya_app

import android.content.Intent
import android.os.Bundle
import android.os.SystemClock
import androidx.appcompat.app.AppCompatActivity

class SosTriggerActivity : AppCompatActivity() {

    companion object {
        private var lastTriggerMs = 0L
        private const val DOUBLE_TAP_GUARD_MS = 2000L
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val now = SystemClock.elapsedRealtime()
        if (now - lastTriggerMs < DOUBLE_TAP_GUARD_MS) {
            // Double-tap within 2s — ignore
            finish()
            return
        }
        lastTriggerMs = now

        val intent = Intent(this, MainActivity::class.java).apply {
            putExtra("is_hardware_trigger", true)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        startActivity(intent)
        finish()
    }
}
