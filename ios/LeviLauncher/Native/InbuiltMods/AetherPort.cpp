#include "AetherPort.hpp"

#include "../Hooks/BlockItemAPI.h"
#include "../Hooks/ContentRegistry.h"
#include "../Hooks/DimensionAPI.h"

#include <atomic>
#include <string>
#include <utility>
#include <vector>

namespace AetherPort {
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
    {"levi_aether:aether", ContentRegistry::RegistryType::Dimension},
    {"levi_aether:holystone", ContentRegistry::RegistryType::Block},
    {"levi_aether:aerogel", ContentRegistry::RegistryType::Block},
    {"levi_aether:skyroot_log", ContentRegistry::RegistryType::Block},
    {"levi_aether:golden_oak_leaves", ContentRegistry::RegistryType::Block},
    {"levi_aether:ambrosium_shard", ContentRegistry::RegistryType::Item},
    {"levi_aether:zanite_gemstone", ContentRegistry::RegistryType::Item},
    {"levi_aether:cloud_staff", ContentRegistry::RegistryType::Item},
    {"levi_aether:skyroot_meadow", ContentRegistry::RegistryType::Biome},
    {"levi_aether:highlands", ContentRegistry::RegistryType::Biome},
    {"levi_aether:moa", ContentRegistry::RegistryType::Entity},
    {"levi_aether:zephyr", ContentRegistry::RegistryType::Entity},
    {"levi_aether:bronze_dungeon", ContentRegistry::RegistryType::Structure}
};

const char *kNames[] = {
    "Aether", "Holystone", "Aerogel", "Skyroot Log", "Golden Oak Leaves",
    "Ambrosium Shard", "Zanite Gemstone", "Cloud Staff", "Skyroot Meadow",
    "Aether Highlands", "Moa", "Zephyr", "Bronze Dungeon"
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
        blocks.push_back(makeBlock("levi_aether:holystone", "Holystone", "stone", 1.5f));
        blocks.push_back(makeBlock("levi_aether:aerogel", "Aerogel", "glass", 0.5f));
        blocks.push_back(makeBlock("levi_aether:skyroot_log", "Skyroot Log", "wood", 2.0f));
        blocks.push_back(makeBlock("levi_aether:golden_oak_leaves", "Golden Oak Leaves", "grass", 0.2f));
    });
    BlockItemAPI::onRegisterItems([](std::vector<BlockItemAPI::ItemDefinition> &items) {
        if (!s_enabled.load()) return;
        items.push_back(makeItem("levi_aether:ambrosium_shard", "Ambrosium Shard", 64));
        items.push_back(makeItem("levi_aether:zanite_gemstone", "Zanite Gemstone", 64));
        items.push_back(makeItem("levi_aether:cloud_staff", "Cloud Staff", 1));
    });
    DimensionAPI::onRegisterDimensions([](std::vector<DimensionAPI::DimensionDefinition> &dimensions) {
        if (!s_enabled.load()) return;
        DimensionAPI::DimensionDefinition dimension{};
        dimension.id = "levi_aether:aether";
        dimension.displayName = "Aether";
        dimension.height = 384;
        dimension.minY = 0;
        dimension.maxY = 384;
        dimension.coordinateScale = 1.0f;
        dimension.hasSkylight = true;
        dimension.natural = true;
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

} // namespace AetherPort
