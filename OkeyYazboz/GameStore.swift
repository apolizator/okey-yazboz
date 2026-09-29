//
//  GameStore.swift
//  Şaban Abi Okey 101 Yazboz
//

import Foundation
import SwiftUI
import Combine
import CryptoKit

func formatDuration(_ t: TimeInterval) -> String {
    let total = Int(t)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 { return String(format: "%d sa %02d dk", h, m) }
    if m > 0 { return String(format: "%d dk %02d sn", m, s) }
    return String(format: "%d sn", s)
}

final class GameStore: ObservableObject {

    @Published var state: GameState?
    @Published var profiles: [PlayerProfile] = []

    @Published var revealUnlocked: Bool = false
    @Published var showPenultimateReveal: Bool = false
    @Published var roundSummary: RoundSummary? = nil
    @Published var statsCommitted: Bool = false

    weak var voice: VoiceManager?

    private var undoStack: [GameState] = []

    private let stateKey = "activeGameState"
    private let profilesKey = "playerProfiles"

    init() {
        loadProfiles()
        loadState()
    }

    var hasActiveGame: Bool { state != nil && !(state?.finished ?? false) }
    var canUndo: Bool { !undoStack.isEmpty }

    var scoresVisible: Bool {
        guard let s = state else { return false }
        return s.finished || revealUnlocked || s.currentHand >= s.totalHands
    }

    private func playerIndex(seat: Int) -> Int? {
        state?.players.firstIndex { $0.seat == seat }
    }

    private func addTeamScore(_ team: Team, _ amount: Int) {
        guard state != nil else { return }
        if team == .A { state!.teamA += amount } else { state!.teamB += amount }
    }

    func donorSeat(for seat: Int) -> Int { (seat + 3) % 4 }

    func hash(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func profile(named name: String) -> PlayerProfile? {
        let n = name.trimmingCharacters(in: .whitespaces).lowercased()
        return profiles.first { $0.name.lowercased() == n }
    }

    func photoData(for name: String) -> Data? { profile(named: name)?.photoData }

    func setPhoto(name: String, data: Data?) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let i = profiles.firstIndex(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            profiles[i].photoData = data
        } else {
            var p = PlayerProfile(name: trimmed)
            p.photoData = data
            profiles.append(p)
        }
        saveProfiles()
    }

    func isProtected(_ name: String) -> Bool {
        (profile(named: name)?.passwordHash?.isEmpty == false)
    }

    func verifyPassword(name: String, password: String) -> Bool {
        guard let h = profile(named: name)?.passwordHash, !h.isEmpty else { return true }
        return h == hash(password)
    }

    func reservePlayer(name: String, password: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let i = profiles.firstIndex(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            if (profiles[i].passwordHash ?? "").isEmpty && !password.isEmpty {
                profiles[i].passwordHash = hash(password)
            }
        } else {
            var prof = PlayerProfile(name: trimmed)
            if !password.isEmpty { prof.passwordHash = hash(password) }
            profiles.append(prof)
        }
        saveProfiles()
    }

    func newGame(seatNames: [String], passwords: [String], totalHands: Int) {
        var players: [Player] = []
        for seat in 0..<4 {
            let name = seat < seatNames.count && !seatNames[seat].isEmpty
                ? seatNames[seat] : "Oyuncu \(seat + 1)"
            players.append(Player(name: name, seat: seat))
            let pw = seat < passwords.count ? passwords[seat] : ""
            reservePlayer(name: name, password: pw)
        }
        var s = GameState(players: players, totalHands: max(1, totalHands))
        s.gameStart = Date()
        s.handStart = Date()
        s.log.append(LogEntry(handNumber: 1, text: "Oyun başladı. \(totalHands) el."))
        undoStack.removeAll()
        revealUnlocked = false
        statsCommitted = false
        state = s
        saveState()
        voice?.speak("OYUN_BASLADI", context: VoiceContext(el: 1))
    }

    private func pushUndo() {
        guard let s = state else { return }
        undoStack.append(s)
        if undoStack.count > 200 { undoStack.removeFirst() }
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        state = last
        saveState()
        voice?.speak("GERI_ALINDI")
    }

    func duzInfo(duz: Int, yan: Int) -> (value: Int, text: String) {
        let value = duz * 3 + yan
        let base = value / 3
        let rem = value % 3
        let text = rem == 0 ? "\(base)" : "\(base) yan \(rem)"
        return (value, text)
    }

    func minDuzValue(for seat: Int) -> Int {
        guard let s = state, let me = s.player(seat: seat) else { return 101 }
        var m = 101
        for p in s.players where p.team != me.team && p.opened && !p.openedPairs {
            m = max(m, p.openValue + 1)
        }
        return m
    }

    func minPairs(for seat: Int) -> Int {
        guard let s = state, let me = s.player(seat: seat) else { return 5 }
        var m = 5
        for p in s.players where p.team != me.team && p.opened && p.openedPairs {
            m = max(m, p.openValue + 1)
        }
        return m
    }

    func applyAction(kind: ActionKind, seat: Int,
                         count: Int = 0, yan: Int = 0, targetSeat: Int? = nil,
                         fromDiscard: Bool = false, discardedTile: Int = 0) {
            guard let idx = playerIndex(seat: seat), state != nil else { return }
            pushUndo()

            let p = state!.players[idx]
            let team = p.team
            var logText = ""
            var ctx = VoiceContext(oyuncu: p.name, el: state!.currentHand)

            switch kind {

            case .openStraight:
                let info = duzInfo(duz: count, yan: yan)
                ctx.sayi = info.text
                state!.players[idx].opened = true
                state!.players[idx].openedPairs = false
                state!.players[idx].openValue = info.value
                state!.players[idx].openInfo = info.text + " düz"
                if info.value > state!.bestDuzValue {
                    state!.bestDuzValue = info.value
                    state!.bestDuzName = p.name
                    state!.bestDuzInfo = info.text
                }
                
                var keysToSpeak: [String] = []
                
                if fromDiscard {
                    let tSeat = donorSeat(for: seat)
                    if let tIdx = playerIndex(seat: tSeat) {
                        let target = state!.players[tIdx]
                        let ceza = discardedTile * 10
                        state!.players[idx].inflicted += ceza
                        state!.players[tIdx].eaten += ceza
                        addTeamScore(target.team, ceza)
                        ctx.hedef = target.name
                        ctx.tas = discardedTile
                        ctx.kat = 10
                        ctx.ceza = ceza
                        state!.pokes.append("\(p.name) → \(target.name) (\(discardedTile) atıp açtırdı)")
                        logText = "\(p.name) yandan aldı (\(discardedTile)), \(target.name)'e \(ceza) ceza. "
                        
                        // 1. Cümle: Yandan aldığı taşın numarasına özel laf
                        keysToSpeak.append("YANDAN_ALIP_\(discardedTile)")
                    }
                }
                
                logText += "\(p.name) düz açtı (\(info.text))."
                
                // 2. Cümle: 50 üstü açtıysa eklenecek, veya sadece normal açtıysa
                if info.value >= 50 {
                    keysToSpeak.append("DUZ_50_USTU")
                } else if !fromDiscard {
                    keysToSpeak.append("DUZ_ACTI")
                }
                
                if !keysToSpeak.isEmpty {
                    voice?.speak(keys: keysToSpeak, context: ctx)
                }

            case .openPairs:
                ctx.sayi = "\(count)"
                state!.players[idx].opened = true
                state!.players[idx].openedPairs = true
                state!.players[idx].openValue = count
                state!.players[idx].openInfo = "\(count) çift"
                if count > state!.bestCiftValue {
                    state!.bestCiftValue = count
                    state!.bestCiftName = p.name
                }
                
                var keysToSpeak: [String] = []
                
                if fromDiscard {
                    let tSeat = donorSeat(for: seat)
                    if let tIdx = playerIndex(seat: tSeat) {
                        let target = state!.players[tIdx]
                        let ceza = discardedTile * 20
                        state!.players[idx].inflicted += ceza
                        state!.players[tIdx].eaten += ceza
                        addTeamScore(target.team, ceza)
                        ctx.hedef = target.name
                        ctx.tas = discardedTile
                        ctx.kat = 20
                        ctx.ceza = ceza
                        state!.pokes.append("\(p.name) → \(target.name) (\(discardedTile) atıp açtırdı)")
                        logText = "\(p.name) yandan aldı (\(discardedTile)), \(target.name)'e \(ceza) ceza. "
                        
                        keysToSpeak.append("YANDAN_ALIP_\(discardedTile)")
                    }
                }
                
                logText += "\(p.name) çift açtı (\(count) çift)."
                
                if count >= 7 {
                    keysToSpeak.append("CIFT_7_USTU")
                } else if !fromDiscard {
                    keysToSpeak.append("CIFT_ACTI")
                }
                
                if !keysToSpeak.isEmpty {
                    voice?.speak(keys: keysToSpeak, context: ctx)
                }

            case .tookOkey:
                let tSeat = targetSeat ?? donorSeat(for: seat)
                guard let tIdx = playerIndex(seat: tSeat) else { return }
                let target = state!.players[tIdx]
                state!.players[idx].inflicted += 100
                state!.players[tIdx].eaten += 100
                addTeamScore(target.team, 100)
                ctx.hedef = target.name
                state!.pokes.append("\(p.name) → \(target.name) (okey)")
                logText = "\(p.name), \(target.name)'in okeyini aldı → \(target.name)'e 100 ceza."
                voice?.speak("OKEY_ALDI", context: ctx)

            case .threwOkey:
                state!.players[idx].eaten += 100
                addTeamScore(team, 100)
                logText = "\(p.name) okey attı → kendine 100 ceza."
                voice?.speak("OKEY_ATTI", context: ctx)

            case .wrongOpen:
                state!.players[idx].eaten += 100
                addTeamScore(team, 100)
                logText = "\(p.name) yanlış açtı → kendine 100 ceza."
                voice?.speak("YANLIS_ACTI", context: ctx)

            default:
                return
            }

            state!.log.append(LogEntry(handNumber: state!.currentHand, text: logText))
            saveState()
        }
    func endHand(finisherSeat: Int?, finishKind: ActionKind?, remaining: [Int: Int]) {
        guard state != nil else { return }
        pushUndo()
        var logParts: [String] = []

        if let fSeat = finisherSeat, let fIdx = playerIndex(seat: fSeat), let kind = finishKind {
            let finisher = state!.players[fIdx]
            let fTeam = finisher.team
            let rule = FinishRule.rule(for: kind)

            addTeamScore(fTeam, rule.finisherBonus)
            logParts.append("\(finisher.name) \(kindLabel(kind)) (\(rule.finisherBonus))")

            if kind == .finishKafa {
                addTeamScore(fTeam.rakip, rule.kafaOpponentFlat)
                for seat in 0..<4 where seat != fSeat {
                    if let pIdx = playerIndex(seat: seat), state!.players[pIdx].team != fTeam {
                        state!.players[pIdx].eaten += rule.kafaOpponentFlat / 2
                    }
                }
                logParts.append("karşı takım +\(rule.kafaOpponentFlat)")
            } else {
                for seat in 0..<4 where seat != fSeat {
                    guard let pIdx = playerIndex(seat: seat) else { continue }
                    let pl = state!.players[pIdx]
                    let base = pl.opened ? (remaining[seat] ?? 0) : 200
                    let isOpponent = pl.team != fTeam
                    let mult = isOpponent ? rule.baseMultiplier : 1
                    let pts = base * mult
                    state!.players[pIdx].leftInHand += pts
                    addTeamScore(pl.team, pts)
                    let tag = pl.opened ? "elinde \(base)" : "açamadı 200"
                    logParts.append("\(pl.name) \(tag)\(mult > 1 ? " x\(mult)" : "")=\(pts)")
                }
            }
        } else {
            logParts.append("Kimse bitmedi")
            for seat in 0..<4 {
                guard let pIdx = playerIndex(seat: seat) else { continue }
                let pl = state!.players[pIdx]
                let base = pl.opened ? (remaining[seat] ?? 0) : 200
                state!.players[pIdx].leftInHand += base
                addTeamScore(pl.team, base)
                logParts.append("\(pl.name) \(pl.opened ? "elinde \(base)" : "açamadı 200")")
            }
        }

        state!.log.append(LogEntry(handNumber: state!.currentHand,
                                   text: logParts.joined(separator: ", ") + "."))

        let dA = state!.teamA - state!.roundBaseA
        let dB = state!.teamB - state!.roundBaseB
        let summary = RoundSummary(hand: state!.currentHand,
                                   teamAPoints: dA, teamBPoints: dB,
                                   teamANames: state!.teamAPlayers.map(\.name),
                                   teamBNames: state!.teamBPlayers.map(\.name),
                                   isLastHand: state!.currentHand >= state!.totalHands)

        let dur = Date().timeIntervalSince(state!.handStart)
        state!.handDurations.append(dur)
        if let fSeat = finisherSeat, let fIdx = playerIndex(seat: fSeat), let kind = finishKind {
            voice?.speak(kind.sesKey, context: VoiceContext(oyuncu: state!.players[fIdx].name,
                                                            el: state!.currentHand))
        }
        voice?.speak("EL_BITTI", context: VoiceContext(el: state!.currentHand, sure: formatDuration(dur)))

        saveState()
        roundSummary = summary
    }

    func advanceAfterSummary() {
        roundSummary = nil
        guard state != nil else { return }
        if state!.currentHand >= state!.totalHands {
            state!.finished = true
            saveState()
            endGame()
        } else {
            state!.currentHand += 1
            state!.handStart = Date()
            state!.roundBaseA = state!.teamA
            state!.roundBaseB = state!.teamB
            for i in state!.players.indices {
                state!.players[i].opened = false
                state!.players[i].openedPairs = false
                state!.players[i].openValue = 0
                state!.players[i].openInfo = ""
            }
            voice?.speak("EL_BASLADI", context: VoiceContext(el: state!.currentHand))
            saveState()
        }
    }

    private func kindLabel(_ kind: ActionKind) -> String {
        switch kind {
        case .finishKafa: return "kafa attı"
        case .finishNormal: return "normal bitti"
        case .finishOkey: return "okeyle bitti"
        case .finishDoubleOkey: return "çifte okey attı"
        default: return ""
        }
    }

    func endGame() {
        guard let s = state else { return }
        let winner: Team = s.teamA <= s.teamB ? .A : .B
        let durStr = formatDuration(s.totalDuration)
        voice?.speak("OYUN_BITTI", context: VoiceContext(takim: winner.displayName, sure: durStr))
        saveState()
    }

    func commitStats() {
        guard let s = state, !statsCommitted else { return }
        let winner: Team = s.teamA <= s.teamB ? .A : .B
        let margin = s.fark

        for p in s.players {
            updateProfile(name: p.name) { prof in
                prof.gamesPlayed += 1
                prof.totalInflicted += p.inflicted
                prof.totalEaten += p.eaten
                prof.totalLeftInHand += p.leftInHand
                if p.team == winner {
                    prof.gamesWon += 1
                    prof.biggestWinMargin = max(prof.biggestWinMargin, margin)
                }
            }
        }
        saveProfiles()
        statsCommitted = true
    }

    func clearGame() {
        state = nil
        undoStack.removeAll()
        revealUnlocked = false
        statsCommitted = false
        UserDefaults.standard.removeObject(forKey: stateKey)
    }

    private func updateProfile(name: String, _ change: (inout PlayerProfile) -> Void) {
        if let i = profiles.firstIndex(where: { $0.name.lowercased() == name.lowercased() }) {
            change(&profiles[i])
        } else {
            var prof = PlayerProfile(name: name)
            change(&prof)
            profiles.append(prof)
        }
    }

    func saveState() {
        guard let s = state else { return }
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: stateKey)
        }
    }

    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: stateKey),
              let s = try? JSONDecoder().decode(GameState.self, from: data) else { return }
        state = s
    }

    func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: profilesKey)
        }
    }

    private func loadProfiles() {
        guard let data = UserDefaults.standard.data(forKey: profilesKey),
              let p = try? JSONDecoder().decode([PlayerProfile].self, from: data) else { return }
        profiles = p
    }
}
