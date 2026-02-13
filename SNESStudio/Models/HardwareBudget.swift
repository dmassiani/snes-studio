import SwiftUI

struct BudgetMeter: Identifiable {
    let id: String
    let label: String
    let used: Double
    let total: Double
    let unit: String
    var detail: String? = nil

    var percentage: Double {
        guard total > 0 else { return 0 }
        return (used / total) * 100
    }

    var barColor: Color {
        switch percentage {
        case 0..<60:  return SNESTheme.success
        case 60..<85: return SNESTheme.warning
        default:      return SNESTheme.danger
        }
    }

    var formattedValue: String {
        if unit == "KB" {
            return "\(Int(used))\(unit) / \(Int(total))\(unit)"
        }
        return "\(Int(used)) / \(Int(total))"
    }
}

extension BudgetMeter {
    static func metersFromCartridge(_ config: CartridgeConfig) -> [BudgetMeter] {
        metersFromCartridge(config, assets: nil)
    }

    static func metersFromCartridge(_ config: CartridgeConfig, assets: AssetStore?) -> [BudgetMeter] {
        let store = assets

        // VRAM: tile data + tilemap data (in KB)
        let vramUsedKB: Double = {
            guard let s = store else { return 0 }
            var bytes = 0
            // Tile data: each tile = depth-dependent size
            for tile in s.tiles {
                bytes += VRAMBudgetCalculator.tileSizeBytes(depth: tile.depth)
            }
            // Tilemap data: each entry = 2 bytes
            for tm in s.tilemaps {
                bytes += tm.width * tm.height * 2
            }
            return Double(bytes) / 1024.0
        }()

        // CGRAM: count of non-empty palettes (palettes with at least one non-black color beyond index 0)
        let cgramUsed: Double = {
            guard let s = store else { return 0 }
            var count = 0
            for pal in s.palettes {
                let hasContent = pal.colors.dropFirst().contains { $0 != .black }
                if hasContent { count += 1 }
            }
            return Double(count)
        }()

        // Sprites: OAM entries count
        let spritesUsed: Double = {
            guard let s = store else { return 0 }
            return Double(s.spriteEntries.count)
        }()

        var meters: [BudgetMeter] = [
            BudgetMeter(id: "vram",    label: "VRAM",    used: vramUsedKB, total: 64,  unit: "KB"),
            BudgetMeter(id: "rom",     label: "ROM",     used: 0, total: Double(config.romSizeKB), unit: "KB"),
            BudgetMeter(id: "cgram",   label: "CGRAM",   used: cgramUsed, total: 16,  unit: "palettes"),
            BudgetMeter(id: "sprites", label: "Sprites",  used: spritesUsed, total: 128, unit: "", detail: "Max scanline: 32"),
            BudgetMeter(id: "wram",    label: "WRAM",    used: 0, total: 128, unit: "KB"),
            BudgetMeter(id: "cpu",     label: "CPU est.", used: 0, total: 100, unit: "%"),
        ]
        if config.sramSizeKB > 0 {
            meters.insert(
                BudgetMeter(id: "sram", label: "SRAM", used: 0, total: Double(config.sramSizeKB), unit: "KB"),
                at: 2
            )
        }
        return meters
    }
}
