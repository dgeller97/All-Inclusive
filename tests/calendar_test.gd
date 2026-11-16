extends SceneTree

const Calendar = preload("res://scripts/resort_calendar.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	var start := Calendar.state(1, 0)
	_check(start.month == 3 and start.month_name == "March" and start.year == 1, "starts in March, year 1")
	_check(start.day_in_month == 1 and start.time_label == "06:00", "opening dawn and compressed date")
	_check(Calendar.state(3, 0).month == 3 and Calendar.state(4, 0).month == 4, "three days per month")
	_check(Calendar.state(31, 0).month == 1 and Calendar.state(31, 0).year == 2, "December to January rollover")
	_check(Calendar.state(37, 0).month == 3 and Calendar.state(37, 0).year == 2, "full year wraps")
	_check(Calendar.state(1, 60).time_label == "12:00", "noon label")
	_check(Calendar.state(1, 180).time_label == "00:00", "midnight label")
	_check(Calendar.state(1, 60).daylight == 1.0, "full daylight at noon")
	_check(Calendar.state(1, 180).daylight == 0.0, "night at midnight")
	_check(Calendar.state(1, 0).daylight > 0.0 and Calendar.state(1, 0).daylight < 1.0, "dawn transition")
	_check(Calendar.state(1, 120).daylight > 0.0 and Calendar.state(1, 120).daylight < 1.0, "dusk transition")
	_check(is_equal_approx(Calendar.state(1, 240).hour, Calendar.state(2, 0).hour), "day boundary continuous")
	_check(Calendar.state(1, 80).temperature_c > Calendar.state(1, 180).temperature_c, "warm afternoon and cooler night")
	_check(Calendar.state(13, 60).temperature_c > Calendar.state(31, 60).temperature_c, "summer warmer than winter")
	_check(Calendar.state(13, 0).sargassum_pressure > Calendar.state(1, 0).sargassum_pressure, "summer arrival peak")
	_check(Calendar.state(25, 0).sargassum_pressure == 0.0, "November low season")
	_check(Calendar.state(0, -1) == start, "invalid early input safely clamped")
	_check(Calendar.state(1, 999).hour == Calendar.state(1, 240).hour, "late second safely clamped")
	for day in range(1, 73):
		for second in range(241):
			var current := Calendar.state(day, second)
			_check(current.month >= 1 and current.month <= 12 and current.day_in_month in [1, 2, 3], "valid date")
			_check(current.hour >= 0.0 and current.hour < 24.0, "valid time")
			_check(current.daylight >= 0.0 and current.daylight <= 1.0, "bounded light")
			_check(current.temperature_c >= 22.0 and current.temperature_c <= 31.0, "bounded climate")
			_check(current.sargassum_pressure >= 0.0 and current.sargassum_pressure <= 1.0, "bounded arrivals")
			_check(current == Calendar.state(day, second), "same saved time has identical calendar")
	print("Calendar: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
