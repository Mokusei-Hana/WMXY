package com.sakiyui.dormhome.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Logout
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.BrightnessAuto
import androidx.compose.material.icons.rounded.DarkMode
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.DoorFront
import androidx.compose.material.icons.rounded.Key
import androidx.compose.material.icons.rounded.LightMode
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sakiyui.dormhome.BuildConfig
import com.sakiyui.dormhome.core.modules.ModuleRegistry
import com.sakiyui.dormhome.core.storage.PersistedState
import com.sakiyui.dormhome.core.storage.ThemeMode
import com.sakiyui.dormhome.core.viewmodel.AppUiState
import com.sakiyui.dormhome.core.viewmodel.DormAppViewModel
import com.sakiyui.dormhome.ui.components.DormCard
import com.sakiyui.dormhome.ui.theme.DormTheme

@Composable
fun SettingsScreen(
    persisted: PersistedState,
    ui: AppUiState,
    viewModel: DormAppViewModel,
    bottomContentPadding: PaddingValues
) {
    val colors = DormTheme.colors
    var showSignOutDialog by remember { mutableStateOf(false) }
    var showClearHistoryDialog by remember { mutableStateOf(false) }

    val statusDotColor = when {
        persisted.isLoggedIn -> colors.onlineGreen
        persisted.isDemoMode -> colors.warningAmber
        else -> colors.textTertiary
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .padding(top = 12.dp, bottom = bottomContentPadding.calculateBottomPadding() + 24.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        // 顶部栏
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text("设置", color = colors.textPrimary, fontSize = 30.sp, fontWeight = FontWeight.Bold)
            Surface(
                shape = CircleShape,
                color = colors.surfaceElevated,
                border = BorderStroke(0.8.dp, colors.cardBorder)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 11.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Box(Modifier.size(6.dp).clip(CircleShape).background(statusDotColor))
                    Text(persisted.sessionStatusText, color = colors.textSecondary, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }

        // 账号卡片
        DormCard(modifier = Modifier.fillMaxWidth(), cornerRadius = 24.dp, elevated = true) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(13.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .clip(CircleShape)
                        .background(
                            if (persisted.isLoggedIn) {
                                Brush.linearGradient(listOf(colors.actionCyan, colors.actionBlue))
                            } else {
                                Brush.linearGradient(listOf(colors.textTertiary.copy(alpha = 0.4f), colors.textTertiary.copy(alpha = 0.25f)))
                            }
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    if (persisted.isLoggedIn) {
                        Text(
                            text = persisted.userName?.firstOrNull()?.toString() ?: "宿",
                            color = Color.White,
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold
                        )
                    } else {
                        Icon(Icons.Rounded.Person, null, tint = Color.White, modifier = Modifier.size(22.dp))
                    }
                }

                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = if (persisted.isLoggedIn) (persisted.userName ?: "完美校园用户") else "未登录",
                        color = colors.textPrimary,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        text = if (persisted.isLoggedIn) maskPhone(persisted.phone) else "登录完美校园以使用门锁与水电",
                        color = colors.textSecondary,
                        fontSize = 12.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                if (persisted.isLoggedIn) {
                    FilledTonalButton(
                        onClick = { viewModel.openLogin() },
                        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 6.dp),
                        shape = CircleShape
                    ) {
                        Text("切换", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    }
                } else {
                    Button(
                        onClick = { viewModel.openLogin() },
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 6.dp),
                        shape = CircleShape,
                        colors = ButtonDefaults.buttonColors(containerColor = colors.actionBlue)
                    ) {
                        Text("登录", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }

        // 外观设置
        SettingsGroup(title = "外观") {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                ThemeMode.entries.forEach { mode ->
                    val selected = persisted.themeMode == mode
                    val icon = when (mode) {
                        ThemeMode.SYSTEM -> Icons.Rounded.BrightnessAuto
                        ThemeMode.LIGHT -> Icons.Rounded.LightMode
                        ThemeMode.DARK -> Icons.Rounded.DarkMode
                    }
                    Surface(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(14.dp))
                            .clickable { viewModel.setThemeMode(mode) },
                        shape = RoundedCornerShape(14.dp),
                        color = if (selected) colors.actionBlue.copy(alpha = 0.14f) else colors.surfaceSubtle,
                        border = BorderStroke(1.dp, if (selected) colors.actionBlue.copy(alpha = 0.42f) else Color.Transparent)
                    ) {
                        Column(
                            modifier = Modifier.padding(vertical = 11.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(5.dp)
                        ) {
                            Icon(icon, null, tint = if (selected) colors.actionBlue else colors.textSecondary, modifier = Modifier.size(18.dp))
                            Text(
                                text = mode.title,
                                color = if (selected) colors.actionBlue else colors.textSecondary,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }
                }
            }
        }

        // 门锁与体验
        SettingsGroup(title = "门锁与体验") {
            SettingsRow(
                icon = Icons.Rounded.Timer,
                tint = colors.warningAmber,
                title = "自动上锁倒计时",
                subtitle = "开锁后自动恢复上锁状态"
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    StepCircleButton(
                        icon = Icons.Rounded.Remove,
                        enabled = persisted.autoRelockSeconds > 10,
                        onClick = { viewModel.setAutoRelockSeconds(persisted.autoRelockSeconds - 5) }
                    )
                    Text(
                        text = "${persisted.autoRelockSeconds} 秒",
                        color = colors.textPrimary,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    StepCircleButton(
                        icon = Icons.Rounded.Add,
                        enabled = persisted.autoRelockSeconds < 60,
                        onClick = { viewModel.setAutoRelockSeconds(persisted.autoRelockSeconds + 5) }
                    )
                }
            }

            HorizontalDivider(modifier = Modifier.padding(start = 58.dp), color = colors.cardBorder)

            if (persisted.isLoggedIn) {
                SettingsRow(
                    icon = Icons.Rounded.DoorFront,
                    tint = colors.actionBlue,
                    title = "门锁列表",
                    subtitle = "${persisted.devices.size} 把可用门锁"
                ) {
                    FilledTonalButton(
                        onClick = { viewModel.refreshDevices() },
                        enabled = !ui.isRefreshing && !ui.isBusy,
                        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 4.dp),
                        shape = CircleShape
                    ) {
                        if (ui.isRefreshing) {
                            CircularProgressIndicator(modifier = Modifier.size(14.dp), strokeWidth = 2.dp)
                        } else {
                            Text("同步", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            } else {
                SettingsRow(
                    icon = Icons.Rounded.AutoAwesome,
                    tint = colors.waterBlue,
                    title = "演示模式",
                    subtitle = "未登录时预览模拟门锁与水电"
                ) {
                    Switch(
                        checked = persisted.isDemoMode,
                        onCheckedChange = { viewModel.setDemoMode(it) },
                        colors = SwitchDefaults.colors(checkedTrackColor = colors.actionBlue)
                    )
                }
            }
        }

        // 生活服务模块开关
        SettingsGroup(title = "生活服务") {
            ModuleRegistry.all.forEachIndexed { idx, module ->
                val tint = module.accent(colors.isDark)
                val enabled = module.id in persisted.enabledModuleIDs
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 14.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Surface(
                        modifier = Modifier.size(32.dp),
                        shape = CircleShape,
                        color = tint.copy(alpha = 0.14f)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(module.icon, null, tint = tint, modifier = Modifier.size(16.dp))
                        }
                    }

                    Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(module.title, color = colors.textPrimary, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                            module.badge?.let { badge ->
                                Surface(shape = CircleShape, color = colors.surfaceSubtle) {
                                    Text(
                                        badge,
                                        color = colors.textSecondary,
                                        fontSize = 9.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                    )
                                }
                            }
                        }
                        Text(module.subtitle, color = colors.textSecondary, fontSize = 11.sp)
                    }

                    Switch(
                        checked = enabled,
                        onCheckedChange = { viewModel.setModule(module.id, it) },
                        colors = SwitchDefaults.colors(checkedTrackColor = tint)
                    )
                }
                if (idx < ModuleRegistry.all.lastIndex) {
                    HorizontalDivider(modifier = Modifier.padding(start = 58.dp), color = colors.cardBorder)
                }
            }
        }

        // 账号与数据
        SettingsGroup(title = "账号与数据") {
            SettingsRow(
                icon = Icons.Rounded.Key,
                tint = colors.campusPurple,
                title = "记住登录状态",
                subtitle = "免去每次重新输入密码"
            ) {
                Switch(
                    checked = persisted.rememberCredentials,
                    onCheckedChange = { viewModel.setRememberCredentials(it) },
                    colors = SwitchDefaults.colors(checkedTrackColor = colors.campusPurple)
                )
            }

            HorizontalDivider(modifier = Modifier.padding(start = 58.dp), color = colors.cardBorder)

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { showClearHistoryDialog = true }
                    .padding(horizontal = 14.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Surface(
                    modifier = Modifier.size(32.dp),
                    shape = CircleShape,
                    color = colors.dangerRed.copy(alpha = 0.12f)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(Icons.Rounded.DeleteOutline, null, tint = colors.dangerRed, modifier = Modifier.size(16.dp))
                    }
                }
                Text("清除开门记录", color = colors.dangerRed, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                Text("${persisted.visibleHistory.size} 条", color = colors.textTertiary, fontSize = 11.sp)
            }

            if (persisted.isLoggedIn) {
                HorizontalDivider(modifier = Modifier.padding(start = 58.dp), color = colors.cardBorder)

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { showSignOutDialog = true }
                        .padding(horizontal = 14.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Surface(
                        modifier = Modifier.size(32.dp),
                        shape = CircleShape,
                        color = colors.dangerRed.copy(alpha = 0.12f)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(Icons.AutoMirrored.Rounded.Logout, null, tint = colors.dangerRed, modifier = Modifier.size(16.dp))
                        }
                    }
                    Text("退出登录", color = colors.dangerRed, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }

        // 关于卡片
        DormCard(modifier = Modifier.fillMaxWidth(), cornerRadius = 24.dp) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(13.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(13.dp))
                        .background(Brush.linearGradient(listOf(Color(0xFF14203A), Color(0xFF0A1626)))),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Rounded.DoorFront, null, tint = colors.actionCyan, modifier = Modifier.size(22.dp))
                }
                Column {
                    Text("宿享 · DormHome", color = colors.textPrimary, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    Text("版本 ${BuildConfig.VERSION_NAME} · 设备 ${persisted.deviceId.takeLast(8)}", color = colors.textSecondary, fontSize = 11.sp)
                }
            }
        }
    }

    if (showSignOutDialog) {
        AlertDialog(
            onDismissRequest = { showSignOutDialog = false },
            title = { Text("退出当前账号？") },
            text = { Text("退出后会清除本地会话和已保存的登录凭证。") },
            confirmButton = {
                TextButton(onClick = {
                    showSignOutDialog = false
                    viewModel.signOut()
                }) {
                    Text("退出登录", color = colors.dangerRed, fontWeight = FontWeight.SemiBold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showSignOutDialog = false }) { Text("取消") }
            }
        )
    }

    if (showClearHistoryDialog) {
        AlertDialog(
            onDismissRequest = { showClearHistoryDialog = false },
            title = { Text("清除全部开门记录？") },
            text = { Text("此操作不可撤销。") },
            confirmButton = {
                TextButton(onClick = {
                    showClearHistoryDialog = false
                    viewModel.clearHistory()
                }) {
                    Text("清除记录", color = colors.dangerRed, fontWeight = FontWeight.SemiBold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showClearHistoryDialog = false }) { Text("取消") }
            }
        )
    }
}

@Composable
private fun SettingsGroup(
    title: String,
    content: @Composable ColumnScope.() -> Unit
) {
    val colors = DormTheme.colors
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = title,
            color = colors.textSecondary,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(start = 6.dp)
        )
        DormCard(modifier = Modifier.fillMaxWidth(), cornerRadius = 24.dp, content = content)
    }
}

@Composable
private fun SettingsRow(
    icon: ImageVector,
    tint: Color,
    title: String,
    subtitle: String?,
    trailing: @Composable () -> Unit
) {
    val colors = DormTheme.colors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Surface(
            modifier = Modifier.size(32.dp),
            shape = CircleShape,
            color = tint.copy(alpha = 0.14f)
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(icon, null, tint = tint, modifier = Modifier.size(16.dp))
            }
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, color = colors.textPrimary, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            if (!subtitle.isNullOrEmpty()) {
                Text(subtitle, color = colors.textSecondary, fontSize = 11.sp)
            }
        }
        trailing()
    }
}

@Composable
private fun StepCircleButton(
    icon: ImageVector,
    enabled: Boolean,
    onClick: () -> Unit
) {
    val colors = DormTheme.colors
    Surface(
        modifier = Modifier
            .size(28.dp)
            .clip(CircleShape)
            .clickable(enabled = enabled, onClick = onClick),
        shape = CircleShape,
        color = colors.surfaceSubtle
    ) {
        Box(contentAlignment = Alignment.Center) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = if (enabled) colors.textPrimary else colors.textTertiary,
                modifier = Modifier.size(15.dp)
            )
        }
    }
}

private fun maskPhone(phone: String?): String {
    if (phone == null || phone.length != 11) return "已连接完美校园"
    return "${phone.take(3)}****${phone.takeLast(4)}"
}
