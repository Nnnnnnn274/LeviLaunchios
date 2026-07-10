#include "TwilightForestPort.hpp"

#include "../Hooks/BlockItemAPI.h"
#include "../Hooks/ContentRegistry.h"
#include "../Hooks/DimensionAPI.h"

#include <atomic>
#include <string>
#include <utility>
#include <vector>

namespace TwilightForestPort {
namespace {

std::atomic_bool s_enabled{true};
bool s_initialized = false;

BlockItemAPI::BlockDefinition makeBlock(const std::string &id,
                                        const std::string &name,
                                        const std::string &material,
                                        float hardness) {
    BlockItemAPI::BlockDefinition value{};
    value.id = id;
    value.displayName = name;
    value.textureTop = id;
    value.textureSide = id;
    value.textureBottom = id;
    value.hardness = hardness;
    value.resistance = hardness * 3.0f;
    value.lightOpacity = 1.0f;
    value.isSolid = true;
    value.isFullCube = true;
    value.material = material;
    value.soundType = material;
    return value;
}

BlockItemAPI::ItemDefinition makeItem(const std::string &id,
                                      const std::string &name,
                                      int maxStackSize) {
    BlockItemAPI::ItemDefinition value{};
    value.id = id;
    value.displayName = name;
    value.texture = id;
    value.maxStackSize = maxStackSize;
    value.creativeTab = "items";
    return value;
}

using Metadata = std::pair<const char *, ContentRegistry::RegistryType>;
const std::vector<Metadata> kMetadata = {
    {"levi_twilight:twilight_forest", ContentRegistry::RegistryType::Dimension},
    {"levi_twilight:twilight_oak_log", ContentRegistry::RegistryType::Block},
    {"levi_twilight:maze_stone", ContentRegistry::RegistryType::Block},
    {"levi_twilight:castle_brick", ContentRegistry::RegistryType::Block},
    {"levi_twilight:firefly_jar", ContentRegistry::RegistryType::Block},
    {"levi_twilight:magic_map", ContentRegistry::RegistryType::Item},
    {"levi_twilight:ore_magnet", ContentRegistry::RegistryType::Item},
    {"levi_twilight:lifedrain_scepter", ContentRegistry::RegistryType::Item},
    {"levi_twilight:enchanted_forest", ContentRegistry::RegistryType::Biome},
    {"levi_twilight:dark_forest", ContentRegistry::RegistryType::Biome},
    {"levi_twilight:naga", ContentRegistry::RegistryType::Entity},
    {"levi_twilight:lich", ContentRegistry::RegistryType::Entity},
    {"levi_twilight:naga_courtyard", ContentRegistry::RegistryType::Structure},
    {"levi_twilight:lich_tower", ContentRegistry::RegistryType::Structure}
};

const char *kNames[] = {
    "Twilight Forest", "Twilight Oak Log", "Maze Stone", "Castle Brick", "Firefly Jar",
    "Magic Map", "Ore Magnet", "Lifedrain Scepter", "Enchanted Forest", "Dark Forest",
    "Naga", "Twilight Lich", "Naga Courtyard", "Lich Tower"
};

void registerMetadata() {
    for (std::size_t i = 0; i < kMetadata.size(); ++i) {
        ContentRegistry::registerContent(kMetadata[i].first, kNames[i], kMetadata[i].second);
    }
}

void unregisterMetadata() {
    for (const auto &entry : kMetadata) {
        ContentRegistry::unregisterContent(entry.first, entry.second);
    }
}

} // namespace

void initialize() {
    if (s_initialized) return;
    s_initialized = true;

    BlockItemAPI::onRegisterBlocks([](std::vector<BlockItemAPI::BlockDefinition> &blocks) {
        if (!s_enabled.load()) return;
        blocks.push_back(makeBlock("levi_twilight:twilight_oak_log", "Twilight Oak Log", "wood", 2.0f));
        blocks.push_back(makeBlock("levi_twilight:maze_stone", "Maze Stone", "stone", 100.0f));
        blocks.push_back(makeBlock("levi_twilight:castle_brick", "Castle Brick", "stone", 8.0f));
        blocks.push_back(makeBlock("levi_twilight:firefly_jar", "Firefly Jar", "glass", 0.3f));
    });
    BlockItemAPI::onRegisterItems([](std::vector<BlockItemAPI::ItemDefinition> &items) {
        if (!s_enabled.load()) return;
        items.push_back(makeItem("levi_twilight:magic_map", "Magic Map", 1));
        items.push_back(makeItem("levi_twilight:ore_magnet", "Ore Magnet", 1));
        items.push_back(makeItem("levi_twilight:lifedrain_scepter", "Lifedrain Scepter", 1));
    });
    DimensionAPI::onRegisterDimensions([](std::vector<DimensionAPI::DimensionDefinition> &dimensions) {
        if (!s_enabled.load()) return;
        DimensionAPI::DimensionDefinition dimension{};
        dimension.id = "levi_twilight:twilight_forest";
        dimension.displayName = "Twilight Forest";
        dimension.height = 256;
        dimension.minY = 0;
        dimension.maxY = 256;
        dimension.coordinateScale = 1.0f;
        dimension.hasSkylight = true;
        dimension.natural = true;
        dimension.fixedTime = 13000;
        dimension.biomeSource = "custom";
        dimensions.push_back(std::move(dimension));
    });
    if (s_enabled.load()) registerMetadata();
}

void setEnabled(bool enabled) {
    s_enabled.store(enabled);
    if (enabled) registerMetadata();
    else unregisterMetadata();
}

bool isEnabled() {
    return s_enabled.load();
}

std::size_t contentCount() {
    return kMetadata.size();
}

} // namespace TwilightForestPort
