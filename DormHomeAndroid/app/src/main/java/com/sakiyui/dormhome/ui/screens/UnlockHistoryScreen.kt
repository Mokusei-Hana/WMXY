package com.sakiyui.dormhome.ui.screens

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.LockOpen
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sakiyui.dormhome.core.network.DoorAction
import com.sakiyui.dormhome.core.network.UnlockChannel
import com.sakiyui.dormhome.core.network.UnlockRecord
import com.sakiyui.dormhome.core.storage.PersistedState
import com.sakiyui.dormhome.core.viewmodel.DormAppViewModel
import com.sakiyui.dormhome.ui.components.DormCard
import com.sakiyui.dormhome.ui.theme.DormTheme
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun UnlockHistoryScreen(
    persisted: PersistedState,
    viewModel: DormAppViewModel,
    onBack: () -> Unit
) {
    val colors = DormTheme.colors
    var showClearDialog by remember { mutableStateOf(false) }
    var deleteTarget by remember { mutableStateOf<UnlockRecord?>(null) }

    val history = persisted.visibleHistory
    val zone = ZoneId.systemDefault()
    val groups = remember(history) {
        history.groupBy { Instant.ofEpochMilli(it.timestampMillis).atZone(zone).toLocalDate() }
            .entries
            .sortedByDescending { it.key }
    }

    SecondaryScreenScaffold(
        title = "开门记录",
        onBack = onBack,
        trailing = {
            IconButton(
                onClick = { showClearDialog = true },
                enabled = history.isNotEmpty()
            ) {
                Icon(
                    imageVector = Icons.Rounded.DeleteOutline,
                    contentDescription = "清空记录",
                    tint = if (history.isEmpty()) colors.textTertiary else colors.textPrimary
                )
            }
        }
    ) {
        if (history.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 36.dp),
                contentAlignment = Alignment.Center
            ) {
                DormCard(modifier = Modifier.fillMaxWidth(), cornerRadius = 30.dp, elevated = true) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(28.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Surface(
                            modifier = Modifier.size(68.dp),
                            shape = CircleShape,
                            color = colors.onlineGreen.copy(alpha = 0.14f)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(Icons.Rounded.History, null, tint = colors.onlineGreen, modifier = Modifier.size(30.dp))
                            }
                        }
                        Text("暂无开门记录", color = colors.textPrimary, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                        Text(
                            text = "每次远程开锁与自动回锁都会记录在这里",
                            color = colors.textSecondary,
                            fontSize = 12.sp,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp)
                    .padding(top = 8.dp, bottom = 36.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp)
            ) {
                // 概览卡片
                DormCard(modifier = Modifier.fillMaxWidth(), cornerRadius = 24.dp, elevated = true) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        SummaryMetric(
                            value = "${persisted.unlockThisWeekCount}",
                            label = "本周开锁",
                            tint = colors.onlineGreen,
                            modifier = Modifier.weight(1f)
                        )
                        Box(Modifier.width(1.dp).height(30.dp).background(colors.cardBorder))
                        SummaryMetric(
                            value = "${history.count { it.channel == UnlockChannel.AUTO_RELOCK }}",
                            label = "自动回锁",
                            tint = colors.actionBlue,
                            modifier = Modifier.weight(1f)
                        )
                        Box(Modifier.width(1.dp).height(30.dp).background(colors.cardBorder))
                        SummaryMetric(
                            value = relativeShortTime(history.first().timestampMillis),
                            label = "最近操作",
                            tint = colors.warningAmber,
                            modifier = Modifier.weight(1f)
                        )
                    }
                }

                // 按日期分组列表
                groups.forEach { (day, records) ->
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 4.dp),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(dayTitle(day), color = colors.textSecondary, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                            Text("${records.size} 条", color = colors.textTertiary, fontSize = 11.sp)
                        }

                        DormCard(modifier = Modifier.fillMaxWidth(), cornerRadius = 24.dp) {
                            records.forEachIndexed { idx, record ->
                                HistoryRow(
                                    record = record,
                                    onLongClick = { deleteTarget = record }
                                )
                                if (idx < records.lastIndex) {
                                    HorizontalDivider(
                                        modifier = Modifier.padding(start = 58.dp),
                                        color = colors.cardBorder
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showClearDialog) {
        AlertDialog(
            onDismissRequest = { showClearDialog = false },
            title = { Text("清空全部开门记录？") },
            text = { Text("此操作不可撤销，仅清除本机记录。") },
            confirmButton = {
                TextButton(onClick = {
                    showClearDialog = false
                    viewModel.clearHistory()
                }) {
                    Text("清空记录", color = colors.dangerRed, fontWeight = FontWeight.SemiBold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showClearDialog = false }) { Text("取消") }
            }
        )
    }

    deleteTarget?.let { rec ->
        AlertDialog(
            onDismissRequest = { deleteTarget = null },
            title = { Text("删除这条记录？") },
            text = { Text("${rec.deviceName} · ${rec.detail}") },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.deleteHistory(rec.id)
                    deleteTarget = null
                }) {
                    Text("删除", color = colors.dangerRed, fontWeight = FontWeight.SemiBold)
                }
            },
            dismissButton = {
                TextButton(onClick = { deleteTarget = null }) { Text("取消") }
            }
        )
    }
}

@Composable
private fun SummaryMetric(value: String, label: String, tint: Color, modifier: Modifier = Modifier) {
    val colors = DormTheme.colors
    Column(modifier = modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp)) {
        Text(value, color = tint, fontSize = 21.sp, fontWeight = FontWeight.Bold, maxLines = 1)
        Text(label, color = colors.textSecondary, fontSize = 11.sp)
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun HistoryRow(
    record: UnlockRecord,
    onLongClick: () -> Unit
) {
    val colors = DormTheme.colors
    val tint = if (record.action == DoorAction.UNLOCK) colors.onlineGreen else colors.actionBlue
    val timeText = remember(record.timestampMillis) {
        Instant.ofEpochMilli(record.timestampMillis)
            .atZone(ZoneId.systemDefault())
            .format(DateTimeFormatter.ofPattern("HH:mm"))
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .combinedClickable(onClick = {}, onLongClick = onLongClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Surface(
            modifier = Modifier.size(34.dp),
            shape = CircleShape,
            color = tint.copy(alpha = 0.14f)
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    imageVector = if (record.action == DoorAction.UNLOCK) Icons.Rounded.LockOpen else Icons.Rounded.Lock,
                    contentDescription = null,
                    tint = tint,
                    modifier = Modifier.size(16.dp)
                )
            }
        }

        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = "${record.action.title}${if (record.success) "成功" else "失败"}",
                    color = colors.textPrimary,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold
                )
                if (record.isDemo) {
                    Surface(shape = CircleShape, color = colors.surfaceSubtle) {
                        Text(
                            text = "演示",
                            color = colors.textSecondary,
                            fontSize = 9.sp,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.padding(horizontal = 5.dp, vertical = 1.dp)
                        )
                    }
                }
            }
            Text(
                text = record.deviceName,
                color = colors.textSecondary,
                fontSize = 11.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }

        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(timeText, color = colors.textPrimary, fontSize = 12.sp, fontWeight = FontWeight.Medium)
            Text(record.channel.title, color = colors.textTertiary, fontSize = 10.sp)
        }
    }
}

private fun dayTitle(date: LocalDate): String {
    val today = LocalDate.now()
    return when (date) {
        today -> "今天"
        today.minusDays(1) -> "昨天"
        else -> date.format(DateTimeFormatter.ofPattern("M月d日 EEEE", Locale.CHINA))
    }
}

private fun relativeShortTime(timestampMillis: Long): String {
    val diffSec = ((System.currentTimeMillis() - timestampMillis) / 1000).coerceAtLeast(0)
    return when {
        diffSec < 60 -> "刚刚"
        diffSec < 3600 -> "${diffSec / 60}分钟前"
        diffSec < 86400 -> "${diffSec / 3600}小时前"
        else -> "${diffSec / 86400}天前"
    }
}
