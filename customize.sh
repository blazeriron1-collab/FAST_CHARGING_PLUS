SKIPUNZIP=0
REPLACE=""

ui_print " "
ui_print "╔════════════════════════════════════════╗"
ui_print "║        ⚡ FAST_CHARGING_PLUS ⚡        ║"
ui_print "║            by yafi                     ║"
ui_print "║            Poco F4 (munch)             ║"
ui_print "╚════════════════════════════════════════╝"
ui_print " "
ui_print "  Device  : Xiaomi Poco F4 (munch / SM8250)"
ui_print "  ROM     : AOSP"
ui_print "  Version : v1.0"
ui_print "  Author  : yafi"
ui_print " "

ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "  Menyiapkan engine pengisian daya..."
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sleep 0.3

ui_print " "
ui_print "  ⚡ Inti Fast Charging 67W:"
sleep 0.2
ui_print "  • Tanpa Inactive Charging — arus tidak pernah dipotong"
sleep 0.2
ui_print "  • Screen-on current throttle dibuka"
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

APK_PATH="$MODPATH/system/app/HyperChargingService/HyperChargeService.apk"
pm install -r -t --dont-kill "$APK_PATH" >/dev/null 2>&1
pm install -r --user 0 -t --dont-kill "$APK_PATH" >/dev/null 2>&1
sleep 1

pm grant com.hypercharge.service android.permission.POST_NOTIFICATIONS 2>/dev/null
pm grant com.hypercharge.service android.permission.FOREGROUND_SERVICE 2>/dev/null
sleep 0.2
ui_print "  ✓ Izin notifikasi diberikan"

dumpsys deviceidle whitelist +com.hypercharge.service 2>/dev/null
sleep 0.2
ui_print "  ✓ Bebas dari optimasi baterai"

pm grant com.hypercharge.service android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS 2>/dev/null
sleep 0.2
ui_print "  ✓ Layanan latar belakang dilindungi"

am start-foreground-service --user 0 -n com.hypercharge.service/.ChargeNotificationService 2>/dev/null
sleep 0.2
ui_print "  ✓ Layanan notifikasi dijalankan"

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
