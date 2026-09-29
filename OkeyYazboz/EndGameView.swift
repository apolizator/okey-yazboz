//
//  EndGameView.swift
//  Şaban Abi Okey 101 Yazboz
//
//  Oyun sonu: kazanan, süre, 3 liste ve şifreli istatistik onayı.
//

import SwiftUI

struct EndGameView: View {
    @EnvironmentObject var store: GameStore

    @State private var verifiedSeats: Set<Int> = []
    @State private var entrySeat: Int? = nil
    @State private var entryPw = ""
    @State private var showEntry = false
    @State private var wrongPw = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let s = store.state {
                    VStack(spacing: 20) {
                        winnerBanner(s)
                        durationRow(s)
                        teamScores(s)
                        gameRecords(s)
                        threeLists(s)
                        statsGate(s)
                        Button {
                            store.clearGame()
                        } label: {
                            Label("Ana Ekrana Dön", systemImage: "house.fill")
                                .frame(maxWidth: .infinity).padding()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
            .navigationTitle("Oyun Bitti")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { autoVerifyUnprotected() }
            .alert("Şifre", isPresented: $showEntry) {
                SecureField("Şifre", text: $entryPw).keyboardType(.numberPad)
                Button("Onayla") { checkEntry() }
                Button("İptal", role: .cancel) { entryPw = "" }
            } message: {
                Text(wrongPw ? "Şifre yanlış, tekrar dene." : "Bu oyuncunun şifresini gir.")
            }
        }
    }

    // MARK: - İstatistik onay kapısı

    private func statsGate(_ s: GameState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("İstatistiğe İşlemek İçin Şifreler", systemImage: "lock.shield.fill")
                .font(.headline)
            Text("Bu oyunun istatistiklere sayılması için her oyuncu tek tek şifresini girmeli.")
                .font(.caption).foregroundStyle(.secondary)

            ForEach(s.players.sorted { $0.seat < $1.seat }) { p in
                HStack {
                    Circle().fill(p.team == .A ? Color.orange : Color.blue)
                        .frame(width: 12, height: 12)
                    Text(p.name)
                    Spacer()
                    if verifiedSeats.contains(p.seat) {
                        Label("Onaylı", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.caption)
                    } else {
                        Button("Şifre Gir") {
                            entrySeat = p.seat; entryPw = ""; wrongPw = false; showEntry = true
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
                .font(.callout)
            }

            if store.statsCommitted {
                Label("İstatistiklere kaydedildi.", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green).font(.subheadline.bold())
            } else {
                Button {
                    store.commitStats()
                } label: {
                    Label("İstatistiklere Kaydet", systemImage: "square.and.arrow.down.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!allVerified(s))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func allVerified(_ s: GameState) -> Bool {
        s.players.allSatisfy { verifiedSeats.contains($0.seat) }
    }

    private func autoVerifyUnprotected() {
        guard let s = store.state else { return }
        for p in s.players where !store.isProtected(p.name) {
            verifiedSeats.insert(p.seat)
        }
    }

    private func checkEntry() {
        guard let seat = entrySeat, let s = store.state,
              let p = s.players.first(where: { $0.seat == seat }) else { return }
        if store.verifyPassword(name: p.name, password: entryPw) {
            verifiedSeats.insert(seat)
            wrongPw = false
        } else {
            wrongPw = true
            showEntry = true
        }
        entryPw = ""
    }

    // MARK: - Üst bölümler

    private func winnerBanner(_ s: GameState) -> some View {
        let winner: Team = s.teamA <= s.teamB ? .A : .B
        let names = (winner == .A ? s.teamAPlayers : s.teamBPlayers).map(\.name).joined(separator: " & ")
        return VStack(spacing: 8) {
            Image(systemName: "trophy.fill").font(.system(size: 50)).foregroundStyle(.yellow)
            Text("Kazanan: \(winner.displayName)").font(.title.bold())
            Text(names).foregroundStyle(.secondary)
            Text("Fark: \(s.fark)").font(.headline)
        }
        .frame(maxWidth: .infinity).padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func durationRow(_ s: GameState) -> some View {
        HStack {
            Label("Toplam Süre", systemImage: "clock.fill")
            Spacer()
            Text(formatDuration(s.totalDuration)).bold()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func teamScores(_ s: GameState) -> some View {
        HStack(spacing: 14) {
            scoreBox("A Takımı", s.teamA, .orange)
            scoreBox("B Takımı", s.teamB, .blue)
        }
    }

    private func scoreBox(_ t: String, _ v: Int, _ c: Color) -> some View {
        VStack {
            Text(t).font(.subheadline).foregroundStyle(.white)
            Text("\(v)").font(.system(size: 40, weight: .heavy, design: .rounded)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity).padding()
        .background(c.gradient, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Bu oyunun ufak rekorları

    private func gameRecords(_ s: GameState) -> some View {
        let mostEaten = s.players.max(by: { $0.eaten < $1.eaten })
        return VStack(alignment: .leading, spacing: 10) {
            Label("Bu Oyunun Rekorları", systemImage: "rosette").font(.headline)

            recordLine("En yüksek açan",
                       s.bestDuzName.isEmpty ? "—" : "\(s.bestDuzName) (\(s.bestDuzInfo))")
            recordLine("En yüksek çift",
                       s.bestCiftName.isEmpty ? "—" : "\(s.bestCiftName) (\(s.bestCiftValue) çift)")
            recordLine("En çok ceza yiyen",
                       (mostEaten?.eaten ?? 0) > 0 ? "\(mostEaten!.name) (\(mostEaten!.eaten))" : "—")

            if !s.pokes.isEmpty {
                Divider()
                Text("Kim kime soktu").font(.subheadline.bold())
                ForEach(Array(s.pokes.enumerated()), id: \.offset) { _, poke in
                    Text("• \(poke)").font(.caption)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func recordLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.callout)
            Spacer()
            Text(value).font(.callout.bold())
        }
    }

    private func threeLists(_ s: GameState) -> some View {
        VStack(spacing: 16) {
            listCard("🥇 En Çok Ceza Yedirdi (karşıya yazdırdı)",
                     rows: s.players.sorted { $0.inflicted > $1.inflicted }.map { ($0.name, $0.inflicted) })
            listCard("💥 En Çok Ceza Yedi (hatalar)",
                     rows: s.players.sorted { $0.eaten > $1.eaten }.map { ($0.name, $0.eaten) })
            listCard("✋ En Çok Elinde Kaldı",
                     rows: s.players.sorted { $0.leftInHand > $1.leftInHand }.map { ($0.name, $0.leftInHand) })
        }
    }

    private func listCard(_ title: String, rows: [(String, Int)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.bold())
            ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                HStack {
                    Text("\(i + 1).").foregroundStyle(.secondary)
                    Text(r.0)
                    Spacer()
                    Text("\(r.1)").bold().monospacedDigit()
                }
                .font(.callout)
            }
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
