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
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.DoorFront
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Key
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.PhoneAndroid
import androidx.compose.material.icons.rounded.Sms
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.VisibilityOff
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sakiyui.dormhome.core.storage.PersistedState
import com.sakiyui.dormhome.core.viewmodel.DormAppViewModel
import com.sakiyui.dormhome.core.viewmodel.ToastStyle
import com.sakiyui.dormhome.ui.theme.DormTheme
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private enum class LoginMode(val title: String) {
    PASSWORD("账号密码"),
    SMS("短信验证码")
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginSheet(
    persisted: PersistedState,
    viewModel: DormAppViewModel,
    onDismiss: () -> Unit
) {
    val colors = DormTheme.colors
    val scope = rememberCoroutineScope()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    var mode by remember { mutableStateOf(LoginMode.PASSWORD) }
    var phone by remember { mutableStateOf(persisted.phone ?: viewModel.store.vault.load()?.phone ?: "") }
    var password by remember { mutableStateOf("") }
    var smsCode by remember { mutableStateOf("") }
    var showPassword by remember { mutableStateOf(false) }
    var isSubmitting by remember { mutableStateOf(false) }
    var isSendingCode by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var notice by remember { mutableStateOf<String?>(null) }
    var countdown by remember { mutableIntStateOf(0) }

    LaunchedEffect(Unit) {
        val incoming = viewModel.consumeLoginNotice()
        if (!incoming.isNullOrEmpty()) {
            notice = incoming
            if (incoming.contains("新设备")) mode = LoginMode.SMS
        }
    }

    LaunchedEffect(countdown) {
        if (countdown > 0) {
            delay(1000)
            countdown -= 1
        }
    }

    val isPhoneValid = phone.length == 11 && phone.all { it.isDigit() } && phone.startsWith("1")
    val canSendCode = isPhoneValid && !isSendingCode && countdown == 0
    val canSubmit = isPhoneValid && when (mode) {
        LoginMode.PASSWORD -> password.isNotEmpty()
        LoginMode.SMS -> smsCode.length >= 4
    }

    ModalBottomSheet(
        onDismissRequest = { if (!isSubmitting) onDismiss() },
        sheetState = sheetState,
        containerColor = colors.surfaceElevated,
        shape = RoundedCornerShape(topStart = 30.dp, topEnd = 30.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 22.dp)
                .padding(bottom = 24.dp)
                .navigationBarsPadding()
                .imePadding(),
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            // 顶部图标与关闭按钮
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(50.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(
                            Brush.linearGradient(listOf(colors.actionCyan, colors.actionBlue))
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Rounded.DoorFront,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(26.dp)
                    )
                }

                Surface(
                    modifier = Modifier
                        .size(34.dp)
                        .clip(CircleShape)
                        .clickable(enabled = !isSubmitting, onClick = onDismiss),
                    shape = CircleShape,
                    color = colors.surfaceSubtle
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = Icons.Rounded.Close,
                            contentDescription = "关闭",
                            tint = colors.textSecondary,
                            modifier = Modifier.size(18.dp)
                        )
                    }
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = "登录完美校园",
                    color = colors.textPrimary,
                    fontSize = 25.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "登录后即可远程开锁与查看宿舍水电",
                    color = colors.textSecondary,
                    fontSize = 13.sp
                )
            }

            // 模式切换胶囊
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                LoginMode.entries.forEach { item ->
                    val selected = mode == item
                    Surface(
                        modifier = Modifier
                            .weight(1f)
                            .clip(CircleShape)
                            .clickable {
                                mode = item
                                errorMessage = null
                            },
                        shape = CircleShape,
                        color = if (selected) colors.actionBlue.copy(alpha = 0.16f) else colors.surfaceSubtle,
                        border = BorderStroke(
                            1.dp,
                            if (selected) colors.actionBlue.copy(alpha = 0.42f) else Color.Transparent
                        )
                    ) {
                        Row(
                            modifier = Modifier.padding(vertical = 11.dp),
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = if (item == LoginMode.PASSWORD) Icons.Rounded.Key else Icons.Rounded.Sms,
                                contentDescription = null,
                                tint = if (selected) colors.actionBlue else colors.textSecondary,
                                modifier = Modifier.size(15.dp)
                            )
                            Spacer(Modifier.width(6.dp))
                            Text(
                                text = item.title,
                                color = if (selected) colors.actionBlue else colors.textSecondary,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }
                }
            }

            // 表单
            val fieldColors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = colors.actionBlue,
                unfocusedBorderColor = colors.cardBorder,
                focusedContainerColor = colors.surfaceSubtle,
                unfocusedContainerColor = colors.surfaceSubtle,
                focusedTextColor = colors.textPrimary,
                unfocusedTextColor = colors.textPrimary
            )

            OutlinedTextField(
                value = phone,
                onValueChange = { input ->
                    phone = input.filter { it.isDigit() }.take(11)
                },
                label = { Text("手机号") },
                placeholder = { Text("完美校园手机号") },
                leadingIcon = { Icon(Icons.Rounded.PhoneAndroid, null, tint = colors.textSecondary) },
                trailingIcon = {
                    if (phone.isNotEmpty()) {
                        Text(
                            text = "${phone.length}/11",
                            color = if (phone.length == 11) colors.onlineGreen else colors.textTertiary,
                            fontSize = 11.sp,
                            modifier = Modifier.padding(end = 10.dp)
                        )
                    }
                },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                shape = RoundedCornerShape(16.dp),
                colors = fieldColors,
                modifier = Modifier.fillMaxWidth()
            )

            if (mode == LoginMode.PASSWORD) {
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    label = { Text("密码") },
                    placeholder = { Text("完美校园登录密码") },
                    leadingIcon = { Icon(Icons.Rounded.Lock, null, tint = colors.textSecondary) },
                    trailingIcon = {
                        IconButton(onClick = { showPassword = !showPassword }) {
                            Icon(
                                imageVector = if (showPassword) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility,
                                contentDescription = if (showPassword) "隐藏密码" else "显示密码",
                                tint = colors.textSecondary
                            )
                        }
                    },
                    singleLine = true,
                    visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    shape = RoundedCornerShape(16.dp),
                    colors = fieldColors,
                    modifier = Modifier.fillMaxWidth()
                )
            } else {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    OutlinedTextField(
                        value = smsCode,
                        onValueChange = { input -> smsCode = input.filter { it.isDigit() }.take(8) },
                        label = { Text("短信验证码") },
                        placeholder = { Text("6 位验证码") },
                        leadingIcon = { Icon(Icons.Rounded.Sms, null, tint = colors.textSecondary) },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        shape = RoundedCornerShape(16.dp),
                        colors = fieldColors,
                        modifier = Modifier.weight(1f)
                    )

                    Surface(
                        modifier = Modifier
                            .height(56.dp)
                            .width(96.dp)
                            .padding(top = 6.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .clickable(enabled = canSendCode) {
                                isSendingCode = true
                                errorMessage = null
                                scope.launch {
                                    try {
                                        viewModel.requestSMSCode(phone)
                                        countdown = 60
                                        viewModel.showToast("验证码已发送，请查看短信", ToastStyle.SUCCESS)
                                    } catch (e: Throwable) {
                                        errorMessage = e.message ?: "发送失败"
                                    } finally {
                                        isSendingCode = false
                                    }
                                }
                            },
                        shape = RoundedCornerShape(16.dp),
                        color = if (canSendCode) colors.actionBlue.copy(alpha = 0.14f) else colors.surfaceSubtle,
                        border = BorderStroke(1.dp, if (canSendCode) colors.actionBlue.copy(alpha = 0.35f) else colors.cardBorder)
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            if (isSendingCode) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(18.dp),
                                    strokeWidth = 2.dp,
                                    color = colors.actionBlue
                                )
                            } else {
                                Text(
                                    text = if (countdown > 0) "${countdown}s" else "获取验证码",
                                    color = if (canSendCode) colors.actionBlue else colors.textTertiary,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.SemiBold
                                )
                            }
                        }
                    }
                }
            }

            // 记住登录状态
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "记住登录状态（Keystore 加密）",
                    color = colors.textSecondary,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium
                )
                Switch(
                    checked = persisted.rememberCredentials,
                    onCheckedChange = { viewModel.setRememberCredentials(it) },
                    colors = SwitchDefaults.colors(checkedTrackColor = colors.actionBlue)
                )
            }

            // 提示条
            notice?.let { msg ->
                Surface(
                    shape = RoundedCornerShape(14.dp),
                    color = colors.actionBlue.copy(alpha = 0.1f),
                    border = BorderStroke(0.8.dp, colors.actionBlue.copy(alpha = 0.25f))
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.Top
                    ) {
                        Icon(Icons.Rounded.Info, null, tint = colors.actionBlue, modifier = Modifier.size(16.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(msg, color = colors.textPrimary, fontSize = 12.sp)
                            if (msg.contains("新设备")) {
                                Text(
                                    text = "改用短信验证码",
                                    color = colors.actionBlue,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    modifier = Modifier
                                        .padding(top = 4.dp)
                                        .clickable {
                                            mode = LoginMode.SMS
                                            notice = null
                                        }
                                )
                            }
                        }
                    }
                }
            }

            // 错误条
            errorMessage?.let { err ->
                Surface(
                    shape = RoundedCornerShape(14.dp),
                    color = colors.dangerRed.copy(alpha = 0.1f),
                    border = BorderStroke(0.8.dp, colors.dangerRed.copy(alpha = 0.28f))
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Rounded.Warning, null, tint = colors.dangerRed, modifier = Modifier.size(16.dp))
                        Text(err, color = colors.textPrimary, fontSize = 12.sp, modifier = Modifier.weight(1f))
                        if (err.contains("新设备")) {
                            Text(
                                text = "用短信登录",
                                color = colors.dangerRed,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.clickable {
                                    mode = LoginMode.SMS
                                    errorMessage = null
                                }
                            )
                        }
                    }
                }
            }

            // 提交按钮
            Button(
                onClick = {
                    if (!canSubmit || isSubmitting) return@Button
                    errorMessage = null
                    isSubmitting = true
                    scope.launch {
                        try {
                            if (mode == LoginMode.PASSWORD) {
                                viewModel.loginWithPassword(phone, password)
                            } else {
                                viewModel.loginWithSMS(phone, smsCode)
                            }
                            onDismiss()
                        } catch (e: Throwable) {
                            errorMessage = e.message ?: "登录失败"
                        } finally {
                            isSubmitting = false
                        }
                    }
                },
                enabled = canSubmit && !isSubmitting,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(18.dp),
                colors = ButtonDefaults.buttonColors(containerColor = colors.actionBlue)
            ) {
                if (isSubmitting) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        strokeWidth = 2.dp,
                        color = Color.White
                    )
                    Spacer(Modifier.width(8.dp))
                }
                Text(
                    text = when {
                        isSubmitting -> "正在连接…"
                        mode == LoginMode.PASSWORD -> "登录并同步门锁"
                        else -> "验证并登录"
                    },
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }

            TextButton(
                onClick = onDismiss,
                enabled = !isSubmitting,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = if (persisted.isLoggedIn) "取消" else "暂不登录",
                    color = colors.textSecondary,
                    fontSize = 13.sp
                )
            }
        }
    }
}
