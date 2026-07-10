#ifndef CREATEPORT_HPP
#define CREATEPORT_HPP

#include <cstddef>

namespace CreatePort {

void initialize();
void setEnabled(bool enabled);
bool isEnabled();
std::size_t contentCount();

} // namespace CreatePort

#endif
