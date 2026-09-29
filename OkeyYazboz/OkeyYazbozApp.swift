//
//  OkeyYazbozApp.swift
//  Şaban Abi Okey 101 Yazboz
//
//  Uygulama giriş noktası.
//

import SwiftUI

@main
struct OkeyYazbozApp: App {
    @StateObject private var store = GameStore()
    @StateObject private var voice = VoiceManager()
    @StateObject private var auth = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(voice)
                .environmentObject(auth)
                .onAppear { store.voice = voice }
        }
    }
}
