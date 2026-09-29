//
//  AuthGateView.swift
//  Şaban Abi Okey 101 Yazboz
//
//  4 haneli PIN sorar. Doğruysa onUnlock() çağırır.
//

import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    var onUnlock: () -> Void

    @State private var pin = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 56)).foregroundStyle(.yellow)
                Text("Puanları Gör").font(.title2.bold())

                if auth.hasPIN {
                    SecureField("4 haneli PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.title.monospacedDigit())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                    if showError {
                        Text("Yanlış PIN").foregroundStyle(.red).font(.caption)
                    }
                    Button("Onayla") { checkPin() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Text("Henüz PIN ayarlanmadı. Ayarlar'dan 4 haneli PIN belirle.")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top, 40)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
            }
        }
    }

    private func checkPin() {
        if auth.checkPIN(pin) {
            onUnlock()
            dismiss()
        } else {
            showError = true
            pin = ""
        }
    }
}
