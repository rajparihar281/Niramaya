package com.niramaya.app.niramaya_app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class SosTriggerActivity : FlutterActivity() {
    override fun getInitialRoute(): String {
        return "/sos-trigger"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // No custom theme logic here to keep it lean,
        // UI is fully handled by Flutter side in /sos-trigger
    }
}
