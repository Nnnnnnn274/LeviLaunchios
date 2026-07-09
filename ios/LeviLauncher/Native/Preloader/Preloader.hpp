#ifndef PRELOADER_HPP
#define PRELOADER_HPP

#include <string>
#include <vector>

namespace Preloader {

    struct ModInfo {
        std::string id;
        std::string name;
        std::string version;
        std::string author;
        bool enabled;
    };

    bool initialize(const std::string &gamePath);
    bool hookGameFunctions();
    bool loadMod(const std::string &modPath);
    bool isModLoaded(const std::string &modId);
    std::vector<std::string> getLoadedMods();
    size_t getModCount();
    std::string getModInfo(size_t index);

} // namespace Preloader

#endif // PRELOADER_HPP
