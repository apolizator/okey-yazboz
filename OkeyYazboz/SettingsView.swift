//
//  SettingsView.swift
//  Şaban Abi Okey 101 Yazboz
//
//  PIN, seslendirme aç/kapa ve sesli metin şablonunu düzenleme.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var voice: VoiceManager
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var store: GameStore

    @State private var newPin = ""
    @State private var pinSaved = false
    @State private var templateText = ""
    @State private var templateSaved = false
    @State private var showResetConfirm = false

    var body: some View {
        Form {
            Section("Seslendirme") {
                Toggle("Sesli anlatım açık", isOn: $voice.enabled)
                Button("Test et") {
                    voice.speakRaw("Şaban abi okey yazboz hazır. Hadi başlayalım.")
                }
            }

            Section("Şifre (PIN)") {
                SecureField("Yeni 4 haneli PIN", text: $newPin)
                    .keyboardType(.numberPad)
                Button("PIN'i Kaydet") {
                    auth.setPIN(newPin)
                    pinSaved = true
                    newPin = ""
                }
                .disabled(newPin.count < 4)
                if pinSaved {
                    Label("PIN kaydedildi", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green).font(.caption)
                }
                Text("Maç sırasında 'kilit' tuşuna basıp PIN ile puanlara bakabilirsin.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Sesli Metin Şablonu") {
                Text("Her [BASLIK] altına 2-3 cümle yaz; uygulama rastgele seslendirir. {oyuncu}, {tas}, {ceza} gibi etiketler kullanabilirsin.")
                    .font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $templateText)
                    .frame(minHeight: 240)
                    .font(.system(.footnote, design: .monospaced))
                Button("Şablonu Kaydet") {
                    voice.saveTemplate(templateText)
                    templateSaved = true
                }
                if templateSaved {
                    Label("Şablon kaydedildi", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green).font(.caption)
                }
                Button(role: .destructive) {
                    voice.resetTemplateToDefault()
                    templateText = voice.currentTemplateText
                    templateSaved = false
                } label: {
                    Label("Varsayılana Dön (hazır hakaretler)", systemImage: "arrow.counterclockwise")
                }
            }

            Section("Veri") {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("İstatistikleri Sıfırla", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { templateText = voice.currentTemplateText }
        .confirmationDialog("İstatistikler silinsin mi?", isPresented: $showResetConfirm) {
            Button("Sil", role: .destructive) {
                store.profiles.removeAll()
                store.saveProfiles()
            }
            Button("Vazgeç", role: .cancel) {}
        }
    }
}
