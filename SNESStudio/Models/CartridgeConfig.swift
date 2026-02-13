import Foundation

// MARK: - ROM Mapping

enum ROMMapping: String, Codable, CaseIterable, Identifiable {
    case loROM    = "LoROM"
    case hiROM    = "HiROM"
    case exHiROM  = "ExHiROM"
    case sa1      = "SA-1"

    var id: String { rawValue }

    var headerByte: UInt8 {
        switch self {
        case .loROM:   return 0x20
        case .hiROM:   return 0x21
        case .exHiROM: return 0x25
        case .sa1:     return 0x23
        }
    }

    var romBankSize: Int {
        switch self {
        case .loROM:   return 32 * 1024
        case .hiROM:   return 64 * 1024
        case .exHiROM: return 64 * 1024
        case .sa1:     return 64 * 1024
        }
    }

    var romStartAddress: String {
        switch self {
        case .loROM:   return "$008000"
        case .hiROM:   return "$C00000"
        case .exHiROM: return "$C00000"
        case .sa1:     return "$C00000"
        }
    }
}

// MARK: - ROM Speed

enum ROMSpeed: String, Codable, CaseIterable, Identifiable {
    case slow = "SlowROM"
    case fast = "FastROM"

    var id: String { rawValue }

    var headerFlag: UInt8 {
        switch self {
        case .slow: return 0x00
        case .fast: return 0x10
        }
    }
}

// MARK: - Enhancement Chip

enum EnhancementChip: String, Codable, CaseIterable, Identifiable {
    case none     = "None"
    case sa1      = "SA-1"
    case superFX  = "Super FX"
    case dsp1     = "DSP-1"
    case cx4      = "Cx4"
    case sdd1     = "S-DD1"
    case spc7110  = "SPC7110"

    var id: String { rawValue }

    // Backward compatibility: accept old French raw value "Aucun" for .none
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if value == "Aucun" {
            self = .none
        } else if let chip = EnhancementChip(rawValue: value) {
            self = chip
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown EnhancementChip: \(value)"))
        }
    }

    var headerByte: UInt8 {
        switch self {
        case .none:    return 0x00
        case .sa1:     return 0x34
        case .superFX: return 0x15
        case .dsp1:    return 0x05
        case .cx4:     return 0x0F
        case .sdd1:    return 0x43
        case .spc7110: return 0x0A
        }
    }

    var description: String {
        switch self {
        case .none:    return "No co-processor"
        case .sa1:     return "65C816 @ 10.74 MHz — parallel CPU"
        case .superFX: return "GPU RISC 10.7 MHz — 3D, scaling"
        case .dsp1:    return "Math hardware — trigonometry, projections"
        case .cx4:     return "Math 3D @ 20 MHz — polygons"
        case .sdd1:    return "Real-time decompression hardware"
        case .spc7110: return "Decompression + advanced bankswitching"
        }
    }
}

// MARK: - Cartridge Profile

struct CartridgeProfile: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let romSizeKB: Int
    let mapping: ROMMapping
    let sramSizeKB: Int
    let chip: EnhancementChip
    let speed: ROMSpeed
    let difficulty: Int // 1-5

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: CartridgeProfile, rhs: CartridgeProfile) -> Bool { lhs.id == rhs.id }
}

extension CartridgeProfile {
    static let presets: [CartridgeProfile] = [
        CartridgeProfile(
            id: "simple", name: "Simple", description: "256 KB LoROM — Demo, first game",
            romSizeKB: 256, mapping: .loROM, sramSizeKB: 0, chip: .none, speed: .slow, difficulty: 1
        ),
        CartridgeProfile(
            id: "standard", name: "Standard", description: "512 KB LoROM + 8 KB SRAM",
            romSizeKB: 512, mapping: .loROM, sramSizeKB: 8, chip: .none, speed: .slow, difficulty: 2
        ),
        CartridgeProfile(
            id: "extended", name: "Extended", description: "1 MB LoROM — Zelda-like, Metroid-like",
            romSizeKB: 1024, mapping: .loROM, sramSizeKB: 8, chip: .none, speed: .fast, difficulty: 2
        ),
        CartridgeProfile(
            id: "large", name: "Large", description: "2 MB HiROM — RPG, rich adventure",
            romSizeKB: 2048, mapping: .hiROM, sramSizeKB: 32, chip: .none, speed: .fast, difficulty: 3
        ),
        CartridgeProfile(
            id: "very_large", name: "Very Large", description: "4 MB ExHiROM — ambitious RPG",
            romSizeKB: 4096, mapping: .exHiROM, sramSizeKB: 32, chip: .none, speed: .fast, difficulty: 3
        ),
        CartridgeProfile(
            id: "sa1_boost", name: "SA-1 Boost", description: "4 MB SA-1 — complex RPG, action",
            romSizeKB: 4096, mapping: .sa1, sramSizeKB: 32, chip: .sa1, speed: .fast, difficulty: 4
        ),
        CartridgeProfile(
            id: "super_fx", name: "Super FX", description: "1-2 MB Super FX — 3D, special effects",
            romSizeKB: 1024, mapping: .loROM, sramSizeKB: 0, chip: .superFX, speed: .slow, difficulty: 5
        ),
        CartridgeProfile(
            id: "dsp1_math", name: "DSP-1 Math", description: "1-2 MB DSP-1 — Racing, simulation",
            romSizeKB: 1024, mapping: .loROM, sramSizeKB: 8, chip: .dsp1, speed: .slow, difficulty: 4
        ),
        CartridgeProfile(
            id: "custom", name: "Custom", description: "Free configuration, all parameters",
            romSizeKB: 512, mapping: .loROM, sramSizeKB: 0, chip: .none, speed: .slow, difficulty: 0
        ),
    ]

    static func preset(for id: String) -> CartridgeProfile? {
        presets.first { $0.id == id }
    }
}

// MARK: - Cartridge Config (Codable, editable)

struct CartridgeConfig: Codable, Equatable {
    var selectedProfileID: String
    var romSizeKB: Int
    var mapping: ROMMapping
    var speed: ROMSpeed
    var sramSizeKB: Int
    var chip: EnhancementChip

    // MARK: - Header bytes

    var romSizeHeaderByte: UInt8 {
        // ROM size header: log2(size_in_KB) - 10 → 0x08 = 256KB, 0x09 = 512KB, etc.
        let kb = max(romSizeKB, 1)
        var power: UInt8 = 0
        var val = kb
        while val > 1 { val >>= 1; power += 1 }
        return power > 10 ? power - 10 : 0
    }

    // Not using computed property here — just recalculate header byte
    var sramSizeHeaderByte: UInt8 {
        guard sramSizeKB > 0 else { return 0 }
        var power: UInt8 = 0
        var val = sramSizeKB
        while val > 1 { val >>= 1; power += 1 }
        return power > 10 ? power - 10 : power
    }

    var mappingHeaderByte: UInt8 {
        mapping.headerByte | speed.headerFlag
    }

    var cartridgeTypeByte: UInt8 {
        var base: UInt8 = 0x00 // ROM only
        if sramSizeKB > 0 { base = 0x02 } // ROM + SRAM
        if chip != .none { base |= chip.headerByte }
        return base
    }

    // MARK: - Available ROM sizes per mapping

    static let romSizesLoROM  = [256, 512, 1024, 2048]
    static let romSizesHiROM  = [512, 1024, 2048, 3072, 4096]
    static let romSizesExHiROM = [4096, 6144, 8192]
    static let romSizesSA1    = [1024, 2048, 4096, 8192]

    static let sramSizes = [0, 2, 8, 32, 64, 128, 256]

    var availableROMSizes: [Int] {
        switch mapping {
        case .loROM:   return Self.romSizesLoROM
        case .hiROM:   return Self.romSizesHiROM
        case .exHiROM: return Self.romSizesExHiROM
        case .sa1:     return Self.romSizesSA1
        }
    }

    var linkerConfigName: String {
        switch mapping {
        case .loROM:   return "snes.cfg"
        case .hiROM:   return "snes_hirom.cfg"
        case .exHiROM: return "snes_hirom.cfg"
        case .sa1:     return "snes_sa1.cfg"
        }
    }

    // MARK: - Factory

    static func fromProfile(_ profile: CartridgeProfile) -> CartridgeConfig {
        CartridgeConfig(
            selectedProfileID: profile.id,
            romSizeKB: profile.romSizeKB,
            mapping: profile.mapping,
            speed: profile.speed,
            sramSizeKB: profile.sramSizeKB,
            chip: profile.chip
        )
    }

    static let `default` = fromProfile(CartridgeProfile.presets[0])
}
