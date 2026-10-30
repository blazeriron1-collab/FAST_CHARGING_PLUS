# ⚡ FAST_CHARGING_PLUS

Modul Magisk / KernelSU / APatch untuk Xiaomi Poco F4 (munch / SM8250) pada ROM Evolution X / AOSP.

Dibuat oleh: **yafi**

---

## 🔋 Fitur Utama

- **Tanpa Game Bypass Mode**: Pengisian daya tetap berjalan penuh saat bermain game tanpa beralih ke bypass.
- **Tanpa Inactive Charging**: Masalah status charging "Inactive" dan drop arus saat bermain game dihapus total.
- **Optimasi Fast Charging 67W**:
  - Screen-on current throttle bypass: Arus tetap deras meskipun layar menyala.
  - Reset `system_temp_level=0` setiap 0.6 detik: Menghentikan pembatasan termal agresif dari thermal-engine kernel.
  - Pengaktifan Xiaomi Dual Charge Pump (`bq2597x`, `sc8551`, `ln8000`, `smb1396`).
  - Kurva tangga termal 8 tingkat yang disesuaikan khusus untuk Snapdragon 870 Poco F4.
- **Live Watt Indicator pada Notifikasi**:
  - Menampilkan daya pengisian real-time dalam satuan Watt (W).
  - Menampilkan arus pengisian real-time (mA).
  - Menampilkan suhu (°C), persentase baterai, dan estimasi waktu sampai penuh.
- **Proteksi Baterai**:
  - Tapering arus bertingkat pada kapasitas 85%, 90%, 95%, dan 99% agar sel baterai tetap awet.
  - Cutoff otomatis 2 menit setelah baterai mencapai 100%.
  - Cutoff darurat pada suhu kritis (50°C).

---

## 📦 Pemasangan

1. Flash zip modul lewat Magisk / KernelSU / APatch.
2. Reboot HP.
3. Notifikasi status pengisian daya akan muncul otomatis saat charger dicolokkan.

---

## 🧹 Penghapusan

Hapus modul lewat manajer root (Magisk / KernelSU / APatch) lalu reboot perangkat.
