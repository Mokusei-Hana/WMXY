package com.sakiyui.dormhome.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.AcUnit
import androidx.compose.material.icons.rounded.Apartment
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Contactless
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.School
import androidx.compose.material.icons.rounded.Speed
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.UnfoldMore
import androidx.compose.material.icons.rounded.WaterDrop
import androidx.compose.material.icons.rounded.WarningAmber
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sakiyui.dormhome.core.modules.DormServiceModule
import com.sakiyui.dormhome.core.modules.ModuleRegistry
import com.sakiyui.dormhome.core.modules.ServiceModuleKind
import com.sakiyui.dormhome.core.network.SWAEDailyUsage
import com.sakiyui.dormhome.core.network.SWAEMeterDetail
import com.sakiyui.dormhome.core.network.SWAEMeterKind
import com.sakiyui.dormhome.core.network.SWAERoomDetail
import com.sakiyui.dormhome.core.network.formatSwae
import com.sakiyui.dormhome.core.storage.PersistedState
import com.sakiyui.dormhome.core.viewmodel.AppTab
import com.sakiyui.dormhome.core.viewmodel.AppUiState
import com.sakiyui.dormhome.core.viewmodel.DormAppViewModel
import com.sakiyui.dormhome.core.viewmodel.ToastStyle
import com.sakiyui.dormhome.ui.components.DormCard
import com.sakiyui.dormhome.ui.components.SectionHeader
import com.sakiyui.dormhome.ui.theme.DormTheme
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

// MARK: - 生活 Tab

@Composable
fun LifeScreen(
    persisted: PersistedState,
    ui: AppUiState,
    viewModel: DormAppViewModel,
    onOpenModule: (DormServiceModule) -> Unit,
    bottomContentPadding: PaddingValues
) {
    val colors = DormTheme.colors
    val otherModules = remember(persisted.enabledModuleIDs) {
        ModuleRegistry.enabled(persisted.enabledModuleIDs).filter { it.kind != ServiceModuleKind.UTILITIES }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .padding(top = 12.dp, bottom = bottomContentPadding.calculateBottomPadding() + 24.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = persisted.roomName,
                    color = colors.textSecondary,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = "生活",
                    color = colors.textPrimary,
                    fontSize = 30.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            Surface(
                modifier = Modifier
                    .clip(CircleShape)
                    .clickable { viewModel.selectTab(AppTab.SETTINGS) },
                shape = CircleShape,
                color = colors.surfaceElevated,
                border = BorderStroke(0.8.dp, colors.cardBorder)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 13.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(5.dp)
                ) {
                    Icon(Icons.Rounded.Tune, null, tint = colors.textPrimary, modifier = Modifier.size(14.dp))
                    Text("管理", color = colors.textPrimary, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }

        UtilitiesContent(persisted = persisted, ui = ui, viewModel = viewModel)

        if (otherModules.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SectionHeader(title = "更多服务")
                ServiceBentoGrid(
                    modules = otherModules,
                    persisted = persisted,
                    viewModel = viewModel,
                    onOpenModule = onOpenModule
                )
            }
        }
    }
}

// MARK: - 水电费独立二级页

@Composable
fun UtilitiesScreen(
    persisted: PersistedState,
    ui: AppUiState,
    viewModel: DormAppViewModel,
    onBack: () -> Unit
) {
    SecondaryScreenScaffold(title = "水电费", onBack = onBack) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(top = 8.dp, bottom = 36.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            UtilitiesContent(persisted = persisted, ui = ui, viewModel = viewModel)
        }
    }
}

// MARK: - 水电核心内容

@Composable
fun UtilitiesContent(
    persisted: PersistedState,
    ui: AppUiState,
    viewModel: DormAppViewModel
) {
    val colors = DormTheme.colors
    val scope = rememberCoroutineScope()
    var showRoomPicker by remember { mutableStateOf(false) }
    var selectedMeterId by remember { mutableStateOf<String?>(null) }

    val detail = persisted.roomDetail
    val isLive = detail != null
    val isDemoMode = persisted.isDemoMode && detail == null

    LaunchedEffect(detail?.roomVerify) {
        selectedMeterId = null
    }

    val currentRoomName = persisted.selectedRoomName?.takeIf { it.isNotEmpty() }
        ?: detail?.roomFullName?.takeIf { it.isNotEmpty() }
        ?: if (isDemoMode) "3栋 412" else "水电余量"

    val subtitleText = when {
        isLive -> persisted.lastUtilitySyncText
        isDemoMode -> "演示数据"
        else -> "选择宿舍查看余量"
    }

    Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
        // 房间栏
        var roomMenuExpanded by remember { mutableStateOf(false) }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 2.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Box {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .then(
                                if (persisted.boundRooms.size > 1) {
                                    Modifier.clickable { roomMenuExpanded = true }
                                } else {
                                    Modifier
                                }
                            )
                    ) {
                        Text(
                            text = currentRoomName,
                            color = colors.textPrimary,
                            fontSize = 18.sp,
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        if (persisted.boundRooms.size > 1) {
                            Spacer(Modifier.width(4.dp))
                            Icon(
                                imageVector = Icons.Rounded.UnfoldMore,
                                contentDescription = "切换宿舍",
                                tint = colors.textSecondary,
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }

                    DropdownMenu(
                        expanded = roomMenuExpanded,
                        onDismissRequest = { roomMenuExpanded = false }
                    ) {
                        persisted.boundRooms.forEach { room ->
                            DropdownMenuItem(
                                text = { Text(room.roomFullName) },
                                leadingIcon = if (room.roomVerify == persisted.selectedRoomVerify) {
                                    { Icon(Icons.Rounded.Check, null, modifier = Modifier.size(16.dp)) }
                                } else null,
                                onClick = {
                                    roomMenuExpanded = false
                                    viewModel.selectUtilityRoom(room)
                                }
                            )
                        }
                        HorizontalDivider()
                        DropdownMenuItem(
                            text = { Text("选择其他宿舍…") },
                            leadingIcon = { Icon(Icons.Rounded.Apartment, null, modifier = Modifier.size(16.dp)) },
                            onClick = {
                                roomMenuExpanded = false
                                showRoomPicker = true
                            }
                        )
                    }
                }
                Text(
                    text = subtitleText,
                    color = colors.textSecondary,
                    fontSize = 11.sp,
                    maxLines = 1
                )
            }

            Surface(
                modifier = Modifier
                    .clip(CircleShape)
                    .clickable { showRoomPicker = true },
                shape = CircleShape,
                color = colors.surfaceElevated,
                border = BorderStroke(0.8.dp, colors.cardBorder)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(5.dp)
                ) {
                    Icon(Icons.Rounded.Apartment, null, tint = colors.textPrimary, modifier = Modifier.size(14.dp))
                    Text("选房", color = colors.textPrimary, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                }
            }

            if (isLive || persisted.isLoggedIn) {
                Surface(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .clickable(enabled = !ui.isUtilitiesLoading) {
                            scope.launch { viewModel.refreshUtilities(silent = false) }
                        },
                    shape = CircleShape,
                    color = colors.surfaceElevated,
                    border = BorderStroke(0.8.dp, colors.cardBorder)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        if (ui.isUtilitiesLoading) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(15.dp),
                                strokeWidth = 2.dp,
                                color = colors.actionBlue
                            )
                        } else {
                            Icon(Icons.Rounded.Refresh, "刷新水电", tint = colors.textPrimary, modifier = Modifier.size(17.dp))
                        }
                    }
                }
            }
        }

        // 内容区
        if (detail != null) {
            LiveMetersSection(detail)
            LiveUsageSection(
                detail = detail,
                selectedMeterId = selectedMeterId,
                onSelectMeter = { selectedMeterId = it }
            )
            val primary = detail.primaryMeter
            val estDays = primary?.estimatedDays
            if (primary != null && estDays != null && estDays <= 7) {
                LowBalanceCard(detail = detail, meter = primary, days = estDays)
            }

            val cfg = ui.utilityConfig
            val elec = formatPrice(cfg?.electricityUnitPrice ?: 0.65)
            val cold = formatPrice(cfg?.coldWaterUnitPrice ?: 1.5)
            val hot = formatPrice(cfg?.hotWaterUnitPrice ?: 2.5)
            Text(
                text = "电 ${elec}元/度 · 冷水 ${cold}元/吨 · 热水 ${hot}元/吨",
                color = colors.textTertiary,
                fontSize = 11.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth()
            )
        } else if (isDemoMode) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                DemoBalanceCard(
                    title = "电表",
                    value = String.format("%.1f", persisted.electricityKWh),
                    unit = "kWh",
                    caption = "约可用 ${persisted.estimatedElectricityDays} 天",
                    fraction = (persisted.electricityKWh / 100.0).toFloat().coerceIn(0f, 1f),
                    tint = colors.electricYellow,
                    icon = Icons.Rounded.Bolt,
                    modifier = Modifier.weight(1f)
                )
                DemoBalanceCard(
                    title = "水表",
                    value = String.format("%.1f", persisted.waterBalance),
                    unit = "t",
                    caption = "本月用水 3.2 t",
                    fraction = (persisted.waterBalance / 30.0).toFloat().coerceIn(0f, 1f),
                    tint = colors.waterBlue,
                    icon = Icons.Rounded.WaterDrop,
                    modifier = Modifier.weight(1f)
                )
            }

            val demoPoints = remember(persisted.electricityUsage) {
                val zone = ZoneId.systemDefault()
                val mdFmt = DateTimeFormatter.ofPattern("MM-dd", Locale.CHINA)
                val wkFmt = DateTimeFormatter.ofPattern("EEE", Locale.CHINA)
                persisted.electricityUsage.map { pt ->
                    val zdt = Instant.ofEpochMilli(pt.dateMillis).atZone(zone)
                    SWAEDailyUsage(
                        id = pt.id,
                        dateText = zdt.format(mdFmt),
                        weekday = zdt.format(wkFmt),
                        use = pt.kwh
                    )
                }
            }
            UsageChartCard(
                title = "近 7 日用电",
                meterName = "电表",
                points = demoPoints,
                unit = "kWh",
                tint = colors.electricYellow
            )

            RoomPickerPromptCard(onClick = { showRoomPicker = true })
        } else {
            RoomPickerPromptCard(onClick = { showRoomPicker = true })
        }
    }

    if (showRoomPicker) {
        RoomPickerSheet(
            viewModel = viewModel,
            onDismiss = { showRoomPicker = false }
        )
    }
}

@Composable
private fun LiveMetersSection(detail: SWAERoomDetail) {
    val colors = DormTheme.colors
    if (detail.meters.isEmpty()) {
        DormCard(modifier = Modifier.fillMaxWidth(), cornerRadius = 24.dp) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 26.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(Icons.Rounded.Speed, null, tint = colors.textSecondary, modifier = Modifier.size(26.dp))
                Text("暂无表计数据", color = colors.textPrimary, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                Text("可稍后刷新或切换其他宿舍", color = colors.textSecondary, fontSize = 12.sp)
            }
        }
    } else {
        val rows = detail.meters.chunked(2)
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            rows.forEach { row ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    row.forEach { meter ->
                        SWAEMeterCard(
                            title = detail.displayNameFor(meter),
                            meter = meter,
                            kind = detail.kindFor(meter),
                            modifier = Modifier.weight(1f)
                        )
                    }
                    if (row.size == 1) Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun SWAEMeterCard(
    title: String,
    meter: SWAEMeterDetail,
    kind: SWAEMeterKind,
    modifier: Modifier = Modifier
) {
    val colors = DormTheme.colors
    val tint = kind.tintColor()
    val statusColor = if (meter.isOn) colors.onlineGreen else colors.dangerRed

    DormCard(modifier = modifier, cornerRadius = 24.dp) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(15.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Surface(
                    modifier = Modifier.size(32.dp),
                    shape = CircleShape,
                    color = tint.copy(alpha = 0.16f)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(kind.iconVector(), null, tint = tint, modifier = Modifier.size(16.dp))
                    }
                }

                Surface(
                    shape = CircleShape,
                    color = statusColor.copy(alpha = 0.13f)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 7.dp, vertical = 3.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(5.dp)
                                .clip(CircleShape)
                                .background(statusColor)
                        )
                        Text(
                            text = if (meter.isOn) kind.statusOnText else kind.statusOffText,
                            color = statusColor,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }

            Spacer(Modifier.height(10.dp))
            Text(title, color = colors.textSecondary, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
            Spacer(Modifier.height(2.dp))

            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(
                    text = meter.remaining.formatSwae(),
                    color = colors.textPrimary,
                    fontSize = 26.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1
                )
                if (kind.unit.isNotEmpty()) {
                    Text(
                        text = kind.unit,
                        color = colors.textSecondary,
                        fontSize = 11.sp,
                        modifier = Modifier.padding(bottom = 3.dp)
                    )
                }
            }

            Spacer(Modifier.height(6.dp))
            val est = meter.estimatedDays?.let { " · 约 $it 天" } ?: ""
            Text(
                text = "今日 ${meter.todayUse.formatSwae()}${kind.unit}$est",
                color = colors.textSecondary,
                fontSize = 11.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )

            val hasBreakdown = (meter.sumSub ?: 0.0) > 0 || (meter.sumBuy ?: 0.0) > 0
            if (hasBreakdown) {
                HorizontalDivider(
                    modifier = Modifier.padding(vertical = 8.dp),
                    color = colors.cardBorder
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    meter.sumSub?.takeIf { it > 0 }?.let {
                        Text("补贴 ${it.formatSwae()}", color = colors.textTertiary, fontSize = 10.sp)
                    }
                    meter.sumBuy?.takeIf { it > 0 }?.let {
                        Text("自购 ${it.formatSwae()}", color = colors.textTertiary, fontSize = 10.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun LiveUsageSection(
    detail: SWAERoomDetail,
    selectedMeterId: String?,
    onSelectMeter: (String) -> Unit
) {
    val colors = DormTheme.colors
    val activeMeter = selectedMeterId?.let { id -> detail.meters.firstOrNull { it.id == id } }
        ?: detail.meters.firstOrNull { it.weekUseList.isNotEmpty() }
        ?: detail.meters.firstOrNull()

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (detail.meters.size > 1) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                detail.meters.forEach { meter ->
                    val kind = detail.kindFor(meter)
                    val selected = activeMeter?.id == meter.id
                    val tint = kind.tintColor()
                    Surface(
                        modifier = Modifier
                            .clip(CircleShape)
                            .clickable { onSelectMeter(meter.id) },
                        shape = CircleShape,
                        color = if (selected) tint.copy(alpha = 0.16f) else colors.surfaceSubtle,
                        border = BorderStroke(1.dp, if (selected) tint.copy(alpha = 0.42f) else Color.Transparent)
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 7.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(5.dp)
                        ) {
                            Icon(kind.iconVector(), null, tint = if (selected) tint else colors.textSecondary, modifier = Modifier.size(13.dp))
                            Text(
                                text = detail.displayNameFor(meter),
                                color = if (selected) tint else colors.textSecondary,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }
                }
            }
        }

        activeMeter?.let { meter ->
            val kind = detail.kindFor(meter)
            val title = when (kind) {
                SWAEMeterKind.ELECTRICITY, SWAEMeterKind.AIR_CONDITIONER -> "近 7 日用电"
                SWAEMeterKind.COLD_WATER, SWAEMeterKind.HOT_WATER -> "近 7 日用水"
                SWAEMeterKind.OTHER -> "近 7 日用量"
            }
            UsageChartCard(
                title = title,
                meterName = detail.displayNameFor(meter),
                points = meter.weekUseList,
                unit = kind.unit,
                tint = kind.tintColor()
            )
        }
    }
}

@Composable
private fun UsageChartCard(
    title: String,
    meterName: String,
    points: List<SWAEDailyUsage>,
    unit: String,
    tint: Color
) {
    val colors = DormTheme.colors
    val haptics = LocalHapticFeedback.current
    var selectedIdx by remember(points) { mutableStateOf<Int?>(null) }

    val total = remember(points) { points.sumOf { it.use } }
    val avg = remember(points) { if (points.isEmpty()) 0.0 else total / points.size }
    val maxVal = remember(points) { maxOf(1.0, (points.maxOfOrNull { it.use } ?: 1.0) * 1.25) }
    val selected = selectedIdx?.let { points.getOrNull(it) }

    DormCard(modifier = Modifier.fillMaxWidth(), cornerRadius = 24.dp, elevated = true) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Bottom
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(title, color = colors.textPrimary, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(2.dp))
                    if (selected != null) {
                        val label = selected.weekday?.takeIf { it.isNotEmpty() }
                            ?.let { "${selected.shortDateText} · $it" }
                            ?: selected.shortDateText
                        Text(label, color = tint, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    } else {
                        Text(
                            text = if (points.isEmpty()) meterName else "$meterName · 日均 ${avg.formatSwae()} $unit",
                            color = colors.textSecondary,
                            fontSize = 11.sp
                        )
                    }
                }

                Column(horizontalAlignment = Alignment.End) {
                    Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(
                            text = (selected?.use ?: total).formatSwae(),
                            color = if (selected != null) tint else colors.textPrimary,
                            fontSize = 23.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = unit,
                            color = colors.textSecondary,
                            fontSize = 10.sp,
                            modifier = Modifier.padding(bottom = 3.dp)
                        )
                    }
                    Text(
                        text = if (selected != null) "当日用量" else "近 7 日合计",
                        color = colors.textTertiary,
                        fontSize = 10.sp
                    )
                }
            }

            if (points.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(140.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text("暂无近 7 日用量", color = colors.textSecondary, fontSize = 12.sp)
                }
            } else {
                // 可交互平滑曲线图
                Canvas(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(150.dp)
                        .pointerInput(points) {
                            detectTapGestures { offset ->
                                if (points.size > 1) {
                                    val idx = ((offset.x / size.width) * (points.size - 1))
                                        .toInt()
                                        .coerceIn(0, points.lastIndex)
                                    selectedIdx = if (selectedIdx == idx) null else idx
                                    haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                }
                            }
                        }
                        .pointerInput(points) {
                            detectHorizontalDragGestures(
                                onDragEnd = { selectedIdx = null },
                                onDragCancel = { selectedIdx = null }
                            ) { change, _ ->
                                if (points.size > 1) {
                                    val idx = ((change.position.x / size.width) * (points.size - 1))
                                        .toInt()
                                        .coerceIn(0, points.lastIndex)
                                    if (selectedIdx != idx) {
                                        selectedIdx = idx
                                        haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                    }
                                }
                            }
                        }
                ) {
                    val padX = 12.dp.toPx()
                    val padTop = 14.dp.toPx()
                    val padBottom = 8.dp.toPx()
                    val chartW = size.width - padX * 2
                    val chartH = size.height - padTop - padBottom

                    val coords = points.mapIndexed { i, pt ->
                        val x = if (points.size == 1) padX + chartW / 2f else padX + (i.toFloat() / (points.size - 1)) * chartW
                        val y = padTop + chartH * (1f - (pt.use / maxVal).toFloat().coerceIn(0f, 1f))
                        Offset(x, y)
                    }

                    // 日均虚线
                    if (avg > 0 && selectedIdx == null) {
                        val avgY = padTop + chartH * (1f - (avg / maxVal).toFloat().coerceIn(0f, 1f))
                        drawLine(
                            color = colors.textTertiary.copy(alpha = 0.45f),
                            start = Offset(padX, avgY),
                            end = Offset(size.width - padX, avgY),
                            strokeWidth = 1.dp.toPx(),
                            pathEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 8f))
                        )
                    }

                    // 平滑曲线 + 面积填充
                    val linePath = Path()
                    val fillPath = Path()
                    coords.forEachIndexed { idx, pt ->
                        if (idx == 0) {
                            linePath.moveTo(pt.x, pt.y)
                            fillPath.moveTo(pt.x, size.height - padBottom)
                            fillPath.lineTo(pt.x, pt.y)
                        } else {
                            val prev = coords[idx - 1]
                            val cx = (prev.x + pt.x) / 2f
                            linePath.cubicTo(cx, prev.y, cx, pt.y, pt.x, pt.y)
                            fillPath.cubicTo(cx, prev.y, cx, pt.y, pt.x, pt.y)
                        }
                    }
                    fillPath.lineTo(coords.last().x, size.height - padBottom)
                    fillPath.close()

                    drawPath(
                        path = fillPath,
                        brush = Brush.verticalGradient(
                            colors = listOf(tint.copy(alpha = 0.30f), tint.copy(alpha = 0.01f)),
                            startY = padTop,
                            endY = size.height - padBottom
                        )
                    )
                    drawPath(
                        path = linePath,
                        color = tint,
                        style = Stroke(width = 2.6.dp.toPx(), cap = StrokeCap.Round)
                    )

                    // 选中准线
                    selectedIdx?.let { sIdx ->
                        val sPt = coords[sIdx]
                        drawLine(
                            color = tint.copy(alpha = 0.6f),
                            start = Offset(sPt.x, padTop),
                            end = Offset(sPt.x, size.height - padBottom),
                            strokeWidth = 1.2.dp.toPx(),
                            pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 6f))
                        )
                    }

                    // 数据点
                    coords.forEachIndexed { idx, pt ->
                        val isSel = selectedIdx == idx
                        drawCircle(
                            color = tint,
                            radius = if (isSel) 5.5.dp.toPx() else 3.dp.toPx(),
                            center = pt
                        )
                        if (isSel) {
                            drawCircle(
                                color = colors.surfaceElevated,
                                radius = 2.5.dp.toPx(),
                                center = pt
                            )
                        }
                    }
                }

                // X 轴日期标签
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    points.forEachIndexed { idx, pt ->
                        val highlighted = selectedIdx == idx
                        Text(
                            text = pt.shortDateText,
                            color = if (highlighted) tint else colors.textSecondary,
                            fontSize = 10.sp,
                            fontWeight = if (highlighted) FontWeight.Bold else FontWeight.Medium
                        )
                    }
                }

                if (selectedIdx == null) {
                    Text(
                        text = "滑动或轻点曲线查看每日用量",
                        color = colors.textTertiary,
                        fontSize = 10.sp,
                        textAlign = TextAlign.End,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}

@Composable
private fun DemoBalanceCard(
    title: String,
    value: String,
    unit: String,
    caption: String,
    fraction: Float,
    tint: Color,
    icon: ImageVector,
    modifier: Modifier = Modifier
) {
    val colors = DormTheme.colors
    DormCard(modifier = modifier.height(152.dp), cornerRadius = 24.dp, elevated = true) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(15.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Surface(
                modifier = Modifier.size(32.dp),
                shape = CircleShape,
                color = tint.copy(alpha = 0.16f)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(icon, null, tint = tint, modifier = Modifier.size(16.dp))
                }
            }

            Column {
                Text(title, color = colors.textSecondary, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(value, color = colors.textPrimary, fontSize = 25.sp, fontWeight = FontWeight.Bold)
                    Text(unit, color = colors.textSecondary, fontSize = 11.sp, modifier = Modifier.padding(bottom = 3.dp))
                }
                Spacer(Modifier.height(7.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(4.dp)
                        .clip(CircleShape)
                        .background(tint.copy(alpha = 0.15f))
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(fraction.coerceAtLeast(0.05f))
                            .height(4.dp)
                            .clip(CircleShape)
                            .background(tint)
                    )
                }
                Spacer(Modifier.height(6.dp))
                Text(caption, color = colors.textSecondary, fontSize = 11.sp, maxLines = 1)
            }
        }
    }
}

@Composable
private fun RoomPickerPromptCard(onClick: () -> Unit) {
    val colors = DormTheme.colors
    DormCard(modifier = Modifier.fillMaxWidth(), cornerRadius = 24.dp, elevated = true) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Surface(
                modifier = Modifier.size(52.dp),
                shape = CircleShape,
                color = colors.electricYellow.copy(alpha = 0.15f)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Bolt, null, tint = colors.electricYellow, modifier = Modifier.size(26.dp))
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("查看宿舍水电", color = colors.textPrimary, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                Text(
                    text = "选择所在校区与宿舍号，即可查看剩余电量和近 7 日用量",
                    color = colors.textSecondary,
                    fontSize = 12.sp,
                    textAlign = TextAlign.Center
                )
            }
            Button(
                onClick = onClick,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(46.dp),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(containerColor = colors.actionBlue)
            ) {
                Icon(Icons.Rounded.Apartment, null, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text("选择宿舍房间", fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun LowBalanceCard(detail: SWAERoomDetail, meter: SWAEMeterDetail, days: Int) {
    val colors = DormTheme.colors
    val kind = detail.kindFor(meter)
    DormCard(modifier = Modifier.fillMaxWidth(), cornerRadius = 22.dp) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Surface(
                modifier = Modifier.size(38.dp),
                shape = CircleShape,
                color = colors.warningAmber.copy(alpha = 0.16f)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.WarningAmber, null, tint = colors.warningAmber, modifier = Modifier.size(20.dp))
                }
            }
            Column(modifier = Modifier.weight(1f)) {
                Text("余量偏低", color = colors.textPrimary, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                Text(
                    text = "${detail.displayNameFor(meter)}约可用 $days 天，记得及时充值",
                    color = colors.textSecondary,
                    fontSize = 12.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Text(
                text = "${meter.remaining.formatSwae()} ${kind.unit}",
                color = colors.warningAmber,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

// MARK: - 空调控温扩展页

@Composable
fun ClimateControlScreen(
    viewModel: DormAppViewModel,
    onBack: () -> Unit
) {
    val colors = DormTheme.colors
    var mode by remember { mutableStateOf("制冷") }

    SecondaryScreenScaffold(title = "空调控温", onBack = onBack) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(top = 12.dp, bottom = 36.dp)
        ) {
            DormCard(modifier = Modifier.fillMaxWidth(), cornerRadius = 32.dp, elevated = true) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(22.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(20.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text("宿舍空调", color = colors.textPrimary, fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                Box(Modifier.size(6.dp).clip(CircleShape).background(colors.warningAmber))
                                Text("未连接", color = colors.textSecondary, fontSize = 12.sp)
                            }
                        }
                        Surface(shape = CircleShape, color = colors.surfaceSubtle) {
                            Text(
                                "即将支持",
                                color = colors.textSecondary,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.padding(horizontal = 9.dp, vertical = 4.dp)
                            )
                        }
                    }

                    Box(modifier = Modifier.size(190.dp), contentAlignment = Alignment.Center) {
                        Canvas(modifier = Modifier.fillMaxSize()) {
                            val stroke = 12.dp.toPx()
                            val inset = stroke / 2f
                            val arcSize = Size(size.width - stroke, size.height - stroke)
                            drawArc(
                                color = colors.climateBlue.copy(alpha = 0.14f),
                                startAngle = 0f,
                                sweepAngle = 360f,
                                useCenter = false,
                                topLeft = Offset(inset, inset),
                                size = arcSize,
                                style = Stroke(width = stroke)
                            )
                            drawArc(
                                color = colors.climateBlue,
                                startAngle = -90f,
                                sweepAngle = 360f * 0.62f,
                                useCenter = false,
                                topLeft = Offset(inset, inset),
                                size = arcSize,
                                style = Stroke(width = stroke, cap = StrokeCap.Round)
                            )
                        }
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("26", color = colors.textPrimary, fontSize = 54.sp, fontWeight = FontWeight.Bold)
                            Text("设定温度 °C", color = colors.textSecondary, fontSize = 12.sp)
                        }
                    }

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        listOf("制冷", "制热", "除湿").forEach { item ->
                            val selected = mode == item
                            Surface(
                                modifier = Modifier
                                    .weight(1f)
                                    .clip(CircleShape)
                                    .clickable { mode = item },
                                shape = CircleShape,
                                color = if (selected) colors.climateBlue.copy(alpha = 0.16f) else colors.surfaceSubtle,
                                border = BorderStroke(1.dp, if (selected) colors.climateBlue.copy(alpha = 0.45f) else Color.Transparent)
                            ) {
                                Text(
                                    text = item,
                                    color = if (selected) colors.climateBlue else colors.textSecondary,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    textAlign = TextAlign.Center,
                                    modifier = Modifier.padding(vertical = 10.dp)
                                )
                            }
                        }
                    }

                    Button(
                        onClick = { viewModel.showToast("空调控制功能即将开放", ToastStyle.INFO) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(50.dp),
                        shape = RoundedCornerShape(18.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = colors.climateBlue)
                    ) {
                        Icon(Icons.Rounded.AcUnit, null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("连接空调", fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
    }
}

// MARK: - 校园一卡通扩展页

@Composable
fun CampusCardScreen(
    persisted: PersistedState,
    onBack: () -> Unit
) {
    SecondaryScreenScaffold(title = "校园一卡通", onBack = onBack) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(top = 12.dp, bottom = 36.dp)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(216.dp)
                    .clip(RoundedCornerShape(30.dp))
                    .background(
                        Brush.linearGradient(
                            listOf(Color(0xFF7B3FE4), Color(0xFFAF52DE), Color(0xFF5E5CE6))
                        )
                    )
                    .padding(22.dp)
            ) {
                Column(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Icon(Icons.Rounded.School, null, tint = Color.White.copy(alpha = 0.92f), modifier = Modifier.size(16.dp))
                            Text("校园一卡通", color = Color.White.copy(alpha = 0.92f), fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                        }
                        Surface(shape = CircleShape, color = Color.White.copy(alpha = 0.18f)) {
                            Text(
                                "即将支持",
                                color = Color.White,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                            )
                        }
                    }

                    Column {
                        Text("卡内余额", color = Color.White.copy(alpha = 0.78f), fontSize = 12.sp)
                        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                            Text("¥", color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(bottom = 6.dp))
                            Text(
                                text = if (persisted.isDemoMode) String.format("%.2f", persisted.cardBalance) else "—",
                                color = Color.White,
                                fontSize = 40.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(persisted.userName ?: "未登录", color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                        Icon(Icons.Rounded.Contactless, null, tint = Color.White.copy(alpha = 0.88f), modifier = Modifier.size(22.dp))
                    }
                }
            }
        }
    }
}

// MARK: - 二级页通用顶栏壳

@Composable
fun SecondaryScreenScaffold(
    title: String,
    onBack: () -> Unit,
    trailing: (@Composable () -> Unit)? = null,
    content: @Composable () -> Unit
) {
    val colors = DormTheme.colors
    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "返回", tint = colors.textPrimary)
            }
            Text(
                text = title,
                color = colors.textPrimary,
                fontSize = 18.sp,
                fontWeight = FontWeight.SemiBold
            )
            Box(modifier = Modifier.size(48.dp), contentAlignment = Alignment.Center) {
                trailing?.invoke()
            }
        }
        Box(modifier = Modifier.weight(1f)) {
            content()
        }
    }
}

@Composable
private fun SWAEMeterKind.tintColor(): Color {
    val colors = DormTheme.colors
    return when (this) {
        SWAEMeterKind.ELECTRICITY -> colors.electricYellow
        SWAEMeterKind.COLD_WATER -> colors.waterBlue
        SWAEMeterKind.HOT_WATER -> colors.hotWaterCoral
        SWAEMeterKind.AIR_CONDITIONER -> colors.climateBlue
        SWAEMeterKind.OTHER -> colors.textSecondary
    }
}

private fun SWAEMeterKind.iconVector(): ImageVector = when (this) {
    SWAEMeterKind.ELECTRICITY -> Icons.Rounded.Bolt
    SWAEMeterKind.COLD_WATER, SWAEMeterKind.HOT_WATER -> Icons.Rounded.WaterDrop
    SWAEMeterKind.AIR_CONDITIONER -> Icons.Rounded.AcUnit
    SWAEMeterKind.OTHER -> Icons.Rounded.Speed
}

private fun formatPrice(value: Double): String {
    if (value == kotlin.math.round(value)) return String.format("%.0f", value)
    if (kotlin.math.round(value * 10) == value * 10) return String.format("%.1f", value)
    return String.format("%.2f", value)
}
