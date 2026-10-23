#!/usr/bin/env bash

# Waybar custom module for Home Assistant.
#
# Credentials are read from ~/.config/hass-waybar/env, which lives outside this
# repository on purpose (~/.config/waybar is a symlink into it):
#   HASS_URL=http://homeassistant.local:8123
#   HASS_TOKEN=<long-lived access token, non-admin is enough>
#
# /api/template is admin-only, so the states are fetched via /api/states/<id>
# in a single curl process (one keep-alive connection) and rendered with jq.

set -uo pipefail

readonly ENV_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/hass-waybar/env"

readonly ENTITIES=(
    sensor.esphome_web_757cb4_zimmer_temperatur
    sensor.esphome_web_757cb4_zimmer_luftfeuchte
    sensor.sensor_indoor_air_quality
    binary_sensor.fenster_nerdcave_contact
    climate.heizung_nerdcave_device
    climate.climate_scheduler_climate_schedule_nerdcave
    sensor.abend_uhr_restzeit
    sensor.bettzeit
    sensor.pc_power
    sensor.server_power
    light.nerdcave_licht
    weather.luedge
    counter.spezi_kiste
)

offline() {
    jq -cn --arg tooltip "$1" '{text: "󰟐 –", tooltip: $tooltip, class: "offline"}'
    exit 0
}

[[ -r "$ENV_FILE" ]] || offline "Home Assistant: $ENV_FILE missing"
# shellcheck source=/dev/null
source "$ENV_FILE"
[[ -n "${HASS_URL:-}" && -n "${HASS_TOKEN:-}" ]] || offline "Home Assistant: HASS_URL/HASS_TOKEN not set"

urls=()
for entity in "${ENTITIES[@]}"; do
    urls+=("$HASS_URL/api/states/$entity")
done

# The header is passed via a file descriptor so the token never shows up in ps.
# Missing entities return {"message": ...} and are simply skipped below.
response="$(
    curl -s --max-time 8 \
        -H @<(printf 'Authorization: Bearer %s\n' "$HASS_TOKEN") \
        "${urls[@]}"
)" || offline "Home Assistant unreachable ($HASS_URL)"

read -r -d '' RENDER <<'EOF'
def num($d): if (tostring | test("^-?[0-9]+(\\.[0-9]+)?$"))
    then (tonumber * pow(10; $d) | round) / pow(10; $d) else null end;
def show: if . == null then "–" else tostring end;

(map(select(.entity_id?)) | INDEX(.entity_id)) as $s
| def state($id): $s[$id].state // "unknown";
  def attr($id; $a): $s[$id].attributes[$a];

  (state("sensor.esphome_web_757cb4_zimmer_temperatur") | num(1)) as $t
| (state("sensor.esphome_web_757cb4_zimmer_luftfeuchte") | num(0)) as $h
| (state("sensor.sensor_indoor_air_quality") | num(0)) as $iaq
| (state("sensor.abend_uhr_restzeit") | num(0)) as $rest
| (state("binary_sensor.fenster_nerdcave_contact") == "on") as $window_open
| (attr("climate.heizung_nerdcave_device"; "hvac_action") == "heating") as $heating
| (try (state("sensor.bettzeit") | sub("\\+00:00$"; "Z") | fromdateiso8601
        | localtime | strftime("%H:%M")) catch "?") as $bedtime

| [ (if $t then "󰔏 \($t)°" else empty end),
    (if $h then "󰖎 \($h)%" else empty end),
    (if $window_open then "󰖶" else empty end),
    (if $heating then "󰈸" else empty end),
    (if $iaq and $iaq > 175 then "󰌪 \($iaq)" else empty end),
    (if $rest and $rest <= 60 then "󰒲 \($rest)m" else empty end)
  ] as $text

| [ (if $window_open then "window-open" else empty end),
    (if $heating then "heating" else empty end),
    (if $iaq and $iaq > 175 then "bad-air" else empty end),
    (if $rest and $rest <= 60 then
        (if $rest < 0 then "bedtime-overdue" else "bedtime" end) else empty end)
  ] as $class

| { text: (if $text == [] then "󰟐 ?" else $text | join("    ") end),
    tooltip: [
      "Nerdcave: \($t | show) °C, \($h | show) %",
      "IAQ: \($iaq | show)",
      "Window: \(state("binary_sensor.fenster_nerdcave_contact") | sub("^off$"; "closed") | sub("^on$"; "open"))",
      "Heating: \(state("climate.heizung_nerdcave_device")) / \(attr("climate.heizung_nerdcave_device"; "hvac_action") | show), target \(attr("climate.climate_scheduler_climate_schedule_nerdcave"; "temperature") | num(1) | show) °C",
      "Light: \(state("light.nerdcave_licht"))",
      "Power: PC \(state("sensor.pc_power") | num(0) | show) W, Server \(state("sensor.server_power") | num(0) | show) W",
      "Bedtime: \($bedtime) (\($rest | show) min)",
      "Weather: \(state("weather.luedge")), \(attr("weather.luedge"; "temperature") | num(1) | show) °C",
      "Spezi: \(state("counter.spezi_kiste")) bottles"
    ] | join("\n"),
    class: $class }
EOF

# Validate before handing it to waybar; bad output must not break the bar.
jq -cs "$RENDER" <<<"$response" 2>/dev/null || offline "Home Assistant: unexpected API response"
