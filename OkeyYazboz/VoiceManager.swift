//
//  VoiceManager.swift
//  Şaban Abi Okey 101 Yazboz
//

import Foundation
import AVFoundation
import Combine

struct VoiceContext {
    var oyuncu: String? = nil
    var hedef: String? = nil
    var tas: Int? = nil
    var ceza: Int? = nil
    var kat: Int? = nil
    var sayi: String? = nil
    var el: Int? = nil
    var takim: String? = nil
    var fark: Int? = nil
    var sure: String? = nil
}

final class VoiceManager: ObservableObject {

    @Published var enabled: Bool = true
    private(set) var lines: [String: [String]] = [:]

    private let synth = AVSpeechSynthesizer()
    private let defaultsKey = "voiceTemplateText"

    init() {
        configureAudio()
        load()
    }

    private func configureAudio() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        #endif
    }

    func load() {
        if let saved = UserDefaults.standard.string(forKey: defaultsKey), !saved.isEmpty {
            let dict = parsed(saved)
            let hasContent = dict.values.contains { !$0.isEmpty }
            if hasContent {
                lines = dict
                return
            }
        }
        
        if let url = Bundle.main.url(forResource: "SesliMetinler", withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            lines = parsed(text)
        } else {
            lines = parsed(defaultFallbackText)
        }
    }

    func saveTemplate(_ text: String) {
        UserDefaults.standard.set(text, forKey: defaultsKey)
        lines = parsed(text)
    }

    func resetTemplateToDefault() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        load()
    }

    var currentTemplateText: String {
        if let saved = UserDefaults.standard.string(forKey: defaultsKey), !saved.isEmpty {
            return saved
        }
        if let url = Bundle.main.url(forResource: "SesliMetinler", withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        return defaultFallbackText
    }

    func parsed(_ text: String) -> [String: [String]] {
        var result: [String: [String]] = [:]
        var currentKey: String? = nil

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("#") { continue }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                currentKey = String(line.dropFirst().dropLast())
                if result[currentKey!] == nil { result[currentKey!] = [] }
                continue
            }

            guard let key = currentKey else { continue }
            let cleaned = stripBullet(line)
            if !cleaned.isEmpty {
                result[key, default: []].append(cleaned)
            }
        }
        return result
    }

    private func stripBullet(_ s: String) -> String {
        var str = s
        if let range = str.range(of: #"^\s*\d+\s*[\)\.\-]\s*"#, options: .regularExpression) {
            str.removeSubrange(range)
        } else if let range = str.range(of: #"^\s*[\-\•\*]\s*"#, options: .regularExpression) {
            str.removeSubrange(range)
        }
        return str.trimmingCharacters(in: .whitespaces)
    }

    // Birden fazla senaryoyu aynı anda birleştirip okuyan sistem
    func speak(keys: [String], context: VoiceContext = VoiceContext()) {
        guard enabled else { return }
        var combinedText = ""
        
        for key in keys {
            var variants = lines[key]
            
            // Eğer YANDAN_ALIP_x bulunamazsa standart YANDAN_ALIP_ACTI'ya düşsün
            if (variants == nil || variants!.isEmpty) && key.hasPrefix("YANDAN_ALIP_") {
                variants = lines["YANDAN_ALIP_ACTI"]
            }
            
            guard let finalVariants = variants, !finalVariants.isEmpty else { continue }
            let chosen = finalVariants.randomElement()!
            let filled = fill(chosen, with: context)
            
            if !filled.isEmpty {
                combinedText += (combinedText.isEmpty ? "" : " ") + filled
            }
        }
        
        guard !combinedText.isEmpty else { return }
        utter(combinedText)
    }

    // Tekli okuma (Geriye dönük uyumluluk için)
    func speak(_ key: String, context: VoiceContext = VoiceContext()) {
        speak(keys: [key], context: context)
    }

    func speakRaw(_ text: String) {
        guard enabled, !text.isEmpty else { return }
        utter(text)
    }

    private func utter(_ text: String) {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let u = AVSpeechUtterance(string: text)
        u.voice = turkishVoice()
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        u.pitchMultiplier = 1.0
        synth.speak(u)
    }

    private func turkishVoice() -> AVSpeechSynthesisVoice? {
        if let v = AVSpeechSynthesisVoice(language: "tr-TR") { return v }
        return AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix("tr") }
    }

    private func fill(_ template: String, with c: VoiceContext) -> String {
        var s = template
        func rep(_ token: String, _ value: String?) {
            if let v = value { s = s.replacingOccurrences(of: token, with: v) }
        }
        rep("{oyuncu}", c.oyuncu)
        rep("{hedef}", c.hedef)
        rep("{tas}", c.tas.map(String.init))
        rep("{ceza}", c.ceza.map(String.init))
        rep("{kat}", c.kat.map(String.init))
        rep("{sayi}", c.sayi)
        rep("{el}", c.el.map(String.init))
        rep("{takim}", c.takim)
        rep("{fark}", c.fark.map(String.init))
        rep("{sure}", c.sure)
        return s.trimmingCharacters(in: .whitespaces)
    }
    
    private let defaultFallbackText = """
    [OYUN_BASLADI]
    Hadi bakalım sazanlar, taşlar açıldı. Kimin cebi boşalacak göreceğiz.
    [EL_BASLADI]
    {el}. tur. Ahmak gibi oynamayın da biraz oyun görelim.
    [EL_BITTI]
    El bitti, {sure} sürdü. Kaz kafalılar yine zorlandı.
    [DUZ_ACTI]
    {oyuncu} {sayi} ile düz açtı. Meczup bile bazen doğruyu bulur işte.
    [CIFT_ACTI]
    {oyuncu} çift açtı, {sayi} çift. Sazan gibi atlamadan önce iyi beklemiş çakal.
    
    [YANDAN_ALIP_1]
    1 almaya utanmadın mı {oyuncu}? Fakir fukara gibi 1'e muhtaç kalmış şebek!
    [YANDAN_ALIP_2]
    2'yi gördü dayanamadı şebek {oyuncu}. {hedef} sağ olsun seni doyuruyor!
    [YANDAN_ALIP_3]
    Al sana 3'ün biri {hedef}! {oyuncu} 3'ü aldı sana fena monte etti.
    [YANDAN_ALIP_4]
    4 ayak üstüne düştün keriz {oyuncu}. {hedef} sayesinde eli açtın sığır!
    [YANDAN_ALIP_5]
    5 kardeş gibi yapıştırdı suratına {hedef}! {oyuncu} 5'i aldı {ceza} cezayı sana kitledi.
    [YANDAN_ALIP_6]
    {hedef} 6 attı, {oyuncu} altı okka yaptı sana! {ceza} cezayı ye de aklın başına gelsin.
    [YANDAN_ALIP_7]
    7 numara şans getirmez sana ahmak {hedef}! {oyuncu} 7'yi aldı seni batırdı.
    [YANDAN_ALIP_8]
    8 numarayı attı sığır {hedef}. {oyuncu} o 8'i aldı kafana çaktı kaz kafalı!
    [YANDAN_ALIP_9]
    9 numarayı verdin, 9 doğurdun {hedef}! {oyuncu} aldı sana acımadı.
    [YANDAN_ALIP_10]
    10 numara 5 yıldız soktu {oyuncu} sana {hedef}! Hayvan gibi {tas} atılır mı lan?
    [YANDAN_ALIP_11]
    11 numara beton gibi oturdu mu {hedef}? {oyuncu} koca 11'i yuttu seni de batırdı.
    [YANDAN_ALIP_12]
    12 numarayı attın ya {hedef}, harbi körsün! {oyuncu} 12'yi aldı, boğazına dizdi.
    [YANDAN_ALIP_13]
    Ühhh eşşeğe bak, koca 13 alınır mı lan! {oyuncu} böyle sokar ağzına işte {hedef}!
    [YANDAN_ALIP_ACTI]
    {hedef} ahmak gibi {tas} attı, {oyuncu} kapıp soktu. {ceza} ceza {hedef}'in hanesine!
    
    [DUZ_50_USTU]
    Oha! {oyuncu} {sayi} ile düz açtı, elli üstü! Karşıdaki kuzular yüz cezayı yedi.
    [CIFT_7_USTU]
    {oyuncu} {sayi} çift açtı, yedi üstü! Karşıdaki şebekler yüz ceza ile battı.

    [OKEY_ALDI]
    {oyuncu}, {hedef} denilen ahmakın attığı okeyi kaptı! {hedef} 100 ceza yedi.
    [OKEY_ATTI]
    {oyuncu} okeyi attı gitti! Ahmak mısın oğlum sen? Kendine yüz ceza.
    [YANLIS_ACTI]
    {oyuncu} yanlış açtı! Saymayı da bilmiyor sığır. Yüz ceza!
    [BITIS_KAFA]
    {oyuncu} KAFA ATTI! Karşıdaki kuzular sekiz yüz cezayı yedi, meleyin bakayım!
    [BITIS_NORMAL]
    {oyuncu} normal bitti. Zar zor kapattı eli kaz kafalı.
    [BITIS_OKEY]
    {oyuncu} okeyle bitti! Karşıdaki şebekler iki katı ceza yedi!
    [BITIS_CIFTE_OKEY]
    {oyuncu} ÇİFTE OKEY attı! Karşı taraf dört kat yedi, eşek gibi anırın şimdi!
    [GERI_ALINDI]
    Geri alındı. Elin mi titredi kör herif?
    [OYUN_BITTI]
    Oyun bitti! Kazanan {takim}. Süre {sure}. Kaybeden sığırlar hesabı ödesin.
    """
}
