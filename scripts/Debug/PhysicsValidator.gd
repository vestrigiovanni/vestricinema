extends Node
## PhysicsValidator (Fase 11)
##
## Validazione fisica attivabile con F4 (solo in debug build). Genera un report in
## console che confronta i valori ATTESI (formula analitica / database) con quelli
## SIMULATI dalla pipeline, per i 3 oggetti hardcoded di test:
##
##   1. Trasmittanza del laptop da solo: marcia un raggio verticale attraverso il
##      volume voxelizzato (solo voxel "misto" = laptop) e confronta la
##      trasmittanza misurata con la Beer-Lambert analitica T = exp(-mu*rho*L).
##   2. z_eff stimato dalla decomposizione DECT vs z_eff dichiarato nel JSON.
##
## Errore percentuale per ciascun valore: deve stare sotto il 10% per passare.
## Logga [PhysicsValidator] PASS oppure [PhysicsValidator] FAIL — delta z_eff: X%.

const DectAnalysisOverlay := preload("res://scripts/UI/DectAnalysisOverlay.gd")

const TOLERANCE_PCT := 10.0

var _host  # VolumetricSetup


func setup(host) -> void:
	_host = host
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		run_report()


func run_report() -> void:
	print("[PhysicsValidator] ===== Report validazione fisica (Fase 11) =====")
	var all_ok := true
	var worst_zeff_delta := 0.0

	# --- 1) Beer-Lambert: laptop da solo --------------------------------------
	var laptop_ok := _validate_laptop_transmittance()
	all_ok = all_ok and laptop_ok

	# --- 2) DECT z_eff vs dichiarato per i 3 oggetti --------------------------
	var objs: Array = _host.get_test_objects()
	for item in objs:
		var declared := float(item.get("z_eff", 0.0))
		var mid: float = _host.material_id_for_item(item)
		var est := DectAnalysisOverlay.dect_zeff(mid)
		var delta := _pct_error(est, declared)
		worst_zeff_delta = maxf(worst_zeff_delta, delta)
		var ok := delta < TOLERANCE_PCT
		all_ok = all_ok and ok
		print("[PhysicsValidator]   %-16s z_eff dichiarato %.1f | DECT %.1f | delta %.1f%% -> %s" % [
			str(item.get("name", "?")), declared, est, delta, "OK" if ok else "FAIL"
		])

	# --- Verdetto -------------------------------------------------------------
	if all_ok:
		print("[PhysicsValidator] PASS")
	else:
		print("[PhysicsValidator] FAIL — delta z_eff: %.1f%%" % worst_zeff_delta)
	print("[PhysicsValidator] ================================================")


## Confronta la trasmittanza del laptop misurata sul volume con Beer-Lambert.
func _validate_laptop_transmittance() -> bool:
	var laptop: Dictionary = _host.get_laptop_item()
	if laptop.is_empty():
		print("[PhysicsValidator]   Laptop non trovato: salto la verifica Beer-Lambert.")
		return false

	var density := float(laptop.get("density", 0.0))
	var thickness := float(laptop["size"].y)          # spessore lungo Y (m, spazio volume)
	var mu: float = _host.get_absorption_scale()        # absorption_scale corrente

	# Analitica: tau = mu * rho * L  (Beer-Lambert discreta della pipeline).
	var tau_analytic := mu * density * thickness
	var t_analytic := exp(-tau_analytic)

	# Misurata: raggio verticale al centro del laptop, somma solo i voxel "misto".
	var center: Vector3 = laptop["position"]
	var tau_measured: float = _host.measure_column_tau(center.x, center.z, 0.5)  # mat_id 0.5 = misto
	var t_measured := exp(-tau_measured)

	var delta := _pct_error(t_measured, t_analytic)
	var ok := delta < TOLERANCE_PCT
	print("[PhysicsValidator]   Laptop Beer-Lambert  T analitica %.4f | T misurata %.4f | delta %.1f%% -> %s" % [
		t_analytic, t_measured, delta, "OK" if ok else "FAIL"
	])
	return ok


func _pct_error(measured: float, expected: float) -> float:
	if absf(expected) < 1e-6:
		return 0.0 if absf(measured) < 1e-6 else 100.0
	return absf(measured - expected) / absf(expected) * 100.0
