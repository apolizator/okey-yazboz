//
//  Models.swift
//  Şaban Abi Okey 101 Yazboz
//
//  Tüm veri modelleri ve oyun sabitleri.
//

import Foundation

// MARK: - Takım

enum Team: String, Codable, CaseIterable {
    case A
    case B

    var displayName: String { "\(rawValue) Takımı" }

    /// 0=alt, 1=sağ, 2=üst, 3=sol -> karşılıklı oturanlar aynı takım.
    static func forSeat(_ seat: Int) -> Team {
        seat % 2 == 0 ? .A : .B
    }

    var rakip: Team { self == .A ? .B : .A }
}

// MARK: - Oyuncu (oyun içi)

struct Player: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    /// 0=alt, 1=sağ, 2=üst, 3=sol
    var seat: Int

    // Oyun boyunca biriken 3 ayrı liste için sayaçlar:
    var inflicted: Int = 0   // Karşıya yazdırdığı (soktuğu) ceza
    var eaten: Int = 0       // Kendi yediği ceza (hatalar)
    var leftInHand: Int = 0  // Elinde kalan toplam

    // Bu tura özel (her el başında sıfırlanır):
    var opened: Bool = false     // Bu el açtı mı?
    var openedPairs: Bool = false // Çift mi açtı? (false = düz)
    var openValue: Int = 0       // Karşılaştırma değeri (düz: düz*3+yan, çift: çift adedi)
    var openInfo: String = ""    // "42 yan 2", "6 çift" gibi gösterim

    var team: Team { Team.forSeat(seat) }
}

// MARK: - Aksiyon tipleri

enum ActionKind: String, Codable {
    // Açılış
    case openStraight      // Düz açtı (düz + yan)
    case openPairs         // Çift açtı
    // Açana özel: yerdeki okeyi aldı -> okeyi atan kişiye 100
    case tookOkey
    // Kendi hatası (kendine 100)
    case threwOkey         // Okey attı (kendine 100)
    case wrongOpen         // Yanlış açtı (kendine 100)
    // Bitiş
    case finishKafa
    case finishNormal
    case finishOkey
    case finishDoubleOkey

    var sesKey: String {
        switch self {
        case .openStraight:   return "DUZ_ACTI"
        case .openPairs:      return "CIFT_ACTI"
        case .tookOkey:       return "OKEY_ALDI"
        case .threwOkey:      return "OKEY_ATTI"
        case .wrongOpen:      return "YANLIS_ACTI"
        case .finishKafa:     return "BITIS_KAFA"
        case .finishNormal:   return "BITIS_NORMAL"
        case .finishOkey:     return "BITIS_OKEY"
        case .finishDoubleOkey: return "BITIS_CIFTE_OKEY"
        }
    }

    var isFinish: Bool {
        switch self {
        case .finishKafa, .finishNormal, .finishOkey, .finishDoubleOkey: return true
        default: return false
        }
    }
}

// MARK: - Bitiş kuralları (sabitler)

struct FinishRule {
    /// Bitirenin kendi takımına eklenen (negatif) bonus.
    let finisherBonus: Int
    /// Rakibin elinde kalanına uygulanan temel çarpan.
    let baseMultiplier: Int
    /// Kafa için rakip takıma sabit eklenen puan (yoksa 0).
    let kafaOpponentFlat: Int

    static func rule(for kind: ActionKind) -> FinishRule {
        switch kind {
        case .finishKafa:        return FinishRule(finisherBonus: -200, baseMultiplier: 0, kafaOpponentFlat: 800)
        case .finishNormal:      return FinishRule(finisherBonus: -100, baseMultiplier: 1, kafaOpponentFlat: 0)
        case .finishOkey:        return FinishRule(finisherBonus: -200, baseMultiplier: 2, kafaOpponentFlat: 0)
        case .finishDoubleOkey:  return FinishRule(finisherBonus: -400, baseMultiplier: 4, kafaOpponentFlat: 0)
        default:                 return FinishRule(finisherBonus: 0, baseMultiplier: 1, kafaOpponentFlat: 0)
        }
    }
}

// MARK: - Log kaydı (şifreyle "adım adım" görünür)

struct LogEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var handNumber: Int
    var text: String
    var createdAt: Date = Date()
}

// MARK: - Oyun durumu (snapshot olarak undo'da saklanır)

struct GameState: Codable {
    var players: [Player]
    var totalHands: Int
    var currentHand: Int = 1
    var teamA: Int = 0          // Birikmiş ceza puanı (az olan iyi)
    var teamB: Int = 0
    var roundBaseA: Int = 0     // Bu el başındaki A skoru (tur özeti için)
    var roundBaseB: Int = 0     // Bu el başındaki B skoru
    var log: [LogEntry] = []
    // Oyun boyu ufak rekorlar
    var pokes: [String] = []        // "Apo → Samet (okey)" gibi
    var bestDuzValue: Int = 0
    var bestDuzName: String = ""
    var bestDuzInfo: String = ""
    var bestCiftValue: Int = 0
    var bestCiftName: String = ""
    var handStart: Date = Date()
    var handDurations: [TimeInterval] = []  // her elin süresi
    var gameStart: Date = Date()
    var finished: Bool = false

    func player(seat: Int) -> Player? { players.first { $0.seat == seat } }

    var teamAPlayers: [Player] { players.filter { $0.team == .A } }
    var teamBPlayers: [Player] { players.filter { $0.team == .B } }

    func score(for team: Team) -> Int { team == .A ? teamA : teamB }

    var fark: Int { abs(teamA - teamB) }

    var totalDuration: TimeInterval {
        handDurations.reduce(0, +) + Date().timeIntervalSince(handStart)
    }
}

// MARK: - Tur sonu özeti (geçici, kaydedilmez)

struct RoundSummary: Identifiable {
    let id = UUID()
    let hand: Int
    let teamAPoints: Int
    let teamBPoints: Int
    let teamANames: [String]
    let teamBNames: [String]
    let isLastHand: Bool
}

// MARK: - Kalıcı oyuncu profili (oyunlar arası istatistik)

struct PlayerProfile: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    /// Bu isme ait şifrenin SHA256 özeti. nil = korumasız (eski kayıt).
    var passwordHash: String? = nil
    /// Oyuncu fotoğrafı (JPEG verisi).
    var photoData: Data? = nil
    var gamesPlayed: Int = 0
    var gamesWon: Int = 0
    var biggestWinMargin: Int = 0   // en yüksek fark rekoru (kazanırken)
    var totalInflicted: Int = 0
    var totalEaten: Int = 0
    var totalLeftInHand: Int = 0

    var winRate: Double {
        gamesPlayed == 0 ? 0 : Double(gamesWon) / Double(gamesPlayed)
    }
}
