package com.sakiyui.dormhome.core.modules

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AcUnit
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.CreditCard
import androidx.compose.material.icons.rounded.History
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import kotlinx.serialization.Serializable

@Serializable
enum class ServiceModuleKind(val id: String) {
    UTILITIES("utilities"),
    HISTORY("history"),
    CLIMATE("climate"),
    CAMPUS_CARD("campusCard")
}

data class DormServiceModule(
    val kind: ServiceModuleKind,
    val title: String,
    val subtitle: String,
    val icon: ImageVector,
    val accentDark: Color,
    val accentLight: Color,
    val badge: String? = null
) {
    val id: String get() = kind.id
    fun accent(isDark: Boolean): Color = if (isDark) accentDark else accentLight
}

object ModuleRegistry {
    val all: List<DormServiceModule> = listOf(
        DormServiceModule(
            kind = ServiceModuleKind.UTILITIES,
            title = "水电费",
            subtitle = "电量余量与用水余额",
            icon = Icons.Rounded.Bolt,
            accentDark = Color(0xFFFFD60A),
            accentLight = Color(0xFFD98A00),
            badge = null
        ),
        DormServiceModule(
            kind = ServiceModuleKind.HISTORY,
            title = "开门记录",
            subtitle = "每一次开锁与回锁",
            icon = Icons.Rounded.History,
            accentDark = Color(0xFF34D399),
            accentLight = Color(0xFF16A34A),
            badge = null
        ),
        DormServiceModule(
            kind = ServiceModuleKind.CLIMATE,
            title = "空调控温",
            subtitle = "回寝前提前降温",
            icon = Icons.Rounded.AcUnit,
            accentDark = Color(0xFF38BDF8),
            accentLight = Color(0xFF0284C7),
            badge = "即将接入"
        ),
        DormServiceModule(
            kind = ServiceModuleKind.CAMPUS_CARD,
            title = "校园一卡通",
            subtitle = "余额与消费流水",
            icon = Icons.Rounded.CreditCard,
            accentDark = Color(0xFFC084FC),
            accentLight = Color(0xFF9333EA),
            badge = "即将接入"
        )
    )

    val defaultEnabledIds: List<String> = listOf(
        ServiceModuleKind.UTILITIES.id,
        ServiceModuleKind.HISTORY.id
    )

    fun enabled(ids: List<String>): List<DormServiceModule> = all.filter { it.id in ids }

    fun module(kind: ServiceModuleKind): DormServiceModule =
        all.firstOrNull { it.kind == kind } ?: all.first()
}
