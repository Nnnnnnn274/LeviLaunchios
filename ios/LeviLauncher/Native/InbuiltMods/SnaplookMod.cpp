#include "SnaplookMod.hpp"

namespace SnaplookMod {

    static bool g_enabled = false;

    void setEnabled(bool enabled) {
        g_enabled = enabled;
        // TODO: Hook camera perspective to force front view
    }

    bool isEnabled() {
        return g_enabled;
    }

} // namespace SnaplookMod
