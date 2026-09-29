//
//  ContentView.swift
//  Şaban Abi Okey 101 Yazboz
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        Group {
            if let s = store.state {
                if s.finished {
                    EndGameView()
                } else {
                    GameView()
                }
            } else {
                HomeView()
            }
        }
        .animation(.easeInOut, value: store.state?.finished)
    }
}

// MARK: - Ana ekran (oyun yokken)

struct HomeView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.05, green: 0.18, blue: 0.10),
                                        Color(red: 0.02, green: 0.08, blue: 0.05)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer()
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.yellow)
                    Text("ŞABAN ABİ\nOKEY 101 YAZBOZ")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    Spacer()

                    NavigationLink {
                        SetupView()
                    } label: {
                        Label("Yeni Oyun", systemImage: "play.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.yellow, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.black)
                    }

                    HStack(spacing: 14) {
                        NavigationLink {
                            StatsView()
                        } label: {
                            Label("İstatistik", systemImage: "chart.bar.fill")
                                .frame(maxWidth: .infinity).padding()
                                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                        }
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Label("Ayarlar", systemImage: "gearshape.fill")
                                .frame(maxWidth: .infinity).padding()
                                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(24)
            }
        }
    }
}
