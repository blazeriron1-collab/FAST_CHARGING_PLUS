# FAST_CHARGING_PLUS - Changelog

## v1.0 (Initial Release oleh yafi)
- **Rebranding Penuh**: Modul resmi diberi nama `FAST_CHARGING_PLUS` oleh **yafi**.
- **Hapus Fitur Game Bypass & Inactive Charging**:
  - Dihapus seluruh deteksi polling game, package monitor, dan manipulasi flag bypass charging.
  - Saat bermain game HP tetap melakukan fast charging normal tanpa terputus atau mode inactive.
- **Optimasi Fast Charging 67W Poco F4 (munch / SM8250)**:
  - Reset agresif `system_temp_level` setiap interval 0.6s untuk mencegah thermal step-down prematur.
  - Thermal tier unthrottled: 6.0A (tier 0) -> 5.5A (tier 1) -> 4.5A (tier 2) -> 3.5A (tier 3) -> 2.5A (tier 4).
  - Screen-on throttle bypass: arus tetap maksimal saat layar menyala.
  - Driver pump dual SMB1396 / BQ2597X / SC8551 dipertahankan dalam mode parallel charging.
- **Banner Notifikasi Live Watt**:
  - Banner APK dimodifikasi total (`HyperChargeService.apk`).
  - Judul: `FAST CHARGING+⚡`.
  - Body menampilkan live Watt real-time: `Fast Charging Active (XX.X W)` dan `⚡ XXXXmA (XX.X W)`.
  - Icon notifikasi diganti menjadi dual-bolt neon modern.
  - Logo APK (`ic_launcher.png`) dan banner Magisk (`banner.png`) diganti dengan desain eksklusif baru.
