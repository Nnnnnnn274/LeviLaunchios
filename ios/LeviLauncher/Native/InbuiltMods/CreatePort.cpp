#include "CreatePort.hpp"

#include "../Hooks/BlockItemAPI.h"
#include "../Hooks/ContentRegistry.h"

#include <atomic>
#include <string>
#include <utility>
#include <vector>

namespace CreatePort {
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
    value.soundType = material == "metal" ? "metal" : "wood";
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
    value.creativeTab = "tools";
    return value;
}

using Metadata = std::pair<const char *, ContentRegistry::RegistryType>;
const std::vector<Metadata> kMetadata = {
    {"levi_create:cogwheel", ContentRegistry::RegistryType::Block},
    {"levi_create:shaft", ContentRegistry::RegistryType::Block},
    {"levi_create:gearbox", ContentRegistry::RegistryType::Block},
    {"levi_create:mechanical_press", ContentRegistry::RegistryType::Block},
    {"levi_create:creative_motor", ContentRegistry::RegistryType::Block},
    {"levi_create:wrench", ContentRegistry::RegistryType::Item},
    {"levi_create:brass_hand", ContentRegistry::RegistryType::Item},
    {"levi_create:mechanical_pressing", ContentRegistry::RegistryType::Recipe},
    {"levi_create:mechanical_mixing", ContentRegistry::RegistryType::Recipe},
    {"levi_create:rotation_spark", ContentRegistry::RegistryType::Particle}
};

const char *kNames[] = {
    "Cogwheel", "Shaft", "Gearbox", "Mechanical Press", "Creative Motor",
    "Wrench", "Brass Hand", "Mechanical Pressing", "Mechanical Mixing", "Rotation Spark"
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
        blocks.push_back(makeBlock("levi_create:cogwheel", "Cogwheel", "wood", 1.5f));
        blocks.push_back(makeBlock("levi_create:shaft", "Shaft", "wood", 1.5f));
        blocks.push_back(makeBlock("levi_create:gearbox", "Gearbox", "wood", 2.0f));
        blocks.push_back(makeBlock("levi_create:mechanical_press", "Mechanical Press", "metal", 5.0f));
        blocks.push_back(makeBlock("levi_create:creative_motor", "Creative Motor", "metal", 5.0f));
    });
    BlockItemAPI::onRegisterItems([](std::vector<BlockItemAPI::ItemDefinition> &items) {
        if (!s_enabled.load()) return;
        items.push_back(makeItem("levi_create:wrench", "Wrench", 1));
        items.push_back(makeItem("levi_create:brass_hand", "Brass Hand", 64));
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

} // namespace CreatePort
