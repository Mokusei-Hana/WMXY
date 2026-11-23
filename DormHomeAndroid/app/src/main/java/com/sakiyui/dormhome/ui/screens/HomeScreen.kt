package com.sakiyui.dormhome.ui.screens

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.material.icons.rounded.Battery4Bar
import androidx.compose.material.icons.rounded.BatteryAlert
import androidx.compose.material.icons.rounded.BatteryFull
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.DoorFront
import androidx.compose.material.icons.rounded.GridView
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.LockOpen
import androidx.compose.material.icons.rounded.PersonAddAlt1
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.SyncLock
import androidx.compose.material.icons.rounded.UnfoldMore
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sakiyui.dormhome.core.modules.DormServiceModule
import com.sakiyui.dormhome.core.modules.ModuleRegistry
import com.sakiyui.dormhome.core.network.DoorDevice
import com.sakiyui.dormhome.core.storage.PersistedState
import com.sakiyui.dormhome.core.viewmodel.AppTab
import com.sakiyui.dormhome.core.viewmodel.AppUiState
import com.sakiyui.dormhome.core.viewmodel.DoorVisualState
import com.sakiyui.dormhome.core.viewmodel.DormAppViewModel
import com.sakiyui.dormhome.ui.components.DormCard
import com.sakiyui.dormhome.ui.components.SectionHeader
import com.sakiyui.dormhome.ui.theme.DormTheme
import java.time.LocalTime

@Composable
fun HomeScreen(
    persisted: PersistedState,
    ui: AppUiState,
    viewModel: DormAppViewModel,
    onOpenModule: (DormServiceModule) -> Unit,
    bottomContentPadding: PaddingValues
) {
    val colors = DormTheme.colors
    val haptics = LocalHapticFeedback.current
    val enabledModules = remember(persisted.enabledModuleIDs) {
        ModuleRegistry.enabled(persisted.enabledModuleIDs)
    }

    val greeting = remember {
        when (LocalTime.now().hour) {
            in 5..8 -> "早上好"
            in 9..11 -> "上午好"
            in 12..13 -> "中午好"
            in 14..17 -> "下午好"
            in 18..22 -> "晚上好"
            else -> "夜深了"
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .padding(top = 12.dp, bottom = bottomContentPadding.calculateBottomPadding() + 24.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        // 顶部问候与账户胶囊
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "$greeting · ${persisted.roomName}",
                    color = colors.textSecondary,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = "宿享",
                    color = colors.textPrimary,
                    fontSize = 30.sp,
                    fontWeight = FontWeight.Bold
                )
            }
            Spacer(Modifier.width(12.dp))
            AccountStatusPill(
                persisted = persisted,
                onClick = { viewModel.openLogin() }
            )
        }

        // 门锁主控卡片
        DoorHeroCard(
            persisted = persisted,
            ui = ui,
            device = viewModel.selectedDevice(persisted),
            onOpenLogin = {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                viewModel.openLogin()
            },
            onRefresh = { viewModel.refreshDevices() },
            onSelectDevice = { viewModel.selectDevice(it) },
            onToggleDoor = {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                viewModel.toggleDoor()
            },
            onUnlock = {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                viewModel.unlock()
            },
            onLock = {
                haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                viewModel.lock(auto = false)
            }
        )

        // 生活服务 Bento 网格
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            SectionHeader(
                title = "生活服务",
                actionText = "全部 ›",
                onActionClick = { viewModel.selectTab(AppTab.LIFE) }
            )

            if (enabledModules.isEmpty()) {
                DormCard(modifier = Modifier.fillMaxWidth(), cornerRadius = 24.dp) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 28.dp, horizontal = 16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.GridView,
                            contentDescription = null,
                            tint = colors.textSecondary,
                            modifier = Modifier.size(26.dp)
                        )
                        Text(
                            text = "生活服务模块均已关闭",
                            color = colors.textPrimary,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            text = "可在「设置 · 生活服务」中重新开启",
                            color = colors.textSecondary,
                            fontSize = 12.sp
                        )
                    }
                }
            } else {
                ServiceBentoGrid(
                    modules = enabledModules,
                    persisted = persisted,
                    viewModel = viewModel,
                    onOpenModule = onOpenModule
                )
            }
        }
    }
}

@Composable
private fun AccountStatusPill(
    persisted: PersistedState,
    onClick: () -> Unit
) {
    val colors = DormTheme.colors
    Surface(
        modifier = Modifier
            .clip(CircleShape)
            .clickable(onClick = onClick),
        shape = CircleShape,
        color = colors.surfaceElevated,
        border = BorderStroke(0.8.dp, colors.cardBorder)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 13.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            when {
                persisted.isLoggedIn -> {
                    Box(
                        modifier = Modifier
                            .size(7.dp)
                            .clip(CircleShape)
                            .background(colors.onlineGreen)
                    )
                    Text(
                        text = persisted.userName ?: "已连接",
                        color = colors.textPrimary,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1
                    )
                }
                persisted.isDemoMode -> {
                    Box(
                        modifier = Modifier
                            .size(7.dp)
                            .clip(CircleShape)
                            .background(colors.warningAmber)
                    )
                    Text(
                        text = "演示模式",
                        color = colors.textPrimary,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
                else -> {
                    Icon(
                        imageVector = Icons.Rounded.PersonAddAlt1,
                        contentDescription = null,
                        tint = colors.actionBlue,
                        modifier = Modifier.size(14.dp)
                    )
                    Text(
                        text = "登录",
                        color = colors.actionBlue,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
            Icon(
                imageVector = Icons.Rounded.ChevronRight,
                contentDescription = null,
                tint = colors.textTertiary,
                modifier = Modifier.size(14.dp)
            )
        }
    }
}

@Composable
private fun DoorHeroCard(
    persisted: PersistedState,
    ui: AppUiState,
    device: DoorDevice?,
    onOpenLogin: () -> Unit,
    onRefresh: () -> Unit,
    onSelectDevice: (DoorDevice) -> Unit,
    onToggleDoor: () -> Unit,
    onUnlock: () -> Unit,
    onLock: () -> Unit
) {
    val colors = DormTheme.colors
    val accent by animateColorAsState(colors.accentFor(ui.doorState), tween(400), label = "doorAccent")

    DormCard(
        modifier = Modifier.fillMaxWidth(),
        cornerRadius = 32.dp,
        elevated = true
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            when {
                !persisted.isLoggedIn && !persisted.isDemoMode -> {
                    // 未登录引导态
                    Box(
                        modifier = Modifier.size(104.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Box(
                            modifier = Modifier
                                .size(104.dp)
                                .clip(CircleShape)
                                .background(
                                    Brush.radialGradient(
                                        listOf(colors.actionBlue.copy(alpha = 0.22f), Color.Transparent)
                                    )
                                )
                        )
                        Surface(
                            modifier = Modifier.size(76.dp),
                            shape = CircleShape,
                            color = colors.actionBlue.copy(alpha = 0.14f),
                            border = BorderStroke(1.dp, colors.actionBlue.copy(alpha = 0.25f))
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(
                                    imageVector = Icons.Rounded.DoorFront,
                                    contentDescription = null,
                                    tint = colors.actionBlue,
                                    modifier = Modifier.size(36.dp)
                                )
                            }
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                    Text(
                        text = "连接完美校园",
                        color = colors.textPrimary,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        text = "登录后即可远程开锁与查看宿舍水电",
                        color = colors.textSecondary,
                        fontSize = 13.sp,
                        textAlign = TextAlign.Center
                    )
                    Spacer(Modifier.height(18.dp))
                    Button(
                        onClick = onOpenLogin,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(50.dp),
                        shape = RoundedCornerShape(18.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = colors.actionBlue)
                    ) {
                        Text("登录账号", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                    }
                }

                device == null -> {
                    // 已登录但暂无门锁
                    Surface(
                        modifier = Modifier.size(72.dp),
                        shape = CircleShape,
                        color = colors.surfaceSubtle
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = Icons.Rounded.Lock,
                                contentDescription = null,
                                tint = colors.textSecondary,
                                modifier = Modifier.size(32.dp)
                            )
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                    Text(
                        text = "暂无可用门锁",
                        color = colors.textPrimary,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = "轻点下方按钮重新同步门锁列表",
                        color = colors.textSecondary,
                        fontSize = 12.sp
                    )
                    Spacer(Modifier.height(16.dp))
                    Button(
                        onClick = onRefresh,
                        enabled = !ui.isRefreshing,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(48.dp),
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = colors.actionBlue)
                    ) {
                        if (ui.isRefreshing) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(16.dp),
                                strokeWidth = 2.dp,
                                color = Color.White
                            )
                            Spacer(Modifier.width(8.dp))
                        }
                        Text(
                            text = if (ui.isRefreshing) "正在同步…" else "同步门锁",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }

                else -> {
                    // 正常门锁控制态
                    var menuExpanded by remember { mutableStateOf(false) }

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.Top,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier
                                    .clip(RoundedCornerShape(8.dp))
                                    .then(
                                        if (persisted.activeDevices.size > 1) {
                                            Modifier.clickable { menuExpanded = true }
                                        } else {
                                            Modifier
                                        }
                                    )
                            ) {
                                Text(
                                    text = device.name,
                                    color = colors.textPrimary,
                                    fontSize = 20.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                                if (persisted.activeDevices.size > 1) {
                                    Spacer(Modifier.width(4.dp))
                                    Icon(
                                        imageVector = Icons.Rounded.UnfoldMore,
                                        contentDescription = "切换门锁",
                                        tint = colors.textSecondary,
                                        modifier = Modifier.size(18.dp)
                                    )
                                    DropdownMenu(
                                        expanded = menuExpanded,
                                        onDismissRequest = { menuExpanded = false }
                                    ) {
                                        persisted.activeDevices.forEach { item ->
                                            DropdownMenuItem(
                                                text = {
                                                    Text(
                                                        text = item.name,
                                                        fontWeight = if (item.deviceId == device.deviceId) {
                                                            FontWeight.Bold
                                                        } else {
                                                            FontWeight.Normal
                                                        }
                                                    )
                                                },
                                                onClick = {
                                                    menuExpanded = false
                                                    onSelectDevice(item)
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                            Spacer(Modifier.height(6.dp))
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(6.dp)
                                        .clip(CircleShape)
                                        .background(if (device.isOnline) colors.onlineGreen else colors.dangerRed)
                                )
                                Text(
                                    text = if (device.isOnline) "在线" else "离线",
                                    color = colors.textSecondary,
                                    fontSize = 12.sp
                                )
                                device.battery?.let { bat ->
                                    Text("·", color = colors.textTertiary, fontSize = 12.sp)
                                    Icon(
                                        imageVector = when {
                                            bat >= 75 -> Icons.Rounded.BatteryFull
                                            bat >= 25 -> Icons.Rounded.Battery4Bar
                                            else -> Icons.Rounded.BatteryAlert
                                        },
                                        contentDescription = null,
                                        tint = if (bat < 20) colors.warningAmber else colors.textSecondary,
                                        modifier = Modifier.size(14.dp)
                                    )
                                    Text(
                                        text = "$bat%",
                                        color = colors.textSecondary,
                                        fontSize = 12.sp
                                    )
                                }
                            }
                        }

                        Surface(
                            modifier = Modifier
                                .size(38.dp)
                                .clip(CircleShape)
                                .clickable(enabled = !ui.isBusy && !ui.isRefreshing, onClick = onRefresh),
                            shape = CircleShape,
                            color = colors.surfaceSubtle,
                            border = BorderStroke(0.6.dp, colors.cardBorder)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                if (ui.isRefreshing) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(16.dp),
                                        strokeWidth = 2.dp,
                                        color = colors.actionBlue
                                    )
                                } else {
                                    Icon(
                                        imageVector = Icons.Rounded.Refresh,
                                        contentDescription = "刷新门锁",
                                        tint = colors.textPrimary,
                                        modifier = Modifier.size(18.dp)
                                    )
                                }
                            }
                        }
                    }

                    Spacer(Modifier.height(16.dp))

                    // 核心交互锁芯圆盘
                    val totalSec = maxOf(1, persisted.autoRelockSeconds)
                    val progress = ui.unlockCountdown?.let { 1f - it.toFloat() / totalSec.toFloat() } ?: 0f
                    val statusLabel = when (ui.doorState) {
                        DoorVisualState.LOCKED -> "轻触开锁"
                        DoorVisualState.UNLOCKING -> "开锁中…"
                        DoorVisualState.UNLOCKED -> ui.unlockCountdown?.let { "已开锁 · ${it}s" } ?: "已开锁"
                    }

                    TactileLockDial(
                        doorState = ui.doorState,
                        accent = accent,
                        statusLabel = statusLabel,
                        relockProgress = progress,
                        enabled = !(ui.isBusy && ui.doorState == DoorVisualState.UNLOCKING),
                        onClick = onToggleDoor
                    )

                    Spacer(Modifier.height(18.dp))

                    // 双控操作条
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Button(
                            onClick = onUnlock,
                            enabled = !ui.isBusy && ui.doorState != DoorVisualState.UNLOCKING,
                            modifier = Modifier
                                .weight(1.55f)
                                .height(50.dp),
                            shape = RoundedCornerShape(18.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = accent)
                        ) {
                            Icon(
                                imageVector = Icons.Rounded.LockOpen,
                                contentDescription = null,
                                modifier = Modifier.size(18.dp)
                            )
                            Spacer(Modifier.width(6.dp))
                            Text(
                                text = if (ui.doorState == DoorVisualState.UNLOCKED) "重新开锁" else "远程开锁",
                                fontSize = 15.sp,
                                fontWeight = FontWeight.SemiBold,
                                maxLines = 1
                            )
                        }

                        FilledTonalButton(
                            onClick = onLock,
                            enabled = !ui.isBusy && ui.doorState != DoorVisualState.LOCKED,
                            modifier = Modifier
                                .weight(1f)
                                .height(50.dp),
                            shape = RoundedCornerShape(18.dp),
                            colors = ButtonDefaults.filledTonalButtonColors(
                                containerColor = if (colors.isDark) Color(0xFF222E44) else colors.surfaceSubtle,
                                contentColor = colors.textPrimary,
                                disabledContainerColor = if (colors.isDark) Color(0xFF172033) else Color(0xFFE9EEF5),
                                disabledContentColor = colors.textTertiary
                            )
                        ) {
                            Icon(
                                imageVector = Icons.Rounded.Lock,
                                contentDescription = null,
                                modifier = Modifier.size(17.dp)
                            )
                            Spacer(Modifier.width(5.dp))
                            Text("上锁", fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                        }
                    }

                    val micro = ui.lastOperationText ?: if (persisted.isDemoMode) "演示模式 · 仅模拟开锁" else null
                    if (!micro.isNullOrEmpty()) {
                        Spacer(Modifier.height(12.dp))
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(5.dp)
                                    .clip(CircleShape)
                                    .background(accent)
                            )
                            Text(
                                text = micro,
                                color = colors.textSecondary,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TactileLockDial(
    doorState: DoorVisualState,
    accent: Color,
    statusLabel: String,
    relockProgress: Float,
    enabled: Boolean,
    onClick: () -> Unit
) {
    val colors = DormTheme.colors
    val infinite = rememberInfiniteTransition(label = "lockDial")

    val breathScale by infinite.animateFloat(
        initialValue = 0.985f,
        targetValue = 1.02f,
        animationSpec = infiniteRepeatable(tween(2400, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "breath"
    )
    val scanAngle by infinite.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(tween(1400, easing = LinearEasing)),
        label = "scan"
    )
    val ripplePhase by infinite.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(2400, easing = LinearEasing)),
        label = "ripple"
    )
    val animatedProgress by animateFloatAsState(
        targetValue = relockProgress.coerceIn(0f, 1f),
        animationSpec = tween(250),
        label = "relockProgress"
    )

    Box(
        modifier = Modifier.size(184.dp),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val center = Offset(size.width / 2f, size.height / 2f)
            val outerR = size.minDimension / 2f

            // 柔和环境光晕
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(accent.copy(alpha = 0.26f), accent.copy(alpha = 0.04f), Color.Transparent),
                    center = center,
                    radius = outerR
                ),
                radius = outerR,
                center = center
            )

            // 静态外环
            drawCircle(
                color = accent.copy(alpha = 0.16f),
                radius = outerR - 8.dp.toPx(),
                center = center,
                style = Stroke(width = 1.dp.toPx())
            )

            when (doorState) {
                DoorVisualState.LOCKED -> {
                    drawCircle(
                        color = accent.copy(alpha = 0.14f),
                        radius = (outerR - 14.dp.toPx()) * breathScale,
                        center = center,
                        style = Stroke(width = 1.5.dp.toPx())
                    )
                }
                DoorVisualState.UNLOCKING -> {
                    val arcInset = 10.dp.toPx()
                    val arcSize = Size(size.width - arcInset * 2, size.height - arcInset * 2)
                    drawCircle(
                        color = accent.copy(alpha = 0.12f),
                        radius = arcSize.width / 2f,
                        center = center,
                        style = Stroke(width = 3.dp.toPx())
                    )
                    drawArc(
                        color = accent,
                        startAngle = scanAngle,
                        sweepAngle = 86f,
                        useCenter = false,
                        topLeft = Offset(arcInset, arcInset),
                        size = arcSize,
                        style = Stroke(width = 3.5.dp.toPx(), cap = StrokeCap.Round)
                    )
                }
                DoorVisualState.UNLOCKED -> {
                    val arcInset = 8.dp.toPx()
                    val arcSize = Size(size.width - arcInset * 2, size.height - arcInset * 2)
                    drawCircle(
                        color = accent.copy(alpha = 0.14f),
                        radius = arcSize.width / 2f,
                        center = center,
                        style = Stroke(width = 3.5.dp.toPx())
                    )
                    drawArc(
                        color = accent,
                        startAngle = -90f,
                        sweepAngle = 360f * animatedProgress,
                        useCenter = false,
                        topLeft = Offset(arcInset, arcInset),
                        size = arcSize,
                        style = Stroke(width = 3.5.dp.toPx(), cap = StrokeCap.Round)
                    )
                    // 脉冲扩散圈
                    val rippleR = (outerR - 22.dp.toPx()) + 16.dp.toPx() * ripplePhase
                    drawCircle(
                        color = accent.copy(alpha = 0.24f * (1f - ripplePhase)),
                        radius = rippleR,
                        center = center,
                        style = Stroke(width = 1.5.dp.toPx())
                    )
                }
            }
        }

        // 中央可点按圆形按钮
        Surface(
            modifier = Modifier
                .size(138.dp)
                .clip(CircleShape)
                .clickable(enabled = enabled, onClick = onClick),
            shape = CircleShape,
            color = colors.surfaceElevated,
            border = BorderStroke(1.2.dp, accent.copy(alpha = 0.34f)),
            shadowElevation = if (colors.isDark) 4.dp else 8.dp
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.radialGradient(
                            colors = listOf(accent.copy(alpha = 0.18f), Color.Transparent)
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Icon(
                        imageVector = when (doorState) {
                            DoorVisualState.LOCKED -> Icons.Rounded.Lock
                            DoorVisualState.UNLOCKING -> Icons.Rounded.SyncLock
                            DoorVisualState.UNLOCKED -> Icons.Rounded.LockOpen
                        },
                        contentDescription = statusLabel,
                        tint = accent,
                        modifier = Modifier.size(42.dp)
                    )
                    Text(
                        text = statusLabel,
                        color = colors.textPrimary,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1
                    )
                }
            }
        }
    }
}

@Composable
fun ServiceBentoGrid(
    modules: List<DormServiceModule>,
    persisted: PersistedState,
    viewModel: DormAppViewModel,
    onOpenModule: (DormServiceModule) -> Unit
) {
    val rows = modules.chunked(2)
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        rows.forEach { rowItems ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                rowItems.forEach { module ->
                    ServiceTileCard(
                        module = module,
                        value = viewModel.valueFor(module, persisted),
                        detail = viewModel.detailFor(module, persisted),
                        onClick = { onOpenModule(module) },
                        modifier = Modifier.weight(1f)
                    )
                }
                if (rowItems.size == 1) {
                    Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun ServiceTileCard(
    module: DormServiceModule,
    value: String,
    detail: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = DormTheme.colors
    val tint = module.accent(colors.isDark)

    DormCard(
        modifier = modifier.height(126.dp),
        cornerRadius = 24.dp,
        onClick = onClick
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Surface(
                    modifier = Modifier.size(36.dp),
                    shape = RoundedCornerShape(12.dp),
                    color = tint.copy(alpha = 0.16f),
                    border = BorderStroke(0.6.dp, tint.copy(alpha = 0.2f))
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = module.icon,
                            contentDescription = null,
                            tint = tint,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }

                if (module.badge != null) {
                    Surface(
                        shape = CircleShape,
                        color = colors.surfaceSubtle
                    ) {
                        Text(
                            text = module.badge,
                            color = colors.textSecondary,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.padding(horizontal = 7.dp, vertical = 3.dp)
                        )
                    }
                } else {
                    Icon(
                        imageVector = Icons.Rounded.ChevronRight,
                        contentDescription = null,
                        tint = colors.textTertiary,
                        modifier = Modifier.size(16.dp)
                    )
                }
            }

            Column {
                Text(
                    text = value,
                    color = colors.textPrimary,
                    fontSize = 21.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = "${module.title} · $detail",
                    color = colors.textSecondary,
                    fontSize = 12.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}
