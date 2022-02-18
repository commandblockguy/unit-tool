# ----------------------------
# Makefile Options
# ----------------------------

NAME = UNITS
ICON = icon.png
DESCRIPTION = "Unit Manipulation Tool"
COMPRESSED = NO
ARCHIVED = YES

CFLAGS = -Wall -Wextra -Oz
CXXFLAGS = -Wall -Wextra -Oz

# ----------------------------

include $(shell cedev-config --makefile)
