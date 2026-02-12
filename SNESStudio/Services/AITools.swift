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
            description: "Retourne les informations du projet courant (cartouche, fichiers source, palettes, tiles, etc.)",
            properties: [:],
            required: []
        ),
    ]

    // MARK: - Palette tools

    static let paletteTools: [[String: Any]] = [
        makeTool(
            name: "get_palette",
            description: "Retourne les 16 couleurs d'une palette SNES (indices 0-15). Chaque couleur est en BGR555 (0-31 par composante).",
            properties: [
                "palette_index": ["type": "integer", "description": "Index de la palette (0-15)"],
            ],
            required: ["palette_index"]
        ),
        makeTool(
            name: "set_palette_color",
            description: "Modifie une couleur dans une palette SNES. Composantes BGR555: r, g, b de 0 a 31.",
            properties: [
                "palette_index": ["type": "integer", "description": "Index de la palette (0-15)"],
                "color_index": ["type": "integer", "description": "Index de la couleur dans la palette (0-15)"],
                "r": ["type": "integer", "description": "Composante rouge (0-31)"],
                "g": ["type": "integer", "description": "Composante verte (0-31)"],
                "b": ["type": "integer", "description": "Composante bleue (0-31)"],
            ],
            required: ["palette_index", "color_index", "r", "g", "b"]
        ),
    ]

    // MARK: - Tile tools

    static let tileTools: [[String: Any]] = [
        makeTool(
            name: "set_tile_pixel",
            description: "Modifie un pixel d'un tile 8x8. La valeur est un index de couleur dans la palette.",
            properties: [
                "tile_index": ["type": "integer", "description": "Index du tile"],
                "x": ["type": "integer", "description": "Position X (0-7)"],
                "y": ["type": "integer", "description": "Position Y (0-7)"],
                "color_index": ["type": "integer", "description": "Index couleur palette"],
            ],
            required: ["tile_index", "x", "y", "color_index"]
        ),
        makeTool(
            name: "set_tile_pixels_batch",
            description: "Modifie plusieurs pixels d'un tile en une seule operation. Chaque pixel est {x, y, color_index}.",
            properties: [
                "tile_index": ["type": "integer", "description": "Index du tile"],
                "pixels": [
                    "type": "array",
                    "description": "Liste de pixels a modifier",
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
            description: "Modifie une entree de la tilemap a la position (x, y). Permet de placer un tile avec palette, flips et priorite.",
            properties: [
                "x": ["type": "integer", "description": "Position X en tiles"],
                "y": ["type": "integer", "description": "Position Y en tiles"],
                "tile_index": ["type": "integer", "description": "Index du tile a placer"],
                "palette_index": ["type": "integer", "description": "Index de la palette (0-7)"],
                "flip_h": ["type": "boolean", "description": "Flip horizontal"],
                "flip_v": ["type": "boolean", "description": "Flip vertical"],
                "priority": ["type": "boolean", "description": "Priorite haute"],
            ],
            required: ["x", "y", "tile_index"]
        ),
    ]

    // MARK: - Sprite tools

    static let spriteTools: [[String: Any]] = [
        makeTool(
            name: "add_sprite",
            description: "Ajoute un nouveau sprite (entree OAM) avec position, tile, palette et taille.",
            properties: [
                "x": ["type": "integer", "description": "Position X (0-255)"],
                "y": ["type": "integer", "description": "Position Y (0-223)"],
                "tile_index": ["type": "integer", "description": "Index du tile"],
                "palette_index": ["type": "integer", "description": "Index palette (0-7)"],
                "size": ["type": "string", "description": "Taille: small8x8, large16x16, large32x32, large64x64", "enum": ["small8x8", "large16x16", "large32x32", "large64x64"]],
            ],
            required: ["x", "y", "tile_index"]
        ),
        makeTool(
            name: "move_sprite",
            description: "Deplace un sprite existant a une nouvelle position.",
            properties: [
                "sprite_index": ["type": "integer", "description": "Index du sprite dans la liste OAM"],
                "x": ["type": "integer", "description": "Nouvelle position X"],
                "y": ["type": "integer", "description": "Nouvelle position Y"],
            ],
            required: ["sprite_index", "x", "y"]
        ),
    ]

    // MARK: - Controller tools

    static let controllerTools: [[String: Any]] = [
        makeTool(
            name: "set_button_mapping",
            description: "Assigne une action a un bouton de la manette SNES.",
            properties: [
                "button": ["type": "string", "description": "Nom du bouton", "enum": ["a", "b", "x", "y", "l", "r", "start", "select", "up", "down", "left", "right"]],
                "label": ["type": "string", "description": "Label de l'action (ex: Jump)"],
                "asm_routine": ["type": "string", "description": "Nom de la routine ASM (ex: PlayerJump)"],
            ],
            required: ["button", "label", "asm_routine"]
        ),
    ]

    // MARK: - Code tools

    static let codeTools: [[String: Any]] = [
        makeTool(
            name: "insert_code",
            description: "Insere du code assembleur a une ligne donnee dans le fichier actif.",
            properties: [
                "line": ["type": "integer", "description": "Numero de ligne (1-based) ou inserer"],
                "code": ["type": "string", "description": "Code ASM a inserer"],
            ],
            required: ["line", "code"]
        ),
        makeTool(
            name: "replace_code",
            description: "Remplace des lignes de code dans le fichier actif.",
            properties: [
                "start_line": ["type": "integer", "description": "Premiere ligne a remplacer (1-based)"],
                "end_line": ["type": "integer", "description": "Derniere ligne a remplacer (1-based, inclusive)"],
                "code": ["type": "string", "description": "Code ASM de remplacement"],
            ],
            required: ["start_line", "end_line", "code"]
        ),
    ]

    // MARK: - World tools

    static let worldTools: [[String: Any]] = [
        makeTool(
            name: "add_zone",
            description: "Ajoute une nouvelle zone au monde du jeu.",
            properties: [
                "name": ["type": "string", "description": "Nom de la zone"],
                "type": ["type": "string", "description": "Type de zone", "enum": ["Overworld", "Sidescroll", "Room-based", "Fixed Screen"]],
                "bg_mode": ["type": "integer", "description": "Mode BG SNES (0-7)"],
                "grid_width": ["type": "integer", "description": "Largeur de la grille en ecrans"],
                "grid_height": ["type": "integer", "description": "Hauteur de la grille en ecrans"],
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
