#!/usr/bin/env python3

import os
import sys
import json
from typing import Optional, Final
import urllib.parse
import urllib3
from datetime import datetime, timedelta

CACHED_RESPONSE_FILE: Final[str] = os.path.expanduser("~/.cache/hyprland/weather.json")
GEO_INFO_FILE: Final[str] = os.path.expanduser("~/.geoinfo")

WEATHER_CODES: Final[dict] = {
    "113": "☀️",
    "116": "⛅",
    "119": "⛅",
    "122": "⛅",
    "143": "⛅",
    "176": "🌦️",
    "179": "🌦️",
    "182": "🌦️",
    "185": "🌦️",
    "200": "⛈️",
    "227": "🌨️",
    "230": "🌨️",
    "248": "☁️ ",
    "260": "☁️",
    "263": "🌧️",
    "266": "🌧️",
    "281": "🌧️",
    "284": "🌧️",
    "293": "🌧️",
    "296": "🌧️",
    "299": "🌧️",
    "302": "🌧️",
    "305": "🌧️",
    "308": "🌧️",
    "311": "🌧️",
    "314": "🌧️",
    "317": "🌧️",
    "320": "🌨️",
    "323": "🌨️",
    "326": "🌨️",
    "329": "❄️",
    "332": "❄️",
    "335": "❄️",
    "338": "❄️",
    "350": "🌧️",
    "353": "🌧️",
    "356": "🌧️",
    "359": "🌧️",
    "362": "🌧️",
    "365": "🌧️",
    "368": "🌧️",
    "371": "❄️",
    "374": "🌨️",
    "377": "🌨️",
    "386": "🌨️",
    "389": "🌨️",
    "392": "🌧️",
    "395": "❄️",
}


def format_time(time: str) -> str:
    return time.replace("00", "").zfill(2)


def format_temp(temp: str) -> str:
    return (temp + "°").ljust(3)


def format_day_summary(day: dict) -> str:
    summary = f"{WEATHER_CODES[day['hourly'][0]['weatherCode']]} with a high of {day['maxtempC']}° and a low of {day['mintempC']}°.\n"
    # summary = ""
    for hour in day["hourly"]:
        summary += (
            " ".join(
                [
                    format_time(hour["time"]),
                    WEATHER_CODES[hour["weatherCode"]],
                    format_temp(hour["FeelsLikeC"]),
                    hour["weatherDesc"][0]["value"].strip(),
                ]
            )
            + f", {format_chances(hour)}\n"
        )
    return summary


def format_day_header(i: int, day: dict) -> str:
    d_header = "\n<b>"
    if i == -1:
        d_header += "Today, "
    elif i == 0:
        d_header += "Tomorrow, "
    d_header += f"{day['date']}</b>\n"

    d_header += (
        f"⬆️{day['maxtempC']}° ⬇️{day['mintempC']}° "
        + f"🌅{day['astronomy'][0]['sunrise']} 🌇{day['astronomy'][0]['sunset']}\n"
    )
    return d_header


def format_header(city: str, day: dict) -> str:
    # <b>Athenas: Clear 26°</b>
    header = (
        "<b>"
        + f"{city}: "
        + f"{day['weatherDesc'][0]['value']} "
        + f"{day['temp_C']}°"
        + "</b>\n"
    )
    header += f"Temperature: {day['temp_C']}°\n"
    header += f"Feels like: {day['FeelsLikeC']}°\n"
    header += f"Wind: {day['windspeedKmph']}Km/h\n"
    header += f"Humidity: {day['humidity']}%\n"

    return header


def format_chances(hour: str) -> str:
    chances = {
        "chanceoffog": "🌫️",
        "chanceoffrost": "❄️",
        "chanceofovercast": "⛅️",
        "chanceofrain": "☔️",
        "chanceofsnow": "🌨️",
        "chanceofsunshine": "☀️",
        "chanceofthunder": "⚡️",
        "chanceofwindy": "💨",
    }

    conditions = []
    for event in chances.keys():
        if int(hour[event]) > 0:
            conditions.append(f"{chances[event]} {hour[event]}%")

    return ", ".join(conditions)


def generate_tooltip_str(weather: dict) -> str:
    tooltip = ""

    if len(weather["weather"]) > 0:
        tooltip += format_header(
            weather["nearest_area"][0]["areaName"][0]["value"],
            weather["current_condition"][0],
        )

    for i, day in enumerate(weather["weather"]):
        tooltip += format_day_header(i, day)
        tooltip += format_day_summary(day)

    return tooltip


def make_waybar_json(weather: dict) -> str:
    data = {}

    tempint = int(weather["current_condition"][0]["FeelsLikeC"])
    extrachar = ""
    if tempint > 0 and tempint < 10:
        extrachar = "+"

    data["text"] = (
        " "
        + WEATHER_CODES[weather["current_condition"][0]["weatherCode"]]
        + " "
        + extrachar
        + weather["current_condition"][0]["FeelsLikeC"]
        + "°"
    )
    data["alt"] = weather["nearest_area"][0]["areaName"][0]["value"]
    data["tooltip"] = generate_tooltip_str(weather)

    return json.dumps(data)


# Assuming it is valid JSON
def json_loads_with_abandon(s: str) -> Optional[dict]:
    try:
        return eval(
            s,
            {
                "__builtins__": None,
                "null": None,
                "true": True,
                "false": False,
                # outside of JSON spec
                "NaN": float("nan"),
                "Infinity": float("inf"),
                # "-Infinity" == -(Infinity)
            },
        )
    except Exception:
        return None


def retrieve_weather_data() -> Optional[str]:
    if os.path.exists(CACHED_RESPONSE_FILE):
        file_age = datetime.now() - datetime.fromtimestamp(
            os.path.getmtime(CACHED_RESPONSE_FILE)
        )

        # If file is newer than 30m, read from the file
        if file_age < timedelta(minutes=30):
            with open(CACHED_RESPONSE_FILE, "r") as f:
                return json_loads_with_abandon(f.read())

    city = ""
    if os.path.exists(GEO_INFO_FILE):
        with open(GEO_INFO_FILE, "r") as f:
            city = f.read().split("\n")[0]

    try:
        city = urllib.parse.quote(city)
        http = urllib3.PoolManager().request(
            "GET", f"https://wttr.in/{city}?format=j1", headers={}
        )

        json_string = http.data.decode("utf-8")
    except Exception:
        return None

    # Update weather data
    with open(CACHED_RESPONSE_FILE, "w") as f:
        f.write(json_string)

    return json_loads_with_abandon(json_string)


def make_hyprlock_fmt(weather: dict) -> str:
    degrees = weather["current_condition"][0]["temp_C"]
    feelsl = weather["current_condition"][0]["FeelsLikeC"]
    emoji = WEATHER_CODES[weather["current_condition"][0]["weatherCode"]]
    return f"<b>{degrees}° — Feels like <big>{feelsl}° {emoji}</big></b>"


def main() -> int:
    weather_data = retrieve_weather_data()

    if weather_data is None:
        print(
            "Error: Could not retrieve weather data cuz bruh, you're offline, or something, idk.",
            file=sys.stderr,
        )
        return 1

    argv = sys.argv[1:]

    if len(argv) == 0:
        argv.append("")

    match argv[0]:
        case "hyprlock":
            print(make_hyprlock_fmt(weather_data))
        case "waybar":
            print(make_waybar_json(weather_data))
        case _:
            print(weather_data)

    return 0


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
