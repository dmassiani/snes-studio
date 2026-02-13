import Foundation

/// Defines AI tool schemas for the Anthropic API, organized by active editor.
enum AITools {
    // MARK: - Get tools for active editor

    static func tools(for editor: ActiveEditor) -> [[String: Any]] {
        var result = generalTools
        switch editor {
        case .palette:
            result += paletteTools
        case .tile:
            result += tileTools
        case .tilemap:
            result += tilemapTools
        case .sprite:
            result += spriteTools
        case .controller:
            result += controllerTools
        case .code:
            result += codeTools
        case .world:
            result += worldTools
        default:
            break
        }
        return result
    }

    // MARK: - General (always available)

    static let generalTools: [[String: Any]] = [
        makeTool(
            name: "get_project_info",
            description: "Returns current project information (cartridge, source files, palettes, tiles, etc.)",
            properties: [:],
            required: []
        ),
    ]

    // MARK: - Palette tools

    static let paletteTools: [[String: Any]] = [
        makeTool(
            name: "get_palette",
            description: "Returns the 16 colors of a SNES palette (indices 0-15). Each color is in BGR555 (0-31 per component).",
            properties: [
                "palette_index": ["type": "integer", "description": "Palette index (0-15)"],
            ],
            required: ["palette_index"]
        ),
        makeTool(
            name: "set_palette_color",
            description: "Modifies a color in a SNES palette. BGR555 components: r, g, b from 0 to 31.",
            properties: [
                "palette_index": ["type": "integer", "description": "Palette index (0-15)"],
                "color_index": ["type": "integer", "description": "Color index in the palette (0-15)"],
                "r": ["type": "integer", "description": "Red component (0-31)"],
                "g": ["type": "integer", "description": "Green component (0-31)"],
                "b": ["type": "integer", "description": "Blue component (0-31)"],
            ],
            required: ["palette_index", "color_index", "r", "g", "b"]
        ),
    ]

    // MARK: - Tile tools

    static let tileTools: [[String: Any]] = [
        makeTool(
            name: "set_tile_pixel",
            description: "Modifies a pixel of an 8x8 tile. The value is a color index in the palette.",
            properties: [
                "tile_index": ["type": "integer", "description": "Tile index"],
                "x": ["type": "integer", "description": "Position X (0-7)"],
                "y": ["type": "integer", "description": "Position Y (0-7)"],
                "color_index": ["type": "integer", "description": "Palette color index"],
            ],
            required: ["tile_index", "x", "y", "color_index"]
        ),
        makeTool(
            name: "set_tile_pixels_batch",
            description: "Modifies multiple pixels of a tile in a single operation. Each pixel is {x, y, color_index}.",
            properties: [
                "tile_index": ["type": "integer", "description": "Tile index"],
                "pixels": [
                    "type": "array",
                    "description": "List of pixels to modify",
                    "items": [
                        "type": "object",
                        "properties": [
                            "x": ["type": "integer"],
                            "y": ["type": "integer"],
                            "color_index": ["type": "integer"],
                        ] as [String: Any],
                        "required": ["x", "y", "color_index"],
                    ] as [String: Any],
                ] as [String: Any],
            ],
            required: ["tile_index", "pixels"]
        ),
    ]

    // MARK: - Tilemap tools

    static let tilemapTools: [[String: Any]] = [
        makeTool(
            name: "set_tilemap_entry",
            description: "Modifies a tilemap entry at position (x, y). Places a tile with palette, flips and priority.",
            properties: [
                "x": ["type": "integer", "description": "X position in tiles"],
                "y": ["type": "integer", "description": "Y position in tiles"],
                "tile_index": ["type": "integer", "description": "Tile index to place"],
                "palette_index": ["type": "integer", "description": "Palette index (0-7)"],
                "flip_h": ["type": "boolean", "description": "Flip horizontal"],
                "flip_v": ["type": "boolean", "description": "Flip vertical"],
                "priority": ["type": "boolean", "description": "High priority"],
            ],
            required: ["x", "y", "tile_index"]
        ),
    ]

    // MARK: - Sprite tools

    static let spriteTools: [[String: Any]] = [
        makeTool(
            name: "add_sprite",
            description: "Adds a new sprite (OAM entry) with position, tile, palette and size.",
            properties: [
                "x": ["type": "integer", "description": "Position X (0-255)"],
                "y": ["type": "integer", "description": "Position Y (0-223)"],
                "tile_index": ["type": "integer", "description": "Tile index"],
                "palette_index": ["type": "integer", "description": "Palette index (0-7)"],
                "size": ["type": "string", "description": "Size: small8x8, large16x16, large32x32, large64x64", "enum": ["small8x8", "large16x16", "large32x32", "large64x64"]],
            ],
            required: ["x", "y", "tile_index"]
        ),
        makeTool(
            name: "move_sprite",
            description: "Moves an existing sprite to a new position.",
            properties: [
                "sprite_index": ["type": "integer", "description": "Sprite index in OAM list"],
                "x": ["type": "integer", "description": "New X position"],
                "y": ["type": "integer", "description": "New Y position"],
            ],
            required: ["sprite_index", "x", "y"]
        ),
    ]

    // MARK: - Controller tools

    static let controllerTools: [[String: Any]] = [
        makeTool(
            name: "set_button_mapping",
            description: "Assigns an action to a SNES controller button.",
            properties: [
                "button": ["type": "string", "description": "Button name", "enum": ["a", "b", "x", "y", "l", "r", "start", "select", "up", "down", "left", "right"]],
                "label": ["type": "string", "description": "Action label (e.g. Jump)"],
                "asm_routine": ["type": "string", "description": "ASM routine name (e.g. PlayerJump)"],
            ],
            required: ["button", "label", "asm_routine"]
        ),
    ]

    // MARK: - Code tools

    static let codeTools: [[String: Any]] = [
        makeTool(
            name: "insert_code",
            description: "Inserts assembly code at a given line in the active file.",
            properties: [
                "line": ["type": "integer", "description": "Line number (1-based) to insert at"],
                "code": ["type": "string", "description": "ASM code to insert"],
            ],
            required: ["line", "code"]
        ),
        makeTool(
            name: "replace_code",
            description: "Replaces lines of code in the active file.",
            properties: [
                "start_line": ["type": "integer", "description": "First line to replace (1-based)"],
                "end_line": ["type": "integer", "description": "Last line to replace (1-based, inclusive)"],
                "code": ["type": "string", "description": "Replacement ASM code"],
            ],
            required: ["start_line", "end_line", "code"]
        ),
    ]

    // MARK: - World tools

    static let worldTools: [[String: Any]] = [
        makeTool(
            name: "add_zone",
            description: "Adds a new zone to the game world.",
            properties: [
                "name": ["type": "string", "description": "Zone name"],
                "type": ["type": "string", "description": "Zone type", "enum": ["Overworld", "Sidescroll", "Room-based", "Fixed Screen"]],
                "bg_mode": ["type": "integer", "description": "Mode BG SNES (0-7)"],
                "grid_width": ["type": "integer", "description": "Grid width in screens"],
                "grid_height": ["type": "integer", "description": "Grid height in screens"],
            ],
            required: ["name", "type", "bg_mode", "grid_width", "grid_height"]
        ),
    ]

    // MARK: - Helper

    private static func makeTool(
        name: String,
        description: String,
        properties: [String: [String: Any]],
        required: [String]
    ) -> [String: Any] {
        [
            "name": name,
            "description": description,
            "input_schema": [
                "type": "object",
                "properties": properties,
                "required": required,
            ] as [String: Any],
        ]
    }
}
