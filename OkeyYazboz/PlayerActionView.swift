//
//  PlayerActionView.swift
//  Şaban Abi Okey 101 Yazboz
//

import SwiftUI

struct PlayerActionView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let seat: Int

    enum Mode: Equatable {
        case menu
        case open
        case tookOkey
        case finish(ActionKind)
    }

    @State private var mode: Mode = .menu

    // Açış
    @State private var openIsPairs = false
    @State private var fromDiscard = false
    @State private var discardedTile = 0
    @State private var openDuz = 0
    @State private var openYan = 0
    @State private var openPairsCount = 0
    @State private var openError: String? = nil
    
    // Okey aldı
    @State private var tookTarget = -1
    // Bitiş
    @State private var remaining = [0, 0, 0, 0]
    @State private var confirmFinish = false

    private var me: Player? { store.state?.player(seat: seat) }
    private var playerName: String { me?.name ?? "Oyuncu" }
    private var isOpened: Bool { me?.opened == true }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(playerName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if mode == .menu {
                            Button("Kapat") { dismiss() }
                        } else {
                            Button("Geri") { mode = .menu; openError = nil }
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder private var content: some View {
        switch mode {
        case .menu:          menuView
        case .open:          openView
        case .tookOkey:      tookOkeyView
        case .finish(let k): finishView(k)
        }
    }

    private var menuView: some View {
        Form {
            Section("El") {
                if isOpened {
                    Label("Açtı: \(me?.openInfo ?? "")", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green).font(.callout)
                } else {
                    row("El Açtı", "hand.raised.fill", .green) {
                        openIsPairs = false; fromDiscard = false; discardedTile = 0
                        openDuz = 0; openYan = 0
                        openPairsCount = 0; openError = nil; mode = .open
                    }
                }
            }
            Section("Hata / Okey") {
                row("Okey Attı (−100)", "arrow.up.right.circle", .red) { apply(.threwOkey) }
                row("Yanlış Açtı (−100)", "xmark.octagon", .red) { apply(.wrongOpen) }
                if isOpened {
                    row("Okey Aldı (karşıya +100)", "hand.point.up.left.fill", .teal) {
                        tookTarget = store.donorSeat(for: seat)
                        if opponentSeats().contains(tookTarget) == false {
                            tookTarget = opponentSeats().first ?? -1
                        }
                        mode = .tookOkey
                    }
                }
            }
            Section("Bitiş") {
                if isOpened {
                    row("Bitti", "checkmark.seal.fill", .blue) { startFinish(.finishNormal) }
                } else {
                    row("Kafa Attı", "bolt.fill", .purple) { startFinish(.finishKafa) }
                    Text("Kafa sadece açmadıysa atılır. Bitmek için önce açmalısın.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func row(_ title: String, _ icon: String, _ color: Color,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).foregroundStyle(.primary)
        }
        .listRowBackground(color.opacity(0.12))
    }

    private var openView: some View {
        let info = store.duzInfo(duz: openDuz, yan: openYan)
        let minD = store.minDuzValue(for: seat)
        let minP = store.minPairs(for: seat)
        return Form {
            Section("Açılış Şekli") {
                Picker("", selection: $fromDiscard) {
                    Text("Kendi Açtı").tag(false)
                    Text("Yerden Aldı").tag(true)
                }.pickerStyle(.segmented)
            }

            Section("Düz mü çift mi?") {
                Picker("", selection: $openIsPairs) {
                    Text("Düz").tag(false)
                    Text("Çift").tag(true)
                }.pickerStyle(.segmented)
            }
            
            if fromDiscard {
                Section("Yerden Alınan Taş") {
                    ManualNumberInput(title: "Taşın Sayısı", value: $discardedTile, range: 1...13)
                    let kat = openIsPairs ? 20 : 10
                    Text("Solundaki (önceki) oyuncuya \(discardedTile * kat) ceza yazılır.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if !openIsPairs {
                Section("Düz açış (düz + yan)") {
                    ManualNumberInput(title: "Düz", value: $openDuz, range: 0...200)
                    ManualNumberInput(title: "Yan", value: $openYan, range: 0...90)
                    Text("El değeri: \(info.text)   •   En az: \(valueText(minD))")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Yan / 3 düze eklenir, kalanı yan olarak gözükür.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                Section("Çift açış") {
                    ManualNumberInput(title: "Çift adedi", value: $openPairsCount, range: 0...20)
                    Text("En az: \(minP) çift")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let e = openError {
                Section {
                    Label(e, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red).font(.caption)
                }
            }
            confirmButton("Aç") { validateAndOpen(info: info, minD: minD, minP: minP) }
        }
    }

    private func validateAndOpen(info: (value: Int, text: String), minD: Int, minP: Int) {
        if fromDiscard && discardedTile < 1 {
            openError = "Yerden alınan taşın sayısını girin (1-13)."
            return
        }
        
        if openIsPairs {
            if openPairsCount < minP {
                openError = "En az \(minP) çift açabilirsin."
                return
            }
            store.applyAction(kind: .openPairs, seat: seat, count: openPairsCount, fromDiscard: fromDiscard, discardedTile: discardedTile)
        } else {
            if info.value < minD {
                openError = "En az \(valueText(minD)) açabilirsin."
                return
            }
            store.applyAction(kind: .openStraight, seat: seat, count: openDuz, yan: openYan, fromDiscard: fromDiscard, discardedTile: discardedTile)
        }
        dismiss()
    }

    private func valueText(_ v: Int) -> String {
        let base = v / 3, rem = v % 3
        return rem == 0 ? "\(base)" : "\(base) yan \(rem)"
    }

    private var tookOkeyView: some View {
        let targetName = store.state?.player(seat: tookTarget)?.name ?? "—"
        return Form {
            Section("Kimin okeyini aldı? (eş hariç)") {
                Picker("Hedef", selection: $tookTarget) {
                    ForEach(opponentSeats(), id: \.self) { os in
                        Text(store.state?.player(seat: os)?.name ?? "—").tag(os)
                    }
                }.pickerStyle(.inline)
            }
            Section {
                Text("\(targetName)'e 100 ceza yazılacak.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            confirmButton("Okey Aldı") {
                store.applyAction(kind: .tookOkey, seat: seat, targetSeat: tookTarget)
                dismiss()
            }
        }
    }

    private func opponentSeats() -> [Int] {
        guard let myTeam = me?.team else { return [] }
        return (0..<4).filter { $0 != seat && Team.forSeat($0) != myTeam }
    }

    private func startFinish(_ kind: ActionKind) {
        remaining = [0, 0, 0, 0]
        mode = .finish(kind)
    }

    private func allowedFinishTypes() -> [ActionKind] {
        if me?.openedPairs == true { return [.finishNormal, .finishOkey, .finishDoubleOkey] }
        return [.finishNormal, .finishOkey]
    }

    private func finishView(_ kind: ActionKind) -> some View {
        let isKafa = kind == .finishKafa
        return Form {
            if !isKafa {
                Section("Bitiş tipi") {
                    Picker("Tip", selection: Binding(
                        get: { kind },
                        set: { mode = .finish($0) })) {
                        ForEach(allowedFinishTypes(), id: \.self) { t in
                            Text(typeLabel(t)).tag(t)
                        }
                    }.pickerStyle(.segmented)
                }
            }
            Section {
                Text(finishDescription(kind))
                    .font(.callout).foregroundStyle(.secondary)
            }
            if !isKafa {
                Section("Diğerleri (açanlar elindekini, açmayanlar 200)") {
                    RemainingEntryList(finisherSeat: seat, remaining: $remaining)
                }
            }
            Section {
                Button { confirmFinish = true } label: {
                    Label(playerName + " Bitirdi", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .alert("Cidden bitti mi?", isPresented: $confirmFinish) {
            Button("Evet, bitti", role: .destructive) {
                commitFinish(kind); dismiss()
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("\(playerName) eli bitirdi olarak işlenecek.")
        }
    }

    private func commitFinish(_ kind: ActionKind) {
        var dict: [Int: Int] = [:]
        if kind != .finishKafa {
            for s in (0..<4).filter({ $0 != seat })
            where store.state?.player(seat: s)?.opened == true {
                dict[s] = remaining[s]
            }
        }
        store.endHand(finisherSeat: seat, finishKind: kind, remaining: dict)
    }

    private func typeLabel(_ k: ActionKind) -> String {
        switch k {
        case .finishNormal: return "Normal"
        case .finishOkey: return "Okey"
        case .finishDoubleOkey: return "Çifte Okey"
        case .finishKafa: return "Kafa"
        default: return ""
        }
    }

    private func finishDescription(_ kind: ActionKind) -> String {
        switch kind {
        case .finishKafa: return "Kafa: Biten −200, karşı takım +800. Elde kalan sorulmaz."
        case .finishNormal: return "Normal: Biten takım −100. Açanlar elindekini, açmayanlar 200 yer."
        case .finishOkey: return "Okey: Biten −200, rakip elinde kalan x2."
        case .finishDoubleOkey: return "Çifte Okey: Biten −400, rakip elinde kalan x4."
        default: return ""
        }
    }

    private func apply(_ kind: ActionKind) {
        store.applyAction(kind: kind, seat: seat)
        dismiss()
    }

    private func confirmButton(_ title: String, action: @escaping () -> Void) -> some View {
        Section {
            Button(action: action) {
                Label(title, systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct RemainingEntryList: View {
    @EnvironmentObject var store: GameStore
    let finisherSeat: Int?
    @Binding var remaining: [Int]

    var body: some View {
        ForEach(0..<4, id: \.self) { seat in
            if finisherSeat != seat, let p = store.state?.player(seat: seat) {
                if p.opened {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle().fill(p.team == .A ? Color.orange : Color.blue)
                                .frame(width: 12, height: 12)
                            Text(p.name).bold()
                            Text("(\(p.openInfo))").font(.caption).foregroundStyle(.secondary)
                        }
                        ManualNumberInput(title: "Elinde kalan", value: $remaining[seat], range: 0...300)
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack {
                        Circle().fill(p.team == .A ? Color.orange : Color.blue)
                            .frame(width: 12, height: 12)
                        Text(p.name)
                        Spacer()
                        Text("açamadı → 200").font(.caption.bold()).foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}

struct ManualNumberInput: View {
    let title: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...999

    @State private var show = false
    @State private var temp = ""

    var body: some View {
        Button {
            temp = value == 0 ? "" : "\(value)"
            show = true
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text("\(value)")
                    .font(.title3.bold().monospacedDigit())
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .alert(title, isPresented: $show) {
            TextField("Sayı gir", text: $temp).keyboardType(.numberPad)
            Button("Tamam") {
                let v = Int(temp) ?? 0
                value = min(max(v, range.lowerBound), range.upperBound)
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Sayıyı manuel gir (\(range.lowerBound)–\(range.upperBound))")
        }
    }
}

struct FinishSheetView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    @State private var remaining = [0, 0, 0, 0]
    @State private var confirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Kimse bitmedi. Açanların elinde kalanını gir; açmayanlar otomatik 200 yer.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Section("Elde kalanlar") {
                    RemainingEntryList(finisherSeat: nil, remaining: $remaining)
                }
                Section {
                    Button { confirm = true } label: {
                        Label("Eli Kapat", systemImage: "flag.checkered")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("El Bitti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
            .alert("Cidden el bitti mi?", isPresented: $confirm) {
                Button("Evet, kapat", role: .destructive) { commit(); dismiss() }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Kimse bitirmedi olarak işlenecek.")
            }
        }
    }

    private func commit() {
        var dict: [Int: Int] = [:]
        for seat in 0..<4 where store.state?.player(seat: seat)?.opened == true {
            dict[seat] = remaining[seat]
        }
        store.endHand(finisherSeat: nil, finishKind: nil, remaining: dict)
    }
}

struct YanCalculatorView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    @State private var duz = 0
    @State private var yan = 0

    var body: some View {
        let info = store.duzInfo(duz: duz, yan: yan)
        NavigationStack {
            Form {
                Section("Gir") {
                    ManualNumberInput(title: "Düz", value: $duz, range: 0...300)
                    ManualNumberInput(title: "Yan", value: $yan, range: 0...150)
                }
                Section("Sonuç") {
                    HStack {
                        Text("Elin değeri")
                        Spacer()
                        Text(info.text)
                            .font(.title2.bold())
                            .foregroundStyle(.green)
                    }
                    Text("Yan / 3 düze eklenir, kalanı yan olarak gösterilir.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Yan Hesabı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
