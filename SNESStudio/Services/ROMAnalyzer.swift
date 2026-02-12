import Foundation

@Observable
final class ROMAnalyzer {
    var result: ROMAnalysisResult?
    var errorMessage: String?
    var isAnalyzing = false

    // MARK: - Analyze ROM

    func analyzeROM(at url: URL) {
        isAnalyzing = true
        errorMessage = nil
        result = nil

        guard let data = try? Data(contentsOf: url) else {
            errorMessage = "Impossible de lire le fichier"
            isAnalyzing = false
            return
        }

        let fileSize = data.count
        let hasSMCHeader = fileSize % 1024 == 512

        let romData: Data
        if hasSMCHeader {
            romData = data.dropFirst(512)
        } else {
            romData = data
        }

        guard let header = parseHeader(romData) else {
            errorMessage = "Header SNES invalide"
            isAnalyzing = false
            return
        }

        result = ROMAnalysisResult(
            fileName: url.lastPathComponent,
            fileSize: fileSize,
            hasSMCHeader: hasSMCHeader,
            header: header,
            tileBlocks: [],
            paletteBlocks: []
        )

        isAnalyzing = false
    }

    // MARK: - Parse Header

    private func parseHeader(_ data: Data) -> ROMHeader? {
        // Try LoROM ($7FC0) and HiROM ($FFC0)
        let loROMOffset = 0x7FC0
        let hiROMOffset = 0xFFC0

        if let header = tryParseHeader(data, at: hiROMOffset, expectedMapping: .hiROM) {
            return header
        }
        if let header = tryParseHeader(data, at: loROMOffset, expectedMapping: .loROM) {
            return header
        }

        // Fallback: try LoROM regardless of mapping byte
        return tryParseHeader(data, at: loROMOffset, expectedMapping: nil)
    }

    private func tryParseHeader(_ data: Data, at offset: Int, expectedMapping: ROMMapping?) -> ROMHeader? {
        guard data.count > offset + 0x3F else { return nil }

        let bytes = [UInt8](data)

        // Read title (21 bytes at offset)
        let titleBytes = Array(bytes[offset..<offset+21])
        let title = String(bytes: titleBytes, encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .whitespaces) ?? "Unknown"

        // Validate title: should be mostly printable ASCII
        let printableCount = titleBytes.filter { $0 >= 0x20 && $0 <= 0x7E }.count
        guard printableCount >= 10 || expectedMapping == nil else { return nil }

        let mappingByte = bytes[offset + 0x15]
        let chipType = bytes[offset + 0x16]
        let romSizeByte = bytes[offset + 0x17]
        let ramSizeByte = bytes[offset + 0x18]
        let country = bytes[offset + 0x19]

        // Checksum complement and checksum
        let checksumComplement = UInt16(bytes[offset + 0x1C]) | (UInt16(bytes[offset + 0x1D]) << 8)
        let checksum = UInt16(bytes[offset + 0x1E]) | (UInt16(bytes[offset + 0x1F]) << 8)

        // Validate checksum complement
        if expectedMapping != nil && (checksum ^ checksumComplement != 0xFFFF) {
            return nil
        }

        // Determine mapping
        let mappingValue = mappingByte & 0x0F
        let mapping: ROMMapping
        switch mappingValue {
        case 0x00, 0x02: mapping = .loROM
        case 0x01, 0x03: mapping = .hiROM
        case 0x05:       mapping = .exHiROM
        default:         mapping = expectedMapping ?? .loROM
        }

        let speed: ROMSpeed = (mappingByte & 0x10) != 0 ? .fast : .slow

        let romSizeKB = romSizeByte <= 0x0D ? (1 << romSizeByte) : 0
        let ramSizeKB = ramSizeByte > 0 && ramSizeByte <= 0x07 ? (1 << ramSizeByte) : 0

        // Vectors
        let vectorBase = offset + 0x24  // $xxE4 relative
        let nmiVector: UInt16
        let resetVector: UInt16
        let irqVector: UInt16

        if data.count > offset + 0x3F {
            // NMI at $xxEA (offset + 0x2A), RESET at $xxFC (offset + 0x3C), IRQ at $xxEE (offset + 0x2E)
            let nmiOff = offset + 0x2A
            let resetOff = offset + 0x3C
            let irqOff = offset + 0x2E
            nmiVector = UInt16(bytes[nmiOff]) | (UInt16(bytes[nmiOff + 1]) << 8)
            resetVector = UInt16(bytes[resetOff]) | (UInt16(bytes[resetOff + 1]) << 8)
            irqVector = UInt16(bytes[irqOff]) | (UInt16(bytes[irqOff + 1]) << 8)
        } else {
            nmiVector = 0
            resetVector = 0
            irqVector = 0
        }

        return ROMHeader(
            title: title,
            mapping: mapping,
            speed: speed,
            chipType: chipType,
            romSizeKB: romSizeKB,
            ramSizeKB: ramSizeKB,
            country: country,
            checksum: checksum,
            checksumComplement: checksumComplement,
            resetVector: resetVector,
            nmiVector: nmiVector,
            irqVector: irqVector
        )
    }

    // MARK: - Extract Tiles

    func extractTilesAtOffset(data: Data, offset: Int, depth: TileDepth, count: Int) -> [SNESTile] {
        let bytesPerTile = VRAMBudgetCalculator.tileSizeBytes(depth: depth)
        let bytes = [UInt8](data)
        var tiles: [SNESTile] = []

        for i in 0..<count {
            let tileOffset = offset + i * bytesPerTile
            guard tileOffset + bytesPerTile <= bytes.count else { break }

            let tileData = Array(bytes[tileOffset..<tileOffset + bytesPerTile])
            let pixels = decodePlanarTile(data: tileData, depth: depth)
            tiles.append(SNESTile(pixels: pixels, depth: depth))
        }

        return tiles
    }

    private func decodePlanarTile(data: [UInt8], depth: TileDepth) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: 64)

        for row in 0..<8 {
            // Bitplanes 0-1 are interleaved at bytes row*2 and row*2+1
            let bp0 = row < data.count / 2 ? data[row * 2] : 0
            let bp1 = row < data.count / 2 ? data[row * 2 + 1] : 0

            var bp2: UInt8 = 0
            var bp3: UInt8 = 0
            if depth == .bpp4 || depth == .bpp8 {
                let offset4 = 16 + row * 2
                bp2 = offset4 < data.count ? data[offset4] : 0
                bp3 = offset4 + 1 < data.count ? data[offset4 + 1] : 0
            }

            var bp4: UInt8 = 0, bp5: UInt8 = 0, bp6: UInt8 = 0, bp7: UInt8 = 0
            if depth == .bpp8 {
                let offset8 = 32 + row * 2
                bp4 = offset8 < data.count ? data[offset8] : 0
                bp5 = offset8 + 1 < data.count ? data[offset8 + 1] : 0
                let offset8b = 48 + row * 2
                bp6 = offset8b < data.count ? data[offset8b] : 0
                bp7 = offset8b + 1 < data.count ? data[offset8b + 1] : 0
            }

            for col in 0..<8 {
                let bit = UInt8(7 - col)
                var value: UInt8 = 0
                value |= ((bp0 >> bit) & 1)
                value |= ((bp1 >> bit) & 1) << 1
                if depth == .bpp4 || depth == .bpp8 {
                    value |= ((bp2 >> bit) & 1) << 2
                    value |= ((bp3 >> bit) & 1) << 3
                }
                if depth == .bpp8 {
                    value |= ((bp4 >> bit) & 1) << 4
                    value |= ((bp5 >> bit) & 1) << 5
                    value |= ((bp6 >> bit) & 1) << 6
                    value |= ((bp7 >> bit) & 1) << 7
                }
                pixels[row * 8 + col] = value
            }
        }

        return pixels
    }

    // MARK: - Scan for Palettes

    func scanForPalettes(data: Data) -> [ROMPaletteBlock] {
        let bytes = [UInt8](data)
        var blocks: [ROMPaletteBlock] = []
        let stride = 32  // 16 colors * 2 bytes each

        // Scan at every 32-byte boundary
        var offset = 0
        while offset + stride <= bytes.count && blocks.count < 64 {
            let paletteData = Array(bytes[offset..<offset + stride])

            // Heuristic: valid palette if first color is dark and colors vary
            if isProbablePalette(paletteData) {
                var colors: [SNESColor] = []
                for i in 0..<16 {
                    let lo = UInt16(paletteData[i * 2])
                    let hi = UInt16(paletteData[i * 2 + 1])
                    let raw = lo | (hi << 8)
                    colors.append(SNESColor(raw: raw))
                }
                let palette = SNESPalette(name: String(format: "ROM @ $%06X", offset), colors: colors)
                blocks.append(ROMPaletteBlock(offset: offset, palette: palette))
            }

            offset += stride
        }

        return blocks
    }

    private func isProbablePalette(_ data: [UInt8]) -> Bool {
        guard data.count >= 32 else { return false }

        // First color should have high bit clear (valid BGR555)
        let firstHi = data[1]
        if firstHi & 0x80 != 0 { return false }

        // Check all colors have high bit clear
        for i in 0..<16 {
            if data[i * 2 + 1] & 0x80 != 0 { return false }
        }

        // At least 4 distinct colors
        var uniqueColors = Set<UInt16>()
        for i in 0..<16 {
            let raw = UInt16(data[i * 2]) | (UInt16(data[i * 2 + 1]) << 8)
            uniqueColors.insert(raw)
        }
        return uniqueColors.count >= 4
    }
}
