//
//  AuthManager.swift
//  Şaban Abi Okey 101 Yazboz
//
//  Şifreli gösterim: 4 haneli PIN ile puanları geçici açar.
//

import Foundation
import Combine

final class AuthManager: ObservableObject {

    private let pinKey = "scorePIN"

    var hasPIN: Bool {
        !(UserDefaults.standard.string(forKey: pinKey) ?? "").isEmpty
    }

    func setPIN(_ pin: String) {
        UserDefaults.standard.set(pin, forKey: pinKey)
    }

    func checkPIN(_ pin: String) -> Bool {
        guard let saved = UserDefaults.standard.string(forKey: pinKey), !saved.isEmpty else {
            return false
        }
        return saved == pin
    }
}
