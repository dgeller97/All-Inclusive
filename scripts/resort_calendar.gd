extends RefCounted

## A compressed fictional Caribbean calendar, derived entirely from simulation time.
## Three operating days represent one month; no wall clock or random state is used.
const DAYS_PER_MONTH := 3
const DAY_LENGTH := 240
const START_MONTH := 3
const START_HOUR := 6.0
const MONTHS := ["January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December"]
# Designed seasonal temperatures, not a station forecast or measured climatology.
const MEAN_TEMPERATURES := [24.0, 24.5, 25.5, 27.0, 28.0, 28.5,
	29.0, 29.0, 28.5, 27.5, 26.0, 24.5]
# Broad spring-to-autumn arrivals, with a summer peak; actual shore conditions vary.
const SARGASSUM_PRESSURE := [0.0, 0.0, 0.25, 0.45, 0.7, 0.9,
	1.0, 0.85, 0.6, 0.3, 0.0, 0.0]


static func state(day: int, second: int) -> Dictionary:
	var elapsed_days := maxi(day - 1, 0)
	var month_index := START_MONTH - 1 + floori(float(elapsed_days) / DAYS_PER_MONTH)
	var month := month_index % 12 + 1
	var progress := clampf(float(second) / DAY_LENGTH, 0.0, 1.0)
	var hour := fposmod(START_HOUR + progress * 24.0, 24.0)
	var daylight := smoothstep(5.5, 7.5, hour) * (1.0 - smoothstep(17.5, 19.5, hour))
	var temperature: float = MEAN_TEMPERATURES[month - 1] + 2.0 * cos((hour - 14.0) * TAU / 24.0)
	var pressure: float = SARGASSUM_PRESSURE[month - 1]
	return {
		"year": 1 + floori(float(month_index) / 12.0),
		"month": month,
		"month_name": MONTHS[month - 1],
		"day_in_month": elapsed_days % DAYS_PER_MONTH + 1,
		"days_per_month": DAYS_PER_MONTH,
		"hour": hour,
		"time_label": "%02d:%02d" % [floori(hour), floori(fposmod(hour * 60.0, 60.0) + 0.00001)],
		"temperature_c": temperature,
		"daylight": daylight,
		"sargassum_pressure": pressure,
		"season": "Sargassum season" if pressure > 0.0 else "Low sargassum season",
	}
