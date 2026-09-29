//
//  RevealView.swift
//  Şaban Abi Okey 101 Yazboz
//
//  Gizli puanların gösterildiği ekran (sondan bir önceki el
//  veya şifreyle bakış). Adım adım el geçmişi de burada.
//

import SwiftUI

struct RevealView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    var isPenultimate: Bool = false

    @State private var animate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let s = store.state {
                        if isPenultimate {
                            Text("SON EL!")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundStyle(.yellow)
                                .scaleEffect(animate ? 1 : 0.5)
                                .opacity(animate ? 1 : 0)
                        }

                        scoreboard(s)
                        differenceView(s)
                        threeLists(s)
                        history(s)
                    }
                }
                .padding()
            }
            .navigationTitle(isPenultimate ? "Puanlar Açıldı" : "Güncel Durum")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { animate = true }
        }
    }

    private func scoreboard(_ s: GameState) -> some View {
        HStack(spacing: 14) {
            teamCard("A Takımı", s.teamAPlayers, s.teamA, .orange)
            teamCard("B Takımı", s.teamBPlayers, s.teamB, .blue)
        }
    }

    private func teamCard(_ title: String, _ players: [Player], _ score: Int, _ color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.headline).foregroundStyle(.white)
            Text("\(score)")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            ForEach(players) { p in
                Text(p.name).font(.caption).foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.gradient, in: RoundedRectangle(cornerRadius: 18))
    }

    private func differenceView(_ s: GameState) -> some View {
        let leader = s.teamA <= s.teamB ? "A Takımı" : "B Takımı"
        return VStack(spacing: 4) {
            Text("Fark: \(s.fark)")
                .font(.title2.bold())
            Text("Önde: \(leader) (az olan iyi)")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func threeLists(_ s: GameState) -> some View {
        VStack(spacing: 16) {
            listCard("Karşıya Yazdırılan Ceza (yedirdiği)", icon: "arrow.up.forward",
                     rows: s.players.sorted { $0.inflicted > $1.inflicted }.map { ($0.name, $0.inflicted) })
            listCard("Yenen Ceza (hatalar)", icon: "arrow.down.forward",
                     rows: s.players.sorted { $0.eaten > $1.eaten }.map { ($0.name, $0.eaten) })
            listCard("Elinde Kalan", icon: "hand.raised",
                     rows: s.players.sorted { $0.leftInHand > $1.leftInHand }.map { ($0.name, $0.leftInHand) })
        }
    }

    private func listCard(_ title: String, icon: String, rows: [(String, Int)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.subheadline.bold())
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                HStack {
                    Text(r.0)
                    Spacer()
                    Text("\(r.1)").bold().monospacedDigit()
                }
                .font(.callout)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func history(_ s: GameState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Adım Adım Geçmiş", systemImage: "list.bullet.rectangle").font(.subheadline.bold())
            ForEach(s.log.reversed()) { e in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(e.handNumber).")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                        .frame(width: 26, alignment: .trailing)
                    Text(e.text).font(.caption)
                    Spacer()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
