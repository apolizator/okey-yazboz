//
//  SetupView.swift
//  Şaban Abi Okey 101 Yazboz
//
//  Yeni oyun kurulumu: oyuncular + şifreler + el sayısı + takımlar.
//

import SwiftUI
import PhotosUI
import UIKit

struct SetupView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    // 0=alt, 1=sağ, 2=üst, 3=sol
    @State private var names: [String] = ["", "", "", ""]
    @State private var passwords: [String] = ["", "", "", ""]
    @State private var photoItems: [PhotosPickerItem?] = [nil, nil, nil, nil]
    @State private var totalHands: Int = 13
    @State private var errorText: String? = nil

    private let seatLabels = ["Alt (Sen)", "Sağ", "Üst", "Sol"]

    var body: some View {
        Form {
            Section("Oyuncular + şifre (karşılıklı = aynı takım)") {
                ForEach(0..<4, id: \.self) { seat in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            avatarPicker(seat)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    TextField(seatLabels[seat], text: $names[seat])
                                        .textInputAutocapitalization(.words)
                                    Text(Team.forSeat(seat).rawValue)
                                        .font(.caption.bold()).foregroundStyle(.secondary)
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: store.isProtected(names[seat]) ? "lock.fill" : "lock.open")
                                        .font(.caption).foregroundStyle(.secondary)
                                    SecureField(passwordPrompt(seat), text: $passwords[seat])
                                        .keyboardType(.numberPad)
                                        .font(.callout)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                Text("A Takımı: Alt + Üst   •   B Takımı: Sağ + Sol")
                    .font(.caption).foregroundStyle(.secondary)
                Text("İsme bir kez şifre konunca, o ismi başkası şifresiz kullanamaz.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if !store.profiles.isEmpty {
                Section("Kayıtlı oyuncular (dokun = ilk boşa yaz)") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(store.profiles) { p in
                                Button(p.name) { fillFirstEmpty(p.name) }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }

            Section("El Sayısı") {
                Stepper("Toplam \(totalHands) el", value: $totalHands, in: 1...51)
                Text("Puanlar gizli kalır; \(max(1,totalHands-1)). el bitince patlar.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let e = errorText {
                Section {
                    Label(e, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red).font(.caption)
                }
            }

            Section {
                Button {
                    start()
                } label: {
                    Label("Oyunu Başlat", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Yeni Oyun")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func avatarPicker(_ seat: Int) -> some View {
        let team = Team.forSeat(seat)
        PhotosPicker(selection: $photoItems[seat], matching: .images, photoLibrary: .shared()) {
            ZStack {
                if !names[seat].isEmpty,
                   let data = store.photoData(for: names[seat]),
                   let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable().scaledToFill()
                        .frame(width: 44, height: 44).clipShape(Circle())
                        .overlay(Circle().stroke(team == .A ? Color.orange : Color.blue, lineWidth: 2))
                } else {
                    Circle().fill(team == .A ? Color.orange : Color.blue)
                        .frame(width: 44, height: 44)
                    Image(systemName: "camera.fill").font(.caption).foregroundStyle(.white)
                }
            }
        }
        .onChange(of: photoItems[seat]) { item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    await MainActor.run { store.setPhoto(name: names[seat], data: data) }
                }
            }
        }
    }

    private func passwordPrompt(_ seat: Int) -> String {
        if names[seat].trimmingCharacters(in: .whitespaces).isEmpty { return "Şifre" }
        return store.isProtected(names[seat]) ? "Bu ismin şifresini gir" : "Bu isme şifre belirle"
    }

    /// Tüm isimler için şifre kontrolü yapıp oyunu başlatır.
    private func start() {
        for seat in 0..<4 {
            let name = names[seat].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }   // boşsa "Oyuncu N" olur, şifresiz
            let pw = passwords[seat]

            if store.isProtected(name) {
                if pw.isEmpty {
                    errorText = "\(name) için şifre gir."
                    return
                }
                if !store.verifyPassword(name: name, password: pw) {
                    errorText = "\(name) için şifre yanlış."
                    return
                }
            } else {
                // Yeni isim: şifre belirlenmeli.
                if pw.count < 1 {
                    errorText = "\(name) için bir şifre belirle."
                    return
                }
            }
        }
        errorText = nil
        store.newGame(seatNames: names, passwords: passwords, totalHands: totalHands)
        dismiss()
    }

    private func fillFirstEmpty(_ name: String) {
        if let i = names.firstIndex(where: { $0.isEmpty }) {
            names[i] = name
        }
    }
}
