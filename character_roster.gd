extends RefCounted

const CHARACTERS = [
    {
        "id": "crimson",
        "name": "CRIMSON",
        "class": "Swing / Acrobat",
        "primary": "#c9182b",
        "primary_dark": "#7d101d",
        "secondary": "#152a69",
        "secondary_light": "#203f8f",
        "accent": "#f6f7f2",
        "stats": {"speed": 4, "acceleration": 5, "swing": 5, "air": 5, "combat": 2, "defense": 2},
        "movement": "Light, fast and built for long flowing web lines. Best air control in the starting roster.",
        "special": "Perfect Release — releasing near the fastest part of the arc gives a stronger launch.",
        "strength": "Best pure swing mobility and fast direction changes.",
        "weakness": "Low defense and weaker close-range pressure.",
        "speed_mult": 1.04,
        "accel_mult": 1.08,
        "air_mult": 1.10,
        "swing_mult": 1.10,
        "zip_mult": 1.00,
        "combat_mult": 0.86,
        "defense_mult": 0.88
    },
    {
        "id": "azure",
        "name": "AZURE",
        "class": "Tech / Zip",
        "primary": "#1677d2",
        "primary_dark": "#0b417d",
        "secondary": "#202a48",
        "secondary_light": "#35456f",
        "accent": "#8ff7ff",
        "stats": {"speed": 4, "acceleration": 4, "swing": 3, "air": 4, "combat": 3, "defense": 3},
        "movement": "Precise web-tech style focused on fast zips and clean line changes instead of huge arcs.",
        "special": "Overcharge Zip — web zip has more speed and keeps more momentum after arrival.",
        "strength": "Fast point-to-point movement and easy recovery after mistakes.",
        "weakness": "Less raw swing acceleration than Acrobat characters.",
        "speed_mult": 1.02,
        "accel_mult": 1.02,
        "air_mult": 1.02,
        "swing_mult": 0.94,
        "zip_mult": 1.15,
        "combat_mult": 1.00,
        "defense_mult": 1.00
    },
    {
        "id": "violet",
        "name": "VIOLET",
        "class": "Trickster / Air",
        "primary": "#8b3fc7",
        "primary_dark": "#4a1f72",
        "secondary": "#151929",
        "secondary_light": "#29304a",
        "accent": "#ffd3ff",
        "stats": {"speed": 5, "acceleration": 4, "swing": 4, "air": 5, "combat": 2, "defense": 2},
        "movement": "Loose aerial style for chaining flips, wall movement and future trick-combo mechanics.",
        "special": "Air Cancel — designed to cancel aerial tricks into a new swing with minimal speed loss.",
        "strength": "Highest style potential and excellent mid-air steering.",
        "weakness": "Fragile and less effective when forced to stay grounded.",
        "speed_mult": 1.08,
        "accel_mult": 1.00,
        "air_mult": 1.13,
        "swing_mult": 1.02,
        "zip_mult": 0.98,
        "combat_mult": 0.90,
        "defense_mult": 0.86
    },
    {
        "id": "gold",
        "name": "GOLD",
        "class": "Bruiser / Power",
        "primary": "#d89a20",
        "primary_dark": "#805313",
        "secondary": "#55231f",
        "secondary_light": "#78352e",
        "accent": "#fff1b0",
        "stats": {"speed": 3, "acceleration": 3, "swing": 3, "air": 2, "combat": 5, "defense": 5},
        "movement": "Heavy momentum character. Slower to redirect, but harder to knock around and built for combat.",
        "special": "Power Launch — future charged zip can turn into a heavy impact attack.",
        "strength": "Highest durability and strongest close-range archetype.",
        "weakness": "Slowest air correction and less forgiving swing lines.",
        "speed_mult": 0.94,
        "accel_mult": 0.90,
        "air_mult": 0.82,
        "swing_mult": 0.90,
        "zip_mult": 0.92,
        "combat_mult": 1.42,
        "defense_mult": 1.24
    }
]

static func count():
    return CHARACTERS.size()

static func get_character(index):
    var safe_index = posmod(index, CHARACTERS.size())
    return CHARACTERS[safe_index]

static func stars(value):
    var result = ""
    for i in range(5):
        result += "★" if i < int(value) else "☆"
    return result
