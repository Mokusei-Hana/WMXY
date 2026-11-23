package com.sakiyui.dormhome.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sakiyui.dormhome.core.network.SWAEBuilding
import com.sakiyui.dormhome.core.network.SWAEFloor
import com.sakiyui.dormhome.core.network.SWAERoomOption
import com.sakiyui.dormhome.core.network.SWAEZone
import com.sakiyui.dormhome.core.viewmodel.DormAppViewModel
import com.sakiyui.dormhome.ui.components.DormCard
import com.sakiyui.dormhome.ui.theme.DormTheme
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RoomPickerSheet(
    viewModel: DormAppViewModel,
    onDismiss: () -> Unit
) {
    val colors = DormTheme.colors
    val scope = rememberCoroutineScope()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    var zones by remember { mutableStateOf<List<SWAEZone>>(emptyList()) }
    var buildings by remember { mutableStateOf<List<SWAEBuilding>>(emptyList()) }
    var floors by remember { mutableStateOf<List<SWAEFloor>>(emptyList()) }
    var rooms by remember { mutableStateOf<List<SWAERoomOption>>(emptyList()) }

    var selectedZone by remember { mutableStateOf<SWAEZone?>(null) }
    var selectedBuilding by remember { mutableStateOf<SWAEBuilding?>(null) }
    var selectedFloor by remember { mutableStateOf<SWAEFloor?>(null) }

    var loadingStep by remember { mutableStateOf<Int?>(1) }
    var queryingRoomId by remember { mutableStateOf<Int?>(null) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        loadingStep = 1
        try {
            zones = viewModel.loadZones()
            errorMessage = null
        } catch (e: Throwable) {
            errorMessage = e.message ?: "加载校区失败"
        } finally {
            loadingStep = null
        }
    }

    ModalBottomSheet(
        onDismissRequest = { if (queryingRoomId == null) onDismiss() },
        sheetState = sheetState,
        containerColor = colors.surfaceElevated,
        shape = RoundedCornerShape(topStart = 30.dp, topEnd = 30.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(bottom = 26.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text("选择宿舍房间", color = colors.textPrimary, fontSize = 23.sp, fontWeight = FontWeight.Bold)
                    Text("依次选择校区、楼栋、楼层与房间", color = colors.textSecondary, fontSize = 12.sp)
                }
                Surface(
                    modifier = Modifier
                        .size(34.dp)
                        .clip(CircleShape)
                        .clickable(enabled = queryingRoomId == null, onClick = onDismiss),
                    shape = CircleShape,
                    color = colors.surfaceSubtle
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(Icons.Rounded.Close, "关闭", tint = colors.textSecondary, modifier = Modifier.size(18.dp))
                    }
                }
            }

            // 1. 校区
            StepCard(
                index = 1,
                title = "校区 / 宿舍区",
                selection = selectedZone?.name,
                loading = loadingStep == 1
            ) {
                if (zones.isEmpty() && loadingStep != 1) {
                    Text("暂无可选校区", color = colors.textSecondary, fontSize = 12.sp)
                } else {
                    OptionChipGrid(
                        items = zones,
                        selected = selectedZone,
                        label = { it.name },
                        onSelect = { zone ->
                            selectedZone = zone
                            selectedBuilding = null
                            selectedFloor = null
                            buildings = emptyList()
                            floors = emptyList()
                            rooms = emptyList()
                            errorMessage = null
                            loadingStep = 2
                            scope.launch {
                                try {
                                    val res = viewModel.loadBuildings(zone)
                                    if (selectedZone?.id == zone.id) buildings = res
                                } catch (e: Throwable) {
                                    if (selectedZone?.id == zone.id) errorMessage = e.message ?: "加载楼栋失败"
                                } finally {
                                    if (loadingStep == 2) loadingStep = null
                                }
                            }
                        }
                    )
                }
            }

            // 2. 楼栋
            if (selectedZone != null) {
                StepCard(
                    index = 2,
                    title = "楼栋",
                    selection = selectedBuilding?.name,
                    loading = loadingStep == 2
                ) {
                    if (buildings.isEmpty() && loadingStep != 2) {
                        Text("该校区暂无可选楼栋", color = colors.textSecondary, fontSize = 12.sp)
                    } else {
                        OptionChipGrid(
                            items = buildings,
                            selected = selectedBuilding,
                            label = { it.name },
                            onSelect = { building ->
                                selectedBuilding = building
                                selectedFloor = null
                                floors = emptyList()
                                rooms = emptyList()
                                errorMessage = null
                                loadingStep = 3
                                scope.launch {
                                    try {
                                        val res = viewModel.loadFloors(building)
                                        if (selectedBuilding?.id == building.id) floors = res
                                    } catch (e: Throwable) {
                                        if (selectedBuilding?.id == building.id) errorMessage = e.message ?: "加载楼层失败"
                                    } finally {
                                        if (loadingStep == 3) loadingStep = null
                                    }
                                }
                            }
                        )
                    }
                }
            }

            // 3. 楼层
            if (selectedBuilding != null) {
                StepCard(
                    index = 3,
                    title = "楼层",
                    selection = selectedFloor?.name,
                    loading = loadingStep == 3
                ) {
                    if (floors.isEmpty() && loadingStep != 3) {
                        Text("该楼栋暂无可选楼层", color = colors.textSecondary, fontSize = 12.sp)
                    } else {
                        OptionChipGrid(
                            items = floors,
                            selected = selectedFloor,
                            label = { it.name },
                            onSelect = { floor ->
                                selectedFloor = floor
                                rooms = emptyList()
                                errorMessage = null
                                loadingStep = 4
                                scope.launch {
                                    try {
                                        val res = viewModel.loadRooms(floor)
                                        if (selectedFloor?.id == floor.id) rooms = res
                                    } catch (e: Throwable) {
                                        if (selectedFloor?.id == floor.id) errorMessage = e.message ?: "加载房间失败"
                                    } finally {
                                        if (loadingStep == 4) loadingStep = null
                                    }
                                }
                            }
                        )
                    }
                }
            }

            // 4. 房间
            if (selectedFloor != null) {
                StepCard(
                    index = 4,
                    title = "房间",
                    selection = "点击房间立即查询",
                    loading = loadingStep == 4
                ) {
                    if (rooms.isEmpty() && loadingStep != 4) {
                        Text("该楼层暂无可选房间", color = colors.textSecondary, fontSize = 12.sp)
                    } else {
                        val rows = rooms.chunked(2)
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            rows.forEach { row ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    row.forEach { room ->
                                        val isQuerying = queryingRoomId == room.id
                                        Surface(
                                            modifier = Modifier
                                                .weight(1f)
                                                .height(40.dp)
                                                .clip(RoundedCornerShape(12.dp))
                                                .clickable(enabled = queryingRoomId == null) {
                                                    val z = selectedZone ?: return@clickable
                                                    val b = selectedBuilding ?: return@clickable
                                                    val f = selectedFloor ?: return@clickable
                                                    queryingRoomId = room.id
                                                    errorMessage = null
                                                    scope.launch {
                                                        try {
                                                            viewModel.selectUtilityRoom(room, z, b, f)
                                                            onDismiss()
                                                        } catch (e: Throwable) {
                                                            errorMessage = e.message ?: "查询房间水电失败"
                                                        } finally {
                                                            queryingRoomId = null
                                                        }
                                                    }
                                                },
                                            shape = RoundedCornerShape(12.dp),
                                            color = if (isQuerying) colors.actionBlue.copy(alpha = 0.14f) else colors.surfaceSubtle,
                                            border = BorderStroke(
                                                1.dp,
                                                if (isQuerying) colors.actionBlue.copy(alpha = 0.42f) else Color.Transparent
                                            )
                                        ) {
                                            Box(contentAlignment = Alignment.Center) {
                                                if (isQuerying) {
                                                    CircularProgressIndicator(
                                                        modifier = Modifier.size(16.dp),
                                                        strokeWidth = 2.dp,
                                                        color = colors.actionBlue
                                                    )
                                                } else {
                                                    Text(
                                                        text = room.name,
                                                        color = colors.textPrimary,
                                                        fontSize = 12.sp,
                                                        fontWeight = FontWeight.SemiBold,
                                                        maxLines = 1,
                                                        overflow = TextOverflow.Ellipsis,
                                                        modifier = Modifier.padding(horizontal = 8.dp)
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    if (row.size == 1) Spacer(Modifier.weight(1f))
                                }
                            }
                        }
                    }
                }
            }

            errorMessage?.let { err ->
                Surface(
                    shape = RoundedCornerShape(14.dp),
                    color = colors.dangerRed.copy(alpha = 0.10f)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Rounded.Warning, null, tint = colors.dangerRed, modifier = Modifier.size(16.dp))
                        Text(err, color = colors.dangerRed, fontSize = 12.sp)
                    }
                }
            }

            queryingRoomId?.let { qId ->
                val roomName = rooms.firstOrNull { it.id == qId }?.name ?: ""
                DormCard(modifier = Modifier.fillMaxWidth(), cornerRadius = 16.dp) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp, color = colors.actionBlue)
                        Text("正在读取 $roomName 实时水电…", color = colors.textSecondary, fontSize = 12.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun StepCard(
    index: Int,
    title: String,
    selection: String?,
    loading: Boolean,
    content: @Composable () -> Unit
) {
    val colors = DormTheme.colors
    DormCard(modifier = Modifier.fillMaxWidth(), cornerRadius = 20.dp) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(22.dp)
                        .clip(CircleShape)
                        .background(colors.actionBlue),
                    contentAlignment = Alignment.Center
                ) {
                    Text("$index", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                }
                Text(title, color = colors.textPrimary, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.weight(1f))
                if (loading) {
                    CircularProgressIndicator(modifier = Modifier.size(15.dp), strokeWidth = 2.dp, color = colors.actionBlue)
                } else if (!selection.isNullOrEmpty()) {
                    Text(selection, color = colors.textSecondary, fontSize = 11.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
            content()
        }
    }
}

@Composable
private fun <T> OptionChipGrid(
    items: List<T>,
    selected: T?,
    label: (T) -> String,
    onSelect: (T) -> Unit
) {
    val colors = DormTheme.colors
    val rows = items.chunked(2)
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        rows.forEach { row ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                row.forEach { item ->
                    val isSel = item == selected
                    Surface(
                        modifier = Modifier
                            .weight(1f)
                            .height(38.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .clickable { onSelect(item) },
                        shape = RoundedCornerShape(12.dp),
                        color = if (isSel) colors.actionBlue.copy(alpha = 0.14f) else colors.surfaceSubtle,
                        border = BorderStroke(1.dp, if (isSel) colors.actionBlue.copy(alpha = 0.42f) else Color.Transparent)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(
                                text = label(item),
                                color = if (isSel) colors.actionBlue else colors.textPrimary,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.SemiBold,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.padding(horizontal = 8.dp)
                            )
                        }
                    }
                }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}
