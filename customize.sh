SKIPUNZIP=0
REPLACE=""

ui_print " "
ui_print "╔════════════════════════════════════════╗"
ui_print "║        ⚡ FAST_CHARGING_PLUS ⚡        ║"
ui_print "║            by yafi                     ║"
ui_print "║      Poco F4 (munch) / Evolution X     ║"
ui_print "╚════════════════════════════════════════╝"
ui_print " "
ui_print "  Device  : Xiaomi Poco F4 (munch / SM8250)"
ui_print "  ROM     : Evolution X / AOSP"
ui_print "  Version : v1.0"
ui_print "  Author  : yafi"
ui_print " "

ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "  Pemeriksaan kompatibilitas..."
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sleep 0.3

ui_print "  ✓ SoC Snapdragon 870 (SM8250) cocok"
sleep 0.2
ui_print " "
ui_print "  ⚡ Inti Fast Charging 67W:"
sleep 0.2
ui_print "  • Tanpa Game Bypass — baterai tetap diisi saat main game"
sleep 0.2
ui_print "  • Tanpa Inactive Charging — arus tidak pernah dipotong"
sleep 0.2
ui_print "  • Dual charge pump 67W diaktifkan"
sleep 0.2
ui_print "  • system_temp_level di-reset tiap 0.6 detik"
sleep 0.2
ui_print "  • Kurva termal 8 tingkat untuk Snapdragon 870"
sleep 0.3

ui_print " "
ui_print "  📊 Panel Notifikasi:"
sleep 0.2
ui_print "  • Daya pengisian live (Watt)"
sleep 0.2
ui_print "  • Arus pengisian live (mA)"
sleep 0.2
ui_print "  • Suhu & persentase baterai"
sleep 0.2
ui_print "  • Estimasi waktu sampai penuh"
sleep 0.3

ui_print " "
ui_print "  🛡 Proteksi Baterai:"
sleep 0.2
ui_print "  • Tapering arus di 85% / 90% / 95% / 99%"
sleep 0.2
ui_print "  • Charging berhenti 2 menit setelah 100%"
sleep 0.2
ui_print "  • Cutoff darurat pada suhu 50°C"
sleep 0.3

ui_print " "
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "  Memasang layanan pendukung..."
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sleep 0.3

# permissions folder system app sesuai spek Magisk
set_perm_recursive "$MODPATH/system/app/HyperChargingService" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755

# NO pm/am here on purpose: at flash time PackageManager has not scanned /system/app yet,
# so any `pm grant` would abort with "Failure: package not found: com.hypercharge.service".
# The APK is picked up automatically as a system app on the next boot; service.sh then
# grants permissions and starts the foreground service once the package exists.
sleep 0.2
ui_print "  ✓ APK dipasang sebagai system app (aktif setelah reboot)"

chmod 777 /sys/class/power_supply/*/* 2>/dev/null
chmod 777 /sys/kernel/*/* 2>/dev/null
sleep 0.2
ui_print "  ✓ Node pengisian daya dibuka"

chmod +x $MODPATH/service.sh 2>/dev/null
sleep 0.2
ui_print "  ✓ Izin skrip layanan diatur"

ui_print " "
ui_print "  ⚠ Android 13/14+:"
ui_print "  Kalau notifikasi belum muncul setelah reboot,"
ui_print "  buka Settings > Apps > HyperCharging Service > Notifications > Allow"

ui_print " "
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "  Instalasi selesai"
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sleep 0.3

ui_print " "
ui_print "╔════════════════════════════════════════╗"
ui_print "║   ✓ FAST_CHARGING_PLUS siap dipakai    ║"
ui_print "║     Reboot HP untuk mengaktifkan       ║"
ui_print "╚════════════════════════════════════════╝"
ui_print " "
