package com.sakiyui.dormhome.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sakiyui.dormhome.core.viewmodel.DoorVisualState
import com.sakiyui.dormhome.core.viewmodel.ToastMessage
import com.sakiyui.dormhome.core.viewmodel.ToastStyle
import com.sakiyui.dormhome.ui.theme.DormTheme

/**
 * 动态氛围光背景：随门锁状态与深浅色模式平滑过渡色相。
 */
@Composable
fun AtmosphericBackground(
    doorState: DoorVisualState,
    modifier: Modifier = Modifier
) {
    val colors = DormTheme.colors
    val targetTop = when {
        colors.isDark && doorState == DoorVisualState.UNLOCKED -> Color(0xFF0A3227)
        colors.isDark && doorState == DoorVisualState.UNLOCKING -> Color(0xFF0E3454)
        colors.isDark -> Color(0xFF132544)
        !colors.isDark && doorState == DoorVisualState.UNLOCKED -> Color(0xFFCFF4E4)
        !colors.isDark && doorState == DoorVisualState.UNLOCKING -> Color(0xFFCDEBF9)
        else -> Color(0xFFD7E6FB)
    }
    val targetSide = when {
        colors.isDark && doorState == DoorVisualState.UNLOCKED -> Color(0xFF0B251E)
        colors.isDark && doorState == DoorVisualState.UNLOCKING -> Color(0xFF0B243D)
        colors.isDark -> Color(0xFF0F1C36)
        !colors.isDark && doorState == DoorVisualState.UNLOCKED -> Color(0xFFE0F7EE)
        !colors.isDark && doorState == DoorVisualState.UNLOCKING -> Color(0xFFDDF1FC)
        else -> Color(0xFFE4EEFC)
    }

    val topGlow by animateColorAsState(targetTop, tween(750), label = "topGlow")
    val sideGlow by animateColorAsState(targetSide, tween(750), label = "sideGlow")

    Canvas(
        modifier = modifier
            .fillMaxSize()
            .background(colors.bgBase)
    ) {
        drawRect(
            brush = Brush.radialGradient(
                colors = listOf(topGlow.copy(alpha = if (colors.isDark) 0.9f else 0.85f), Color.Transparent),
                center = Offset(size.width * 0.22f, size.height * 0.12f),
                radius = size.width * 1.05f
            )
        )
        drawRect(
            brush = Brush.radialGradient(
                colors = listOf(sideGlow.copy(alpha = if (colors.isDark) 0.75f else 0.7f), Color.Transparent),
                center = Offset(size.width * 0.88f, size.height * 0.36f),
                radius = size.width * 0.9f
            )
        )
    }
}

@Composable
fun DormCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 26.dp,
    elevated: Boolean = false,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    val colors = DormTheme.colors
    val shape = RoundedCornerShape(cornerRadius)
    Surface(
        modifier = modifier
            .clip(shape)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier),
        shape = shape,
        color = if (elevated) colors.surfaceElevated else colors.surfaceCard,
        border = BorderStroke(0.8.dp, colors.cardBorder),
        shadowElevation = if (colors.isDark) 0.dp else if (elevated) 6.dp else 2.dp
    ) {
        Column(content = content)
    }
}

@Composable
fun DormToastBanner(
    toast: ToastMessage,
    modifier: Modifier = Modifier
) {
    val colors = DormTheme.colors
    val (icon, tint) = when (toast.style) {
        ToastStyle.SUCCESS -> Icons.Rounded.CheckCircle to colors.onlineGreen
        ToastStyle.INFO -> Icons.Rounded.AutoAwesome to colors.actionBlue
        ToastStyle.ERROR -> Icons.Rounded.Warning to colors.dangerRed
    }

    Surface(
        modifier = modifier,
        shape = CircleShape,
        color = colors.surfaceElevated,
        border = BorderStroke(1.dp, tint.copy(alpha = 0.32f)),
        shadowElevation = 10.dp
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 11.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = tint,
                modifier = Modifier.size(18.dp)
            )
            Text(
                text = toast.message,
                color = colors.textPrimary,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
fun SectionHeader(
    title: String,
    actionText: String? = null,
    onActionClick: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val colors = DormTheme.colors
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            color = colors.textPrimary,
            fontSize = 17.sp,
            fontWeight = FontWeight.SemiBold
        )
        if (actionText != null && onActionClick != null) {
            Text(
                text = actionText,
                color = colors.textSecondary,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier
                    .clip(RoundedCornerShape(10.dp))
                    .clickable(onClick = onActionClick)
                    .padding(horizontal = 8.dp, vertical = 4.dp)
            )
        }
    }
}
