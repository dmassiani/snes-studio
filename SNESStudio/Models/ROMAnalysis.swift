import Foundation

struct ROMHeader: Equatable {
    let title: String
    let mapping: ROMMapping
    let speed: ROMSpeed
    let chipType: UInt8
    let romSizeKB: Int
    let ramSizeKB: Int
    let country: UInt8
    let checksum: UInt16
    let checksumComplement: UInt16
    let resetVector: UInt16
    let nmiVector: UInt16
    let irqVector: UInt16

    var checksumValid: Bool {
        checksum ^ checksumComplement == 0xFFFF
    }

    var countryName: String {
        switch country {
        case 0x00: return "Japan"
        case 0x01: return "USA"
        case 0x02: return "Europe"
        case 0x03: return "Sweden"
        case 0x04: return "Finland"
        case 0x05: return "Denmark"
        case 0x06: return "France"
        case 0x07: return "Netherlands"
        case 0x08: return "Spain"
        case 0x09: return "Germany"
        case 0x0A: return "Italy"
        case 0x0B: return "China"
        case 0x0D: return "Korea"
        default:   return "Unknown (\(String(format: "$%02X", country)))"
        }
    }
}

struct ROMTileBlock: Identifiable, Equatable {
    let id = UUID()
    let offset: Int
    let depth: TileDepth
    var tiles: [SNESTile]
}

struct ROMPaletteBlock: Identifiable, Equatable {
    let id = UUID()
    let offset: Int
    var palette: SNESPalette
}

struct ROMAnalysisResult: Equatable {
    let fileName: String
    let fileSize: Int
    let hasSMCHeader: Bool
    let header: ROMHeader
    var tileBlocks: [ROMTileBlock]
    var paletteBlocks: [ROMPaletteBlock]
}
