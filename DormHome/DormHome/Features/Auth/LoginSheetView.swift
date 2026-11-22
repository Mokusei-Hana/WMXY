//
//  LoginSheetView.swift
//  DormHome
//
//  完美校园账号登录：账密 / 短信验证码，含新设备风控引导。
//

import SwiftUI

struct LoginSheetView: View {
    @EnvironmentObject private var store: DormStore
    @EnvironmentObject private var model: DormAppModel
    @Environment(\.dismiss) private var dismiss

    private enum Mode: String, CaseIterable, Identifiable {
        case password
        case sms

        var id: String { rawValue }
        var title: String { self == .password ? "账号密码" : "短信验证码" }
        var symbol: String { self == .password ? "key.fill" : "message.fill" }
    }

    private enum Field: Hashable {
        case phone
        case password
        case code
    }

    @State private var mode: Mode = .password
    @State private var phone = ""
    @State private var password = ""
    @State private var smsCode = ""
    @State private var showPassword = false
    @State private var isSubmitting = false
    @State private var isSendingCode = false
    @State private var errorMessage: String?
    @State private var notice: String?
    @State private var countdown = 0
    @State private var countdownTask: Task<Void, Never>?

    @FocusState private var focus: Field?

    var body: some View {
        ZStack {
            sheetGlow

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    modePicker
                    fields
                    rememberRow
                    if let notice {
                        noticeBanner(notice)
                    }
                    if let errorMessage {
                        errorBanner(errorMessage)
                    }
                    submitButton
                    cancelButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(.ultraThinMaterial)
        .interactiveDismissDisabled(isSubmitting)
        .onAppear {
            if phone.isEmpty {
                phone = store.phone ?? CredentialVault.load()?.phone ?? ""
            }
            if let incoming = model.loginNotice {
                notice = incoming
                if incoming.contains("新设备") {
                    withAnimation(AppTheme.stateSpring) { mode = .sms }
                }
                model.loginNotice = nil
            }
        }
        .onDisappear {
            countdownTask?.cancel()
        }
    }

    // MARK: - 背景光

    private var sheetGlow: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .fill(AppTheme.actionBlue.opacity(0.10))
                    .frame(width: 300, height: 300)
                    .blur(radius: 70)
                    .position(x: proxy.size.width * 0.15, y: 90)
                Circle()
                    .fill(AppTheme.onlineGreen.opacity(0.07))
                    .frame(width: 260, height: 260)
                    .blur(radius: 80)
                    .position(x: proxy.size.width * 0.9, y: proxy.size.height * 0.45)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    // MARK: - 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.actionCyan.opacity(0.9), AppTheme.actionBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "door.left.hand.open")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 52, height: 52)
                .shadow(color: AppTheme.actionBlue.opacity(0.3), radius: 14, y: 6)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("关闭登录页")
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("登录完美校园")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("登录后即可远程开锁与查看宿舍水电")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 模式选择

    private var modePicker: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(Mode.allCases) { item in
                    Button {
                        withAnimation(AppTheme.stateSpring) {
                            mode = item
                            errorMessage = nil
                            focus = nil
                        }
                        Haptics.impact(.light)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 12, weight: .semibold))
                            Text(item.title)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(mode == item ? AppTheme.actionBlue : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(
                        .regular
                            .tint(mode == item ? AppTheme.actionBlue.opacity(0.22) : nil)
                            .interactive(),
                        in: Capsule(style: .continuous)
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                mode == item ? AppTheme.actionBlue.opacity(0.32) : Color.clear,
                                lineWidth: 1
                            )
                    }
                }
            }
        }
    }

    // MARK: - 表单

    private var fields: some View {
        VStack(spacing: 14) {
            FieldShell(title: "手机号", symbol: "iphone") {
                TextField("完美校园手机号", text: $phone)
                    .font(.system(size: 15, weight: .medium))
                    .keyboardType(.numberPad)
                    .textContentType(.telephoneNumber)
                    .focused($focus, equals: .phone)
                    .onChange(of: phone) { _, newValue in
                        let digits = newValue.filter(\.isNumber)
                        if digits.count > 11 {
                            phone = String(digits.prefix(11))
                        } else if digits != newValue {
                            phone = digits
                        }
                    }

                if !phone.isEmpty {
                    Text("\(phone.count)/11")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(phone.count == 11 ? AppTheme.onlineGreen : Color.secondary)
                        .monospacedDigit()
                }
            }

            if mode == .password {
                FieldShell(title: "密码", symbol: "lock.fill") {
                    Group {
                        if showPassword {
                            TextField("完美校园登录密码", text: $password)
                                .textContentType(.password)
                        } else {
                            SecureField("完美校园登录密码", text: $password)
                                .textContentType(.password)
                        }
                    }
                    .font(.system(size: 15, weight: .medium))
                    .focused($focus, equals: .password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showPassword ? "隐藏密码" : "显示密码")
                }
            } else {
                HStack(spacing: 10) {
                    FieldShell(title: "短信验证码", symbol: "message.badge.fill") {
                        TextField("6 位验证码", text: $smsCode)
                            .font(.system(size: 15, weight: .medium))
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .focused($focus, equals: .code)
                            .onChange(of: smsCode) { _, newValue in
                                let digits = newValue.filter(\.isNumber)
                                smsCode = String(digits.prefix(8))
                            }
                    }

                    Button {
                        requestCode()
                    } label: {
                        Group {
                            if isSendingCode {
                                ProgressView().controlSize(.small)
                            } else {
                                Text(countdown > 0 ? "\(countdown)s" : "获取验证码")
                                    .font(.system(size: 12, weight: .semibold))
                                    .monospacedDigit()
                            }
                        }
                        .foregroundStyle(canSendCode ? AppTheme.actionBlue : Color.secondary)
                        .frame(width: 82, height: 52)
                    }
                    .buttonStyle(.glass)
                    .tint(canSendCode ? AppTheme.actionBlue : Color.secondary.opacity(0.45))
                    .disabled(!canSendCode)
                    .padding(.top, 25)
                }
            }
        }
    }

    private var rememberRow: some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { store.rememberCredentials },
                set: { store.setRememberCredentials($0) }
            )) {
                Text("记住登录状态")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .toggleStyle(.switch)
            .tint(AppTheme.actionBlue)
            .controlSize(.mini)

            Spacer(minLength: 0)

            Image(systemName: "key.fill")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 提示条

    private func noticeBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.actionBlue)
            VStack(alignment: .leading, spacing: 5) {
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if text.contains("新设备") {
                    Button("改用短信验证码") {
                        withAnimation(AppTheme.stateSpring) { mode = .sms }
                        notice = nil
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.actionBlue)
                }
            }
            Spacer(minLength: 0)
            Button {
                notice = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.actionBlue.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.actionBlue.opacity(0.18), lineWidth: 0.8)
        }
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.dangerRed)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if text.contains("新设备") {
                Button("用短信登录") {
                    withAnimation(AppTheme.stateSpring) {
                        mode = .sms
                        errorMessage = nil
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.dangerRed)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.dangerRed.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.dangerRed.opacity(0.18), lineWidth: 0.8)
        }
    }

    // MARK: - 操作

    private var submitButton: some View {
        Button {
            submit()
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: mode == .password ? "lock.open.fill" : "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(isSubmitting ? "正在连接…" : (mode == .password ? "登录并同步门锁" : "验证并登录"))
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(canSubmit || isSubmitting ? Color.white : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.glassProminent)
        .tint(canSubmit || isSubmitting ? AppTheme.actionBlue : Color.secondary.opacity(0.45))
        .disabled(isSubmitting || !canSubmit)
    }

    private var cancelButton: some View {
        Button {
            dismiss()
        } label: {
            Text(store.isLoggedIn ? "取消" : "暂不登录")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 逻辑

    private var isPhoneValid: Bool {
        phone.count == 11 && phone.allSatisfy(\.isNumber) && phone.hasPrefix("1")
    }

    private var canSendCode: Bool {
        isPhoneValid && !isSendingCode && countdown == 0
    }

    private var canSubmit: Bool {
        guard isPhoneValid else { return false }
        switch mode {
        case .password:
            return !password.isEmpty
        case .sms:
            return smsCode.count >= 4
        }
    }

    private func submit() {
        guard canSubmit else {
            errorMessage = mode == .password ? "请填写手机号与密码" : "请填写手机号与短信验证码"
            Haptics.notify(.error)
            return
        }
        focus = nil
        errorMessage = nil
        isSubmitting = true

        Task { @MainActor in
            do {
                if mode == .password {
                    try await model.loginWithPassword(phone: phone, password: password)
                } else {
                    try await model.loginWithSMS(phone: phone, code: smsCode)
                }
                Haptics.notify(.success)
                dismiss()
            } catch {
                Haptics.notify(.error)
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isSubmitting = false
        }
    }

    private func requestCode() {
        guard isPhoneValid else { return }
        isSendingCode = true
        errorMessage = nil

        Task { @MainActor in
            do {
                try await model.requestSMSCode(phone: phone)
                startCountdown()
                model.showToast("验证码已发送，请查看短信", style: .success)
                focus = .code
            } catch {
                Haptics.notify(.error)
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isSendingCode = false
        }
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdown = 60
        countdownTask = Task { @MainActor in
            while countdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                countdown -= 1
            }
        }
    }
}

// MARK: - 表单外壳

private struct FieldShell<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                content
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.8)
            }
        }
    }
}

#Preview {
    LoginSheetPreview()
}

private struct LoginSheetPreview: View {
    @StateObject private var store = DormStore()
    @StateObject private var model: DormAppModel

    init() {
        let store = DormStore()
        _store = StateObject(wrappedValue: store)
        _model = StateObject(wrappedValue: DormAppModel(store: store))
    }

    var body: some View {
        Color.clear
            .sheet(isPresented: .constant(true)) {
                LoginSheetView()
                    .environmentObject(store)
                    .environmentObject(model)
            }
    }
}
