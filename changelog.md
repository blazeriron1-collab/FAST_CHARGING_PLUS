# Changelog

## v2.0-yafi — FAST_CHARGING_PLUS (Poco F4 / Evolution X)
Modul buatan yafi untuk Poco F4 (munch / SM8250) Evolution X.

- **Game Bypass Mode & Inactive Charging Dihapus Total** — baterai tetap diisi daya saat main game, tanpa pemotongan arus, tanpa `dumpsys battery unplug`. Pengisian jalan terus.
- **Optimasi Fast Charging 67W**:
  - Screen-on current throttle bypass — layar nyala tetap ngebut.
  - Reset `system_temp_level=0` tiap 0.6s — throttling kernel dilapuk terus.
  - Dual charge pump 67W aktif (`bq2597x`, `sc8551`, `ln8000`, `smb1396`).
  - Tangga termal 8 tier khusus Snapdragon 870, peak 13.5A dual pump.
  - Tapering longgar di 85/90/95/99% supaya cepat penuh.
  - Cutoff otomatis 2 menit setelah 100%, cutoff darurat di 50°C.
- **Live Watt di Notifikasi**:
  - `service.sh` hitung daya real-time dari sysfs kernel: `(voltage_now * current_now) / 1e6` — tampil 1 desimal.
  - APK `HyperChargeService.apk` dipatch via smali (`classes3.dex`): parser intent `--es watt` ditambah di `CommandReceiver`, builder notifikasi di `ChargeNotificationService` menerima parameter Watt.
  - Judul notifikasi: `Fast Charging Active (XX.X W)`; subteks: `XXXX mA (XX.X W) | XX °C`.
  - APK disign ulang v1+v2+v3 testkey via `uber-apk-signer`.
- **Rebranding** — seluruh teks modul jadi versi yafi: nama modul `FAST_CHARGING_PLUS`, author `yafi`, notifikasi APK `FAST CHARGING+`, channel `FAST_CHARGING_PLUS`.
