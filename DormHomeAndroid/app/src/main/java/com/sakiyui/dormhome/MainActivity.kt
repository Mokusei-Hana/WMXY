package com.sakiyui.dormhome

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import com.sakiyui.dormhome.core.viewmodel.DormAppViewModel
import com.sakiyui.dormhome.ui.DormHomeRoot

class MainActivity : ComponentActivity() {
    private val viewModel: DormAppViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            DormHomeRoot(viewModel = viewModel)
        }
    }
}
