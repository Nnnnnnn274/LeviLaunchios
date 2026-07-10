#ifndef BLOCKITEMAPI_H
#define BLOCKITEMAPI_H

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

namespace BlockItemAPI {

    // ── Block definition (what a mod provides) ────────────
    struct BlockDefinition {
        std::string id;             // "mymod:custom_block"
        std::string displayName;    // "Custom Block"
        std::string textureTop;     // texture path
        std::string textureSide;
        std::string textureBottom;
        float hardness;             // 0.0 - 50.0
        float resistance;           // 0.0 - 6000.0
        float lightEmission;        // 0.0 - 1.0
        float lightOpacity;         // 0.0 - 1.0
        bool isTransparent;
        bool isSolid;
        bool isLiquid;
        bool isFullCube;
        int renderType;             // 0=normal, 1=cutout, 2=transparent, etc
        std::string material;       // "stone", "wood", "dirt", "water", etc
        std::string soundType;      // "stone", "wood", "metal", etc
    };

    // ── Item definition ───────────────────────────────────
    struct ItemDefinition {
        std::string id;             // "mymod:custom_item"
        std::string displayName;    // "Custom Item"
        std::string texture;        // texture path
        int maxStackSize;           // 1-64
        int maxDamage;              // 0 = unbreakable
        bool isFood;
        int foodRestore;            // hunger points
        float foodSaturation;
        std::string useDuration;    // "fast", "normal", "slow"
        std::string creativeTab;    // "building", "items", "tools", etc
    };

    // ── Callbacks ─────────────────────────────────────────
    using BlockProvider = std::function<void(
        std::vector<BlockDefinition> &blocks)>;

    using ItemProvider = std::function<void(
        std::vector<ItemDefinition> &items)>;

    // Called during block registration to inject custom blocks
    using BlockRegistrationHook = std::function<void(
        void *blockRegistry,
        const std::vector<BlockDefinition> &customBlocks)>;

    // Called during item registration to inject custom items
    using ItemRegistrationHook = std::function<void(
        void *itemRegistry,
        const std::vector<ItemDefinition> &customItems)>;

    // ── API ───────────────────────────────────────────────

    bool initialize();

    void onRegisterBlocks(BlockProvider provider);
    void onRegisterItems(ItemProvider provider);

    void onBlockRegistration(BlockRegistrationHook hook);
    void onItemRegistration(ItemRegistrationHook hook);

} // namespace BlockItemAPI

#endif
