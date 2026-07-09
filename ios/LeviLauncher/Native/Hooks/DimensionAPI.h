#ifndef DIMENSIONAPI_H
#define DIMENSIONAPI_H

#include <cstdint>
#include <functional>
#include <string>

namespace DimensionAPI {

    // ── Dimension definition ──────────────────────────────
    // A mod provides this to register a custom dimension

    struct DimensionDefinition {
        std::string id;          // "mymod:custom_dimension"
        std::string displayName;// "Custom Dimension"
        int height;              // world height (e.g. 256)
        int minY;                // min Y (e.g. -64)
        int maxY;                // max Y (e.g. 320)
        float coordinateScale;   // default 1.0
        bool hasCeiling;         // default true for nether-like
        bool hasSkylight;        // default true for overworld-like
        bool ultraWarm;          // default true for nether-like
        bool natural;            // default true
        uint64_t fixedTime;      // 0 for normal day/night
        std::string biomeSource; // "overworld", "nether", "the_end", or "custom"
    };

    // ── Callbacks ─────────────────────────────────────────

    // Called when dimensions are being registered
    // Return your dimension definitions to inject them
    using DimensionProvider = std::function<void(
        std::vector<DimensionDefinition> &dimensions)>;

    // Called when a dimension is about to be created/loaded
    // Allows modifying dimension settings before creation
    using DimensionPreCreate = std::function<void(
        const std::string &dimensionId,
        DimensionDefinition &settings)>;

    // ── API ───────────────────────────────────────────────

    bool initialize();

    // Register a provider that adds custom dimensions
    void onRegisterDimensions(DimensionProvider provider);

    // Register a pre-create hook
    void onPreCreateDimension(DimensionPreCreate hook);

} // namespace DimensionAPI

#endif
