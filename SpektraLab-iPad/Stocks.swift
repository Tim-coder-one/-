import Foundation

// Film/paper list, copied from the Mac app's generated catalogue
// (Spektrafilm/Resources/StockCatalog.json, itself generated from
// engine/resources/profiles). The picker must never list a stock the
// engine does not have, so this list is kept in sync with that file
// by scripts/setup.sh — if a profile is added upstream, regenerate it.
// Film names are manufacturers' trademarks, used only to identify the
// measured material, as on spektralab.app.

struct Stock: Identifiable, Hashable {
    let id: String
    let name: String
    let isFilm: Bool
    let isPositive: Bool
    let isMonochrome: Bool
    let targetPrint: String?
}

enum Stocks {
    static let films: [Stock] = [
        Stock(id: "kodak_portra_400", name: "Kodak Portra 400", isFilm: true, isPositive: false, isMonochrome: false, targetPrint: "kodak_portra_endura"),
        Stock(id: "kodak_portra_160", name: "Kodak Portra 160", isFilm: true, isPositive: false, isMonochrome: false, targetPrint: "kodak_portra_endura"),
        Stock(id: "kodak_portra_800", name: "Kodak Portra 800", isFilm: true, isPositive: false, isMonochrome: false, targetPrint: "kodak_portra_endura"),
        Stock(id: "kodak_portra_800_push1", name: "Kodak Portra 800 (Push 1)", isFilm: true, isPositive: false, isMonochrome: false, targetPrint: "kodak_portra_endura"),
        Stock(id: "kodak_portra_800_push2", name: "Kodak Portra 800 (Push 2)", isFilm: true, isPositive: false, isMonochrome: false, targetPrint: "kodak_portra_endura"),
        Stock(id: "kodak_ektar_100", name: "Kodak Ektar 100", isFilm: true, isPositive: false, isMonochrome: false, targetPrint: "kodak_portra_endura"),
        Stock(id: "kodak_gold_200", name: "Kodak Gold 200", isFilm: true, isPositive: false, isMonochrome: false, targetPrint: "kodak_portra_endura"),
        Stock(id: "kodak_ultramax_400", name: "Kodak Ultramax 400", isFilm: true, isPositive: false, isMonochrome: false, targetPrint: "kodak_portra_endura"),
        Stock(id: "fujifilm_c200", name: "Fujifilm C200", isFilm: true, isPositive: false, isMonochrome: false, targetPrint: "fujifilm_crystal_archive_typeii"),
        Stock(id: "fujifilm_pro_400h", name: "Fujifilm Pro 400H", isFilm: true, isPositive: false, isMonochrome: false, targetPrint: "fujifilm_crystal_archive_typeii"),
        Stock(id: "fujifilm_xtra_400", name: "Fujifilm X-Tra 400", isFilm: true, isPositive: false, isMonochrome: false, targetPrint: "fujifilm_crystal_archive_typeii"),
        Stock(id: "kodak_ektachrome_100", name: "Kodak Ektachrome 100", isFilm: true, isPositive: true, isMonochrome: false, targetPrint: nil),
        Stock(id: "kodak_kodachrome_64", name: "Kodak Kodachrome 64", isFilm: true, isPositive: true, isMonochrome: false, targetPrint: nil),
        Stock(id: "fujifilm_provia_100f", name: "Fujifilm Provia 100F", isFilm: true, isPositive: true, isMonochrome: false, targetPrint: nil),
        Stock(id: "fujifilm_velvia_100", name: "Fujifilm Velvia 100", isFilm: true, isPositive: true, isMonochrome: false, targetPrint: nil),
        Stock(id: "kodak_vision3_50d", name: "Kodak Vision3 50D", isFilm: true, isPositive: false, isMonochrome: false, targetPrint: "kodak_2383"),
        Stock(id: "kodak_vision3_200t", name: "Kodak Vision3 200T", isFilm: true, isPositive: false, isMonochrome: false, targetPrint: "kodak_2383"),
        Stock(id: "kodak_vision3_250d", name: "Kodak Vision3 250D", isFilm: true, isPositive: false, isMonochrome: false, targetPrint: "kodak_2383"),
        Stock(id: "kodak_vision3_500t", name: "Kodak Vision3 500T", isFilm: true, isPositive: false, isMonochrome: false, targetPrint: "kodak_2383"),
        Stock(id: "kodak_verita_200d", name: "Kodak Verita 200D", isFilm: true, isPositive: false, isMonochrome: false, targetPrint: "kodak_2383"),
        Stock(id: "cinestill_800t", name: "CineStill 800T", isFilm: true, isPositive: false, isMonochrome: false, targetPrint: "kodak_2383"),
        Stock(id: "kodak_tri_x_400", name: "Kodak Tri-X 400", isFilm: true, isPositive: false, isMonochrome: true, targetPrint: "ilford_multigrade_iv_rc"),
        Stock(id: "kodak_tmax_100", name: "Kodak T-Max 100", isFilm: true, isPositive: false, isMonochrome: true, targetPrint: "ilford_multigrade_iv_rc"),
        Stock(id: "fujifilm_neopan_acros_100_ii", name: "Fujifilm Neopan 100 Acros II", isFilm: true, isPositive: false, isMonochrome: true, targetPrint: "ilford_multigrade_iv_rc"),
        Stock(id: "ilford_hp5_plus_400", name: "Ilford HP5 Plus 400", isFilm: true, isPositive: false, isMonochrome: true, targetPrint: "ilford_multigrade_iv_rc"),
    ]

    static let papers: [Stock] = [
        Stock(id: "kodak_portra_endura", name: "Kodak Portra Endura", isFilm: false, isPositive: false, isMonochrome: false, targetPrint: nil),
        Stock(id: "kodak_supra_endura", name: "Kodak Supra Endura", isFilm: false, isPositive: false, isMonochrome: false, targetPrint: nil),
        Stock(id: "kodak_endura_premier", name: "Kodak Endura Premier", isFilm: false, isPositive: false, isMonochrome: false, targetPrint: nil),
        Stock(id: "kodak_ultra_endura", name: "Kodak Ultra Endura", isFilm: false, isPositive: false, isMonochrome: false, targetPrint: nil),
        Stock(id: "kodak_ektacolor_edge", name: "Kodak Ektacolor Edge", isFilm: false, isPositive: false, isMonochrome: false, targetPrint: nil),
        Stock(id: "fujifilm_crystal_archive_typeii", name: "Fujifilm Crystal Archive Type II", isFilm: false, isPositive: false, isMonochrome: false, targetPrint: nil),
        Stock(id: "kodak_2383", name: "Kodak Vision 2383", isFilm: false, isPositive: false, isMonochrome: false, targetPrint: nil),
        Stock(id: "kodak_2393", name: "Kodak Vision Premier 2393", isFilm: false, isPositive: false, isMonochrome: false, targetPrint: nil),
        Stock(id: "ilford_multigrade_iv_rc", name: "Ilford Multigrade IV RC", isFilm: false, isPositive: false, isMonochrome: true, targetPrint: nil),
    ]

    static func film(_ id: String) -> Stock? { films.first { $0.id == id } }
    static func paper(_ id: String) -> Stock? { papers.first { $0.id == id } }
}
