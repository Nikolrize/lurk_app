package com.example.lurk_app

import io.flutter.embedding.android.FlutterActivity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("lurk_messages", "Messages and invitations", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "Chat messages and party invitations"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
