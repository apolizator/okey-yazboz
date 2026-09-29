//
//  StatsView.swift
//  Şaban Abi Okey 101 Yazboz
//
//  Oyuncu istatistikleri ve rekorlar.
//

import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: GameStore
    @State private var showReset = false

    var body: some View {
        List {
            if store.profiles.isEmpty {
                Text("Henüz oyun oynanmadı.")
                    .foregroundStyle(.secondary)
            } else {
                Section("Rekorlar") {
                    if let topWinner = store.profiles.max(by: { $0.gamesWon < $1.gamesWon }) {
                        recordRow("En çok kazanan", topWinner.name, "\(topWinner.gamesWon) galibiyet")
                    }
                    if let topMargin = store.profiles.max(by: { $0.biggestWinMargin < $1.biggestWinMargin }) {
                        recordRow("En yüksek fark rekoru", topMargin.name, "\(topMargin.biggestWinMargin) fark")
                    }
                    if let mostInflicted = store.profiles.max(by: { $0.totalInflicted < $1.totalInflicted }) {
                        recordRow("En çok ceza yedirdi", mostInflicted.name, "\(mostInflicted.totalInflicted)")
                    }
                    if let mostEaten = store.profiles.max(by: { $0.totalEaten < $1.totalEaten }) {
                        recordRow("En çok ceza yedi", mostEaten.name, "\(mostEaten.totalEaten)")
                    }
                }

                Section("Oyuncular") {
                    ForEach(store.profiles.sorted { $0.gamesWon > $1.gamesWon }) { p in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(p.name).font(.headline)
                                Spacer()
                                Text("%\(Int(p.winRate * 100)) kazanma")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text("\(p.gamesPlayed) oyun • \(p.gamesWon) galibiyet • en yüksek fark \(p.biggestWinMargin)")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Yedirdiği: \(p.totalInflicted) • Yediği: \(p.totalEaten) • Elinde: \(p.totalLeftInHand)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section {
                    Button(role: .destructive) { showReset = true } label: {
                        Label("Tüm İstatistikleri Sıfırla", systemImage: "trash.fill")
                    }
                }
            }
        }
        .navigationTitle("İstatistikler")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Tüm istatistikler silinsin mi?", isPresented: $showReset, titleVisibility: .visible) {
            Button("Hepsini Sil", role: .destructive) {
                store.profiles.removeAll()
                store.saveProfiles()
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Oyuncu profilleri, galibiyetler ve rekorlar tamamen silinir. Geri alınamaz.")
        }
    }

    private func recordRow(_ title: String, _ name: String, _ detail: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            VStack(alignment: .trailing) {
                Text(name).bold()
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
