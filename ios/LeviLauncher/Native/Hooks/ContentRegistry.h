#ifndef CONTENTREGISTRY_H
#define CONTENTREGISTRY_H

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

namespace ContentRegistry {

    // ── Registry IDs ───────────────────────────────────────
    // Unique identifiers for registries used by both the modloader
    // and hook functions to locate specific registries.
    enum class RegistryType : uint32_t {
        Block        = 0,
        Item         = 1,
        Biome        = 2,
        Dimension    = 3,
        Entity       = 4,
        Enchantment  = 5,
        PotionEffect = 6,
        Particle     = 7,
        Sound        = 8,
        Recipe       = 9,
        Villager     = 10,
        Feature      = 11,
        Structure    = 12,
        _Count
    };

    // ── Content Entry ──────────────────────────────────────
    struct ContentEntry {
        std::string id;            // "mymod:custom_dimension"
        std::string name;          // "Custom Dimension"
        RegistryType type;
        int numericId;              // assigned at runtime
        void *nativePtr;            // pointer to the native Minecraft object
    };

    // ── Callbacks ──────────────────────────────────────────

    // Called when a registry is populated (e.g. blocks being registered)
    // Allows mods to inject their own entries
    using RegistryHook = std::function<void(RegistryType type,
                                             std::vector<ContentEntry> &entries)>;

    // Called during world/level creation to inject custom dimensions
    using DimensionInjectCallback = std::function<void(void *level,
                                                        std::vector<std::string> &dimensionIds)>;

    // Called during block/item registration
    using BlockRegistryCallback = std::function<void(void *blockRegistry)>;
    using ItemRegistryCallback = std::function<void(void *itemRegistry)>;

    // ── API ────────────────────────────────────────────────

    // Initialize registry hooking system
    // This installs inline hooks on Minecraft's registration functions
    bool initialize();

    // Register a callback that fires during game init
    // to add custom content to a specific registry
    void onRegistryPopulate(RegistryType type, RegistryHook hook);

    // Register a callback to inject custom dimensions during level creation
    void onDimensionInject(DimensionInjectCallback callback);

    // Register a callback during block/item registration
    void onBlockRegister(BlockRegistryCallback callback);
    void onItemRegister(ItemRegistryCallback callback);

    // Manual content registration (called from mods)
    bool registerContent(const std::string &id, const std::string &name,
                         RegistryType type, void *nativePtr = nullptr);

    // Removes metadata only; materialized native Minecraft objects are retained.
    bool unregisterContent(const std::string &id, RegistryType type);

    // Queries
    const ContentEntry *getEntry(RegistryType type, const std::string &id);
    std::vector<ContentEntry> getEntries(RegistryType type);

    // Clear all registrations and hooks
    void reset();

} // namespace ContentRegistry

#endif
