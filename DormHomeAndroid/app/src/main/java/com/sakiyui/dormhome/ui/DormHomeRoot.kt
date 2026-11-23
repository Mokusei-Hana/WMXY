package com.sakiyui.dormhome.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.GridView
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sakiyui.dormhome.core.modules.ServiceModuleKind
import com.sakiyui.dormhome.core.viewmodel.AppTab
import com.sakiyui.dormhome.core.viewmodel.DormAppViewModel
import com.sakiyui.dormhome.ui.components.AtmosphericBackground
import com.sakiyui.dormhome.ui.components.DormToastBanner
import com.sakiyui.dormhome.ui.screens.CampusCardScreen
import com.sakiyui.dormhome.ui.screens.ClimateControlScreen
import com.sakiyui.dormhome.ui.screens.HomeScreen
import com.sakiyui.dormhome.ui.screens.LifeScreen
import com.sakiyui.dormhome.ui.screens.LoginSheet
import com.sakiyui.dormhome.ui.screens.SettingsScreen
import com.sakiyui.dormhome.ui.screens.UnlockHistoryScreen
import com.sakiyui.dormhome.ui.screens.UtilitiesScreen
import com.sakiyui.dormhome.ui.theme.DormHomeTheme
import com.sakiyui.dormhome.ui.theme.DormTheme

@Composable
fun DormHomeRoot(viewModel: DormAppViewModel) {
    val persisted by viewModel.persistedState.collectAsState()
    val ui by viewModel.ui.collectAsState()
    var activeSecondary by remember { mutableStateOf<ServiceModuleKind?>(null) }

    BackHandler(enabled = activeSecondary != null) {
        activeSecondary = null
    }

    DormHomeTheme(themeMode = persisted.themeMode) {
        val colors = DormTheme.colors
        Box(modifier = Modifier.fillMaxSize()) {
            AtmosphericBackground(doorState = ui.doorState)

            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .statusBarsPadding()
            ) {
                val navBottomPadding = PaddingValues(bottom = 92.dp)

                if (activeSecondary != null) {
                    when (activeSecondary) {
                        ServiceModuleKind.UTILITIES -> UtilitiesScreen(
                            persisted = persisted,
                            ui = ui,
                            viewModel = viewModel,
                            onBack = { activeSecondary = null }
                        )
                        ServiceModuleKind.HISTORY -> UnlockHistoryScreen(
                            persisted = persisted,
                            viewModel = viewModel,
                            onBack = { activeSecondary = null }
                        )
                        ServiceModuleKind.CLIMATE -> ClimateControlScreen(
                            viewModel = viewModel,
                            onBack = { activeSecondary = null }
                        )
                        ServiceModuleKind.CAMPUS_CARD -> CampusCardScreen(
                            persisted = persisted,
                            onBack = { activeSecondary = null }
                        )
                        null -> Unit
                    }
                } else {
                    AnimatedContent(
                        targetState = ui.selectedTab,
                        transitionSpec = { fadeIn() togetherWith fadeOut() },
                        label = "tabSwitch"
                    ) { tab ->
                        when (tab) {
                            AppTab.HOME -> HomeScreen(
                                persisted = persisted,
                                ui = ui,
                                viewModel = viewModel,
                                onOpenModule = { activeSecondary = it.kind },
                                bottomContentPadding = navBottomPadding
                            )
                            AppTab.LIFE -> LifeScreen(
                                persisted = persisted,
                                ui = ui,
                                viewModel = viewModel,
                                onOpenModule = { activeSecondary = it.kind },
                                bottomContentPadding = navBottomPadding
                            )
                            AppTab.SETTINGS -> SettingsScreen(
                                persisted = persisted,
                                ui = ui,
                                viewModel = viewModel,
                                bottomContentPadding = navBottomPadding
                            )
                        }
                    }

                    // 悬浮胶囊底部导航栏
                    FloatingBottomNavBar(
                        selectedTab = ui.selectedTab,
                        onSelect = { viewModel.selectTab(it) },
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .navigationBarsPadding()
                            .padding(horizontal = 24.dp, vertical = 14.dp)
                    )
                }

                // 全局顶部 Toast
                AnimatedVisibility(
                    visible = ui.toast != null,
                    enter = slideInVertically { -it } + fadeIn(),
                    exit = slideOutVertically { -it } + fadeOut(),
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(top = 8.dp, start = 20.dp, end = 20.dp)
                ) {
                    ui.toast?.let { toast ->
                        DormToastBanner(toast = toast)
                    }
                }
            }

            // 登录弹窗
            if (ui.showLogin) {
                LoginSheet(
                    persisted = persisted,
                    viewModel = viewModel,
                    onDismiss = { viewModel.dismissLogin() }
                )
            }
        }
    }
}

@Composable
private fun FloatingBottomNavBar(
    selectedTab: AppTab,
    onSelect: (AppTab) -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = DormTheme.colors
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = CircleShape,
        color = colors.surfaceElevated,
        border = BorderStroke(0.8.dp, colors.cardBorder),
        shadowElevation = if (colors.isDark) 8.dp else 12.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 7.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            AppTab.entries.forEach { tab ->
                val selected = tab == selectedTab
                val icon = when (tab) {
                    AppTab.HOME -> Icons.Rounded.Home
                    AppTab.LIFE -> Icons.Rounded.GridView
                    AppTab.SETTINGS -> Icons.Rounded.Settings
                }

                Surface(
                    modifier = Modifier
                        .weight(1f)
                        .clip(CircleShape)
                        .clickable { onSelect(tab) },
                    shape = CircleShape,
                    color = if (selected) colors.actionBlue.copy(alpha = 0.16f) else Color.Transparent
                ) {
                    Row(
                        modifier = Modifier.padding(vertical = 10.dp),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = icon,
                            contentDescription = tab.title,
                            tint = if (selected) colors.actionBlue else colors.textSecondary,
                            modifier = Modifier.size(20.dp)
                        )
                        Text(
                            text = tab.title,
                            color = if (selected) colors.actionBlue else colors.textSecondary,
                            fontSize = 12.sp,
                            fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                            modifier = Modifier.padding(start = 6.dp)
                        )
                    }
                }
            }
        }
    }
}
