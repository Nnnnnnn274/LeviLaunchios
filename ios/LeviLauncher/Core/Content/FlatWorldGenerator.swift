import Foundation

final class FlatWorldGenerator {
    static let shared = FlatWorldGenerator()

    struct FlatLayer {
        var blockName: String
        var count: Int
        var blockData: Int32
    }

    func generateFlatWorld(named name: String, layers: [FlatLayer], biome: String,
                           to worldDir: URL) throws {
        try FileManager.default.createDirectory(at: worldDir, withIntermediateDirectories: true)

        let root = NbtTag(type: .compound, name: "", value: [String: NbtTag]())
        let data = NbtTag(type: .compound, name: "Data", value: [String: NbtTag]())

        data.putTag("LevelName", NbtTag(type: .string, name: "LevelName", value: name))
        data.putTag("GameType", NbtTag(type: .int, name: "GameType", value: 1))
        data.putTag("Generator", NbtTag(type: .int, name: "Generator", value: 2))
        data.putTag("RandomSeed", NbtTag(type: .long, name: "RandomSeed", value: Int64(arc4random())))
        data.putTag("SpawnX", NbtTag(type: .int, name: "SpawnX", value: 0))
        data.putTag("SpawnY", NbtTag(type: .int, name: "SpawnY", value: 4))
        data.putTag("SpawnZ", NbtTag(type: .int, name: "SpawnZ", value: 0))
        data.putTag("allowCommands", NbtTag(type: .byte, name: "allowCommands", value: UInt8(0)))
        data.putTag("Difficulty", NbtTag(type: .int, name: "Difficulty", value: 0))
        data.putTag("DayCycleStopTime", NbtTag(type: .int, name: "DayCycleStopTime", value: 0))

        let flatWorldLayers = layers.map { layer -> String in
            "\(layer.blockName)x\(layer.count)"
        }.joined(separator: ";")
        let flatWorldPreset = "\(flatWorldLayers);\(biome)"
        data.putTag("FlatWorldLayers", NbtTag(type: .string, name: "FlatWorldLayers", value: flatWorldPreset))

        root.putTag("Data", data)

        let nbtData = try BedrockNbtWriter.write(root)
        try nbtData.write(to: worldDir.appendingPathComponent("level.dat"), options: .atomic)
        try nbtData.write(to: worldDir.appendingPathComponent("level.dat_old"), options: .atomic)
    }
}
