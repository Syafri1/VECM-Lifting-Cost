# Macroeconomic Stress-Testing pada Lifting Cost Hulu Migas (VECM)

Repositori ini berisi pemodelan ekonometrika time-series untuk menganalisis sensitivitas biaya operasional hulu migas (*Lifting Cost*) terhadap guncangan makroekonomi domestik dan global. Pemodelan dieksekusi menggunakan R dengan pendekatan *Vector Error Correction Model* (VECM).

## Konteks Proyek
Dalam industri padat modal seperti hulu migas, fluktuasi makroekonomi seringkali memiliki efek tertunda (*lagged effect*) pada struktur biaya. Proyek ini bertujuan memetakan seberapa cepat dan seberapa lama guncangan makro mentransmisikan risikonya ke biaya operasional perusahaan.

Variabel yang dianalisis (Frekuensi Bulanan, 2015-2025):
*   `Lifting_Cost_USD`: Biaya produksi per barel (Simulasi/Data Sintetis)
*   `Kurs`: Nilai tukar USD/IDR
*   `ICP`: Indonesian Crude Price 
*   `IHPB`: Indeks Harga Perdagangan Besar (Proksi inflasi material B2B)
*   `BI.Rate`: Suku Bunga Acuan Bank Indonesia

## Tinjauan Data Historis (2015-2025)
![Dinamika Data Mentah](Plot%20Dinamika%20Makroekonomi%20&%20Lifting%20Cost.png)
*Grafik di atas menunjukkan pergerakan historis variabel makroekonomi utama beserta Lifting Cost sintetis sebelum dilakukan transformasi dan pemodelan VECM.*

## Metodologi
Pipeline analisis dalam *script* ini mencakup:
1. Penentuan Lag Optimum (AIC)
2. Uji Stasioneritas (Augmented Dickey-Fuller)
3. Uji Kointegrasi Johansen (Ditemukan bukti kuat adanya 4 vektor kointegrasi, sehingga VECM sah digunakan)
4. Ekstraksi *Impulse Response Function* (IRF) dengan 95% Bootstrap CI menggunakan layout manual dan `ggplot2`.
5. *Forecast Error Variance Decomposition* (FEVD) menggunakan pendekatan *stacked bar chart*.

## Temuan Utama

**1. Dinamika Guncangan (Impulse Response)**
Berdasarkan visualisasi IRF, respons *Lifting Cost* menunjukkan pola struktural yang jelas terhadap masing-masing guncangan:
*   **Kurs & Suku Bunga:** Depresiasi Rupiah dan pengetatan BI Rate berdampak signifikan menaikkan *lifting cost* pada 1-3 bulan pertama. Memasuki bulan ke-4, efeknya mulai tidak signifikan secara statistik, mengindikasikan adanya kemampuan sistem (atau manajemen) untuk melakukan penyesuaian (misal: negosiasi ulang kontrak) dalam jangka menengah.
*   **Inflasi Material (IHPB):** Guncangan inflasi menggeser batas ekuilibrium biaya secara permanen ke atas. Ini merefleksikan karakter *sticky downward* pada harga material (seperti bahan kimia atau pipa) yang sulit turun kembali setelah naik.
*   **Siklus Harga Minyak (ICP):** Siklus *bullish* harga minyak memicu *oilfield service inflation*. Kenaikan harga minyak secara konsisten merambat pada naiknya tarif jasa penunjang operasional di lapangan.

**2. Peta Risiko Jangka Panjang (FEVD)**
Dekomposisi varians menunjukkan bahwa dalam horizon 12 hingga 24 bulan, volatilitas *Lifting Cost* didominasi oleh tumpukan guncangan makroekonomi eksternal, yang perlahan menggerus porsi guncangan internal (*own-shock*).

## Kesimpulan Bisnis
Hasil model ini menyoroti perlunya instrumen *hedging* valas yang agresif khusus untuk tenor pendek (1-3 bulan) untuk meredam guncangan instan. Selain itu, strategi penguncian harga jangka panjang (*multi-years contract*) sangat disarankan untuk pengadaan material sebelum siklus harga minyak dunia mencapai puncaknya.

## Cara Penggunaan Script
1. Buka `Macroeconomic_Stress_Testing.R` di RStudio.
2. Pastikan package `vars`, `urca`, `ggplot2`, dan `patchwork` terinstal.
3. Tempatkan `Data.xlsx` di direktori kerja yang sama.
4. Jalankan script secara berurutan. Hasil plot akan diekstrak secara otomatis di panel Viewer/Plot.
