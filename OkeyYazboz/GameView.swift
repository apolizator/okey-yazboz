//
//  GameView.swift
//  Şaban Abi Okey 101 Yazboz
//
//  4 köşe masa düzeni (elmas). Oyuncuya dokun → menü açılır.
//

import SwiftUI
import Combine
import UIKit

struct GameView: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var auth: AuthManager
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedSeat: Int? = nil
    @State private var showAuthGate = false
    @State private var showReveal = false
    @State private var showFinishSheet = false
    @State private var showCalc = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.06, green: 0.30, blue: 0.16),
                                    Color(red: 0.03, green: 0.16, blue: 0.09)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            if let s = store.state {
                table(for: s)
                topBar(for: s)
            }
        }
        .onChange(of: scenePhase) { phase in
            // Tuş kilidi açılıp ekran öne gelince anında güncelle.
            if phase == .active {
                store.objectWillChange.send()
            }
        }
        .sheet(item: Binding(get: { selectedSeat.map { SeatBox(seat: $0) } },
                             set: { selectedSeat = $0?.seat })) { box in
            PlayerActionView(seat: box.seat)
        }
        .sheet(isPresented: $showFinishSheet) {
            FinishSheetView()
        }
        .sheet(isPresented: $showCalc) {
            YanCalculatorView()
        }
        .sheet(isPresented: $showReveal, onDismiss: { store.revealUnlocked = false }) {
            RevealView()
        }
        .sheet(item: $store.roundSummary) { summary in
            RoundSummaryView(summary: summary)
        }
        .sheet(isPresented: $showAuthGate) {
            AuthGateView {
                store.revealUnlocked = true
                showReveal = true
            }
        }
    }

    // MARK: - Üst bar

    private func topBar(for s: GameState) -> some View {
        VStack {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TUR \(s.currentHand) / \(s.totalHands)")
                        .font(.headline.bold()).foregroundStyle(.yellow)
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(formatDuration(Date().timeIntervalSince(s.handStart)))
                            .font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()

                // Gizli skor rozeti
                scoreBadge(for: s)

                Button { store.undo() } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.title2)
                }
                .disabled(!store.canUndo)
                .foregroundStyle(store.canUndo ? .white : .white.opacity(0.3))

                Button { showCalc = true } label: {
                    Image(systemName: "function").font(.title3)
                        .foregroundStyle(.white)
                }

                Button { showAuthGate = true } label: {
                    Image(systemName: "lock.fill").font(.title3)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            Spacer()
        }
    }

    private func scoreBadge(for s: GameState) -> some View {
        HStack(spacing: 6) {
            teamPill("A", value: store.scoresVisible ? "\(s.teamA)" : "???", color: .orange)
            teamPill("B", value: store.scoresVisible ? "\(s.teamB)" : "???", color: .blue)
        }
    }

    private func teamPill(_ t: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(t).font(.caption2.bold())
            Text(value).font(.caption.bold().monospacedDigit())
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.85), in: Capsule())
        .foregroundStyle(.white)
    }

    // MARK: - Masa

    private func table(for s: GameState) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Orta elmas
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.18), lineWidth: 2)
                    .frame(width: min(w, h) * 0.5, height: min(w, h) * 0.5)
                    .rotationEffect(.degrees(45))
                    .position(x: w/2, y: h/2)

                // Ortadaki El Bitti butonu
                Button { showFinishSheet = true } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "flag.checkered.circle.fill")
                            .font(.system(size: 34))
                        Text("EL BİTTİ")
                            .font(.headline.bold())
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 22).padding(.vertical, 14)
                    .background(.yellow, in: Capsule())
                    .shadow(radius: 6)
                }
                .position(x: w/2, y: h/2)

                // 4 köşe: 0 alt, 1 sağ, 2 üst, 3 sol
                corner(for: s, seat: 2).position(x: w/2, y: h * 0.14)
                corner(for: s, seat: 0).position(x: w/2, y: h * 0.86)
                corner(for: s, seat: 3).position(x: w * 0.20, y: h/2)
                corner(for: s, seat: 1).position(x: w * 0.80, y: h/2)
            }
        }
    }

    private func corner(for s: GameState, seat: Int) -> some View {
        let player = s.player(seat: seat)
        let team = Team.forSeat(seat)
        let opened = player?.opened == true
        return Button { selectedSeat = seat } label: {
            VStack(spacing: 6) {
                ZStack {
                    if let name = player?.name,
                       let data = store.photoData(for: name),
                       let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable().scaledToFill()
                            .frame(width: 74, height: 74)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(team == .A ? Color.orange : Color.blue, lineWidth: 3))
                    } else {
                        Circle().fill(team == .A ? Color.orange : Color.blue)
                            .frame(width: 74, height: 74)
                        Text(initials(player?.name ?? "?"))
                            .font(.title2.bold()).foregroundStyle(.white)
                    }
                    if opened {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3).foregroundStyle(.green)
                            .background(Circle().fill(.white))
                            .offset(x: 28, y: 28)
                    }
                }
                Text(player?.name ?? "—")
                    .font(.subheadline.bold()).foregroundStyle(.white)
                    .lineLimit(1)
                // Açılış bilgisi (gizli değil, herkes görür)
                if opened, let info = player?.openInfo, !info.isEmpty {
                    Text(info)
                        .font(.caption2.bold())
                        .foregroundStyle(.yellow)
                        .lineLimit(1)
                } else {
                    Text("açmadı")
                        .font(.caption2).foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(10)
            .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if let f = parts.first?.first {
            if parts.count > 1, let s = parts[1].first { return "\(f)\(s)".uppercased() }
            return String(f).uppercased()
        }
        return "?"
    }
}

/// Sheet(item:) için Identifiable kutu.
struct SeatBox: Identifiable {
    let seat: Int
    var id: Int { seat }
}

// MARK: - Tur sonu takım ceza özeti

struct RoundSummaryView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let summary: RoundSummary

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Text("\(summary.hand). TUR BİTTİ")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.yellow)

                Text("Bu tur hangi takım kaç ceza yedi")
                    .font(.subheadline).foregroundStyle(.secondary)

                HStack(spacing: 14) {
                    teamCard(summary.teamANames, summary.teamAPoints, .orange)
                    teamCard(summary.teamBNames, summary.teamBPoints, .blue)
                }

                Spacer()

                Button {
                    store.advanceAfterSummary()
                    dismiss()
                } label: {
                    Label(summary.isLastHand ? "Sonuçları Gör" : "Sıradaki Tur",
                          systemImage: summary.isLastHand ? "trophy.fill" : "arrow.right.circle.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity).padding()
                        .background(.yellow, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.black)
                }
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(true)
        }
    }

    private func teamCard(_ names: [String], _ points: Int, _ color: Color) -> some View {
        VStack(spacing: 8) {
            ForEach(names, id: \.self) { Text($0).font(.subheadline.bold()).foregroundStyle(.white) }
            Text("\(points)")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("ceza").font(.caption2).foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity).padding()
        .background(color.gradient, in: RoundedRectangle(cornerRadius: 18))
    }
}
