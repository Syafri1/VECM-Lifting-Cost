# Macroeconomic Stress-Testing pada Lifting Cost Hulu Migas (VECM) — Studi Simulasi

Repositori ini mendemonstrasikan alur kerja ekonometrika *time-series* (uji akar unit, kointegrasi Johansen, VECM, IRF dengan *bootstrap*, dan FEVD) untuk menerjemahkan guncangan makroekonomi Indonesia menjadi dampak pada biaya produksi hulu migas.

> **Penting: variabel biaya dalam proyek ini adalah data sintetis (simulasi), bukan data perusahaan.**
> `Lifting_Cost_USD` dibangkitkan oleh skrip dengan rumus yang ditetapkan penulis (lihat bagian 2).
> Karena itu hasil di bawah **bukan temuan empiris tentang industri migas atau perusahaan tertentu**. Proyek ini menunjukkan *bagaimana metodologinya bekerja* dan *bagaimana membacanya dengan benar*.

---

## 1. Tujuan

1. Menunjukkan pipeline VECM yang lengkap dan dapat direplikasi di R.
2. Menunjukkan cara menerjemahkan guncangan makro (kurs, suku bunga, inflasi bahan, harga minyak) menjadi dampak pada biaya, **bila struktur biaya diasumsikan diketahui**.
3. Mengilustrasikan jebakan interpretasi IRF dan FEVD, khususnya ketergantungan pada urutan variabel (Cholesky).

## 2. Data

Periode: bulanan, **Januari 2015 – Desember 2025** (132 observasi, tanpa nilai hilang).

| Variabel | Deskripsi | Status | Sumber |
|---|---|---|---|
| `ICP` | Indonesian Crude Price (US$/barel) | Data riil | Investing.com |
| `Kurs` | Nilai tukar USD/IDR (Rp) | Data riil | Investing.com |
| `IHPB` | Indeks Harga Perdagangan Besar (proksi inflasi bahan) | Data riil | Badan Pusat Statistik |
| `BI Rate` | Suku bunga acuan BI (%) | Data riil | Bank Indonesia |
| `Lifting_Cost_USD` | Biaya produksi per barel | **Sintetis** | Dibangkitkan skrip |

**Rumus pembangkitan data sintetis** (`set.seed(42)`):

```
Lifting_Cost_USD = 8 + 0.05 × IHPB + 0.0003 × Kurs + 0.2 × BI Rate + ε,   ε ~ N(0, 0.15²)
```

Dua konsekuensi dari rumus ini yang menentukan cara membaca hasil:

- **`ICP` tidak ada dalam rumus.** Pengaruh struktural harga minyak terhadap biaya sama dengan nol.
- **Tidak ada dinamika dalam rumus.** Biaya adalah fungsi *kontemporer* dari kurs, IHPB, dan BI Rate. Setiap pola "efek tertunda" atau "memudar" pada IRF berasal dari dinamika variabel makro itu sendiri, bukan dari perilaku manajemen atau perusahaan.

## 3. Metodologi

| Tahap | Spesifikasi |
|---|---|
| Pemilihan lag | `VARselect`, maksimum 8 lag, kriteria AIC, komponen konstanta. **AIC memilih 1 lag**, sehingga dipakai `K = 2` (minimum untuk VECM) |
| Uji akar unit | ADF (`type = "trend"`, 1 lag) pada tiap variabel, hanya pada level. Hasil di bagian 3.1 |
| Kointegrasi | Johansen *trace test*, `ecdet = "const"` (konstanta terbatas, tanpa tren), `K = 2`. Hasil di bagian 3.2 |
| Rank kointegrasi | `r = 4` pada `vec2var`, berdasarkan uji sekuensial pada tingkat 5%. Dukungan untuk vektor ke-4 lemah (lihat 3.2) |
| IRF | Ortogonal (Cholesky), 24 bulan, *bootstrap* 95% |
| **Urutan Cholesky** | **ICP → Kurs → IHPB → BI Rate → Lifting Cost** |
| FEVD | Horizon 24 bulan |

Satuan IRF adalah dolar AS per barel untuk **satu simpangan baku** inovasi (ortogonal), bukan untuk guncangan yang ditentukan sendiri.

### 3.1 Uji akar unit (ADF, dengan konstanta dan tren, 1 lag)

Nilai kritis τ3: −3,99 (1%), −3,43 (5%), −3,13 (10%).

| Variabel | Statistik τ3 | Kesimpulan |
|---|---:|---|
| ICP | −2,61 | Tidak menolak akar unit |
| Kurs | **−4,20** | **Menolak akar unit pada 1%**, yaitu stasioner di sekitar tren |
| IHPB | −3,09 | Tidak menolak akar unit (juga pada 10%) |
| BI Rate | −1,84 | Tidak menolak akar unit |
| Lifting Cost (sintetis) | −2,75 | Tidak menolak akar unit |

Empat dari lima variabel tampak memiliki akar unit, sedangkan **kurs stasioner di sekitar tren**. Uji pada diferensi pertama belum dilakukan.

### 3.2 Uji kointegrasi Johansen (*trace*, `K = 2`)

| Hipotesis | Statistik uji | Nilai kritis 5% | Nilai kritis 1% | Keputusan 5% | Keputusan 1% |
|---|---:|---:|---:|---|---|
| r = 0 | 146,42 | 76,07 | 84,45 | Tolak | Tolak |
| r ≤ 1 | 85,44 | 53,12 | 60,16 | Tolak | Tolak |
| r ≤ 2 | 50,73 | 34,91 | 41,07 | Tolak | Tolak |
| r ≤ 3 | 21,86 | 19,96 | 24,60 | Tolak | **Tidak tolak** |
| r ≤ 4 | 5,81 | 9,24 | 12,97 | Tidak tolak | Tidak tolak |

Uji sekuensial memilih **r = 4 pada tingkat 5% dan 10%**, tetapi **r = 3 pada tingkat 1%**. Jadi vektor kointegrasi ke-4 hanya didukung secara marginal, bukan "bukti kuat". Rank setinggi ini dari lima variabel juga perlu dibaca hati-hati karena dua alasan:

- **Kurs stasioner di sekitar tren** (bagian 3.1). Variabel seperti ini cenderung menambah rank hasil uji Johansen.
- **Spesifikasi deterministik.** IHPB, kurs, dan biaya jelas bertren, sedangkan `ecdet = "const"` hanya mengizinkan konstanta dalam relasi kointegrasi. Kekeliruan spesifikasi seperti ini dapat membuat rank tampak terlalu tinggi.

Ini menjelaskan mengapa respons kurs pada IRF bersifat sementara (kurs stasioner, sehingga guncangannya memudar), sedangkan respons IHPB dan BI Rate bertahan (keduanya memiliki akar unit).

## 4. Hasil dan Cara Membacanya
Macroeconomic Stress-Testing (IRF).png
![Plot dinamika variabel](Plot%20Dinamika%20Makroekonomi%20%26%20Lifting%20Cost.png)

![IRF](Macroeconomic%20Stress-Testing%20(IRF).png)

Angka di bawah dibaca dari grafik.

| Guncangan | Yang tampak pada IRF | Cara membacanya |
|---|---|---|
| **Kurs melemah** | Respons awal ±0,11 US$/barel, menurun cepat. Interval kepercayaan mencakup nol sekitar bulan ke-4 hingga ke-5 | Sesuai rumus data (koefisien kurs positif). Pudarnya efek mencerminkan **kembalinya kurs ke keseimbangan dalam model VAR** (konsisten dengan uji ADF: kurs stasioner di sekitar tren), bukan penyesuaian kontrak atau manajemen |
| **BI Rate naik** | Respons positif ±0,03 naik ke ±0,07. **Batas bawah interval tetap di atas nol selama 25 bulan** | Efek signifikan sepanjang horizon, bukan hanya 1–3 bulan |
| **IHPB naik** | Respons menetap ±0,035 mulai bulan ke-3, signifikan sekitar bulan ke-3 hingga ke-20 | Sesuai rumus data. Sifat "permanen" berasal dari persistensi IHPB. Asimetri (*sticky downward*) tidak bisa disimpulkan dari model linear |
| **ICP naik** | Respons naik hingga ±0,12 pada bulan ke-25, signifikan mulai sekitar bulan ke-5 | **Bukan efek struktural.** ICP tidak ada dalam rumus data. Respons ini kemungkinan besar muncul lewat korelasi ICP dengan variabel lain dan urutan Cholesky (ICP ditempatkan pertama) |

![FEVD](Forecast%20Error%20Variance%20Decomposition%20(FEVD)%20-%20Lifting%20Cost.png

**FEVD biaya produksi** (dibaca dari grafik): pada bulan pertama sebagian besar variasi berasal dari guncangan biaya itu sendiri (±62%) dan kurs (±34%). Pada horizon 24 bulan, **ICP tampak menjelaskan sekitar separuh variasi**. Karena ICP tidak ada dalam rumus data, angka ini adalah **artefak urutan Cholesky dan persistensi data**, bukan pengaruh nyata. Gunakan FEVD hanya setelah menguji sensitivitas terhadap urutan variabel.

## 5. Skenario Ilustratif

Dengan struktur biaya sintetis di atas, dampak langsung guncangan berskala tertentu dapat dihitung sebagai **asumsi × besar guncangan**. Tabel ini menunjukkan format stress test, bukan estimasi empiris.

| Skenario | Besar guncangan (basis Des 2025) | Dampak langsung ke biaya |
|---|---|---|
| Rupiah melemah 10% | Rp16.675 → ±Rp18.340 (+Rp1.668) | ± +US$0,50 per barel |
| BI Rate naik 100 bps | 4,75% → 5,75% | + US$0,20 per barel |
| IHPB naik 5% | 106,3 → ±111,6 (+5,3 poin) | ± +US$0,27 per barel |

Dampak ini langsung dan bersifat tetap selama kurs, suku bunga, atau IHPB bertahan di level baru. IRF menunjukkan bagaimana guncangan ini menjalar dan meluruh seiring waktu menurut dinamika historis variabel makro.

## 6. Keterbatasan

- **Variabel dependen sintetis.** Hasil IRF dan FEVD pada dasarnya mengembalikan asumsi penulis dikalikan dinamika data makro.
- **Hasil bergantung pada urutan Cholesky.** Belum ada uji sensitivitas urutan.
- **Rank kointegrasi r = 4 dari 5 variabel hanya didukung marginal** (signifikan pada 5%, tidak pada 1%) dan mendekati rank penuh. Kurs stasioner di sekitar tren, dan `ecdet = "const"` tidak mengizinkan tren linear dalam relasi kointegrasi padahal IHPB dan kurs bertren. Hasil perlu diuji dengan spesifikasi alternatif (misalnya `ecdet = "trend"`, atau rank yang lebih kecil).
- **Sampel terbatas** (132 observasi) untuk sistem 5 variabel dengan beberapa lag.
- **Model linear:** tidak menangkap asimetri atau perubahan rezim.

## 7. Pengembangan Berikutnya

1. Ganti data sintetis dengan proksi biaya riil bila ada data publik yang sesuai.
2. Uji validasi: tunjukkan bahwa regresi atau VECM memulihkan koefisien 0,05, 0,0003, dan 0,2.
3. Bandingkan beberapa urutan Cholesky dan laporkan rentangnya, atau pakai pendekatan yang tidak bergantung urutan.
4. Tambahkan uji diagnostik (autokorelasi residual, normalitas, stabilitas) dan laporan lengkap uji ADF dan Johansen.
5. Perluas skenario dengan simulasi lintasan guncangan yang ditentukan penulis.

## 8. Struktur Repositori dan Cara Menjalankan

```
.
├── data/Data.xlsx                    # ICP, Kurs, IHPB, BI Rate (riil); biaya dibangkitkan skrip
├── scripts/stress_test_vecm.R
├── outputs/
│   ├── plot_dinamika_makro.png
│   ├── irf_dashboard.png
│   └── fevd_dashboard.png
├── LICENSE
└── README.md
```

1. Buka `scripts/stress_test_vecm.R` di RStudio dan atur *working directory* ke folder utama.
2. Pasang paket: `readxl`, `urca`, `vars`, `tseries`, `ggplot2`, `patchwork`. [ISI: versi R]
3. Jalankan skrip berurutan. Hasil IRF dan FEVD ditampilkan di panel Plot.

Catatan format data: kolom `ICP` di `Data.xlsx` tersimpan sebagai teks dengan koma desimal dan dibersihkan oleh skrip, sedangkan kolom lain memakai titik desimal.
