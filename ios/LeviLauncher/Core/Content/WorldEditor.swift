import Foundation

final class WorldEditor {
    static let shared = WorldEditor()

    func readWorldProperties(from worldDir: URL) throws -> (name: String, gameMode: Int32, difficulty: Int32, seed: Int64, cheats: Bool)? {
        let levelDatURL = worldDir.appendingPathComponent("level.dat")
        guard let tag = try BedrockNbtReader.read(from: levelDatURL),
              let data = tag.tag("Data") else { return nil }

        let name = data.tag("LevelName")?.stringValue ?? worldDir.lastPathComponent
        let gameMode = data.tag("GameType")?.intValue ?? 0
        let difficulty = data.tag("Difficulty")?.intValue ?? 0
        let seed = data.tag("RandomSeed")?.longValue ?? 0
        let cheats = data.tag("allowCommands")?.byteValue != 0

        return (name, gameMode, difficulty, seed, cheats)
    }

    func writeWorldProperties(_ props: (name: String, gameMode: Int32, difficulty: Int32, seed: Int64, cheats: Bool),
                              to worldDir: URL) throws {
        let levelDatURL = worldDir.appendingPathComponent("level.dat")
        guard let tag = try BedrockNbtReader.read(from: levelDatURL),
              let data = tag.tag("Data") else { return }

        let dataTag = data
        dataTag.putTag("LevelName", NbtTag(type: .string, name: "LevelName", value: props.name))
        dataTag.putTag("GameType", NbtTag(type: .int, name: "GameType", value: props.gameMode))
        dataTag.putTag("Difficulty", NbtTag(type: .int, name: "Difficulty", value: props.difficulty))
        dataTag.putTag("RandomSeed", NbtTag(type: .long, name: "RandomSeed", value: props.seed))
        dataTag.putTag("allowCommands", NbtTag(type: .byte, name: "allowCommands", value: UInt8(props.cheats ? 1 : 0)))

        let newData = try BedrockNbtWriter.write(tag)
        try newData.write(to: levelDatURL, options: .atomic)
    }
}
