# ==============================================================================
# PROYEK: MACROECONOMIC STRESS-TESTING & LIFTING COST FORECASTING
# ==============================================================================
# Memuat library
library(readxl)
library(urca)
library(vars)
library(tseries)
library(ggplot2)
library(patchwork)

# Membaca dataset
data <- read_excel("Data.xlsx")

# Membersihkan data ICP (mengubah koma menjadi titik agar terbaca sebagai numerik)
data$ICP <- as.numeric(gsub(",", ".", data$ICP))

# Membangkitkan variabel Lifting Cost (Skenario Bisnis Sintetis karena 
                                        #tidak memiliki data Lifting Cost Perusahaan)
set.seed(42) 
#noise <- rnorm(nrow(data), mean = 0, sd = 0.5) 
noise <- rnorm(nrow(data), mean = 0, sd = 0.15) # Mengurangi sedikit noise pada data sintetis
data$Lifting_Cost_USD <- 8 + (data$IHPB * 0.05) + (data$Kurs * 0.0003) + (data$`BI Rate` * 0.2) + noise

# Mengonversi dataframe menjadi objek Time-Series (ts)
ts_data <- ts(data[, c("ICP", "Kurs", "IHPB", "BI Rate", "Lifting_Cost_USD")], 
              start = c(2015, 1), frequency = 12)

# Menampilkan plot pergerakan awal
plot(ts_data, main = "Dinamika Makroekonomi & Lifting Cost (2015-2025)", col = "darkblue")

# Mencari lag optimum berdasarkan kriteria AIC
lag_selection <- VARselect(ts_data, lag.max = 8, type = "const")
optimal_lag <- lag_selection$selection["AIC(n)"]
print(paste("Lag Optimum AIC:", optimal_lag))

# Uji Stasioneritas ADF
adf_lifting <- ur.df(ts_data[, "Lifting_Cost_USD"], type = "trend", lags = optimal_lag)
print("=== Hasil Uji Stasioneritas ADF (Lifting Cost) ===")
summary(adf_lifting)
adf_ICP <- ur.df(ts_data[, "ICP"], type = "trend", lags = optimal_lag)
print("=== Hasil Uji Stasioneritas ADF (ICP) ===")
summary(adf_ICP)
adf_IHPB <- ur.df(ts_data[, "IHPB"], type = "trend", lags = optimal_lag)
print("=== Hasil Uji Stasioneritas ADF (IHPB) ===")
summary(adf_IHPB)
adf_Kurs <- ur.df(ts_data[, "Kurs"], type = "trend", lags = optimal_lag)
print("=== Hasil Uji Stasioneritas ADF (Kurs) ===")
summary(adf_Kurs)
adf_BI.Rate <- ur.df(ts_data[, "BI Rate"], type = "trend", lags = optimal_lag)
print("=== Hasil Uji Stasioneritas ADF (BI Rate) ===")
summary(adf_BI.Rate)

# Uji Kointegrasi Johansen
# Memastikan lag minimal 2 untuk membentuk VECM
k_johansen <- max(2, optimal_lag)

johansen_test <- ca.jo(ts_data, type = "trace", ecdet = "const", K = k_johansen)
summary(johansen_test)

# Mengonversi VECM menjadi representasi VAR dengan 4 vektor kointegrasi
model_final <- vec2var(johansen_test, r = 4)

## Impulse Response Function (IRF)
# 1. Skenario: Respon Lifting Cost terhadap Depresiasi Rupiah (Kurs melemah)
irf_kurs <- irf(model_final, impulse = "Kurs", response = "Lifting_Cost_USD", 
                n.ahead = 24, boot = TRUE)
plot(irf_kurs, main = "Respon Lifting Cost terhadap Depresiasi Rupiah",
     ylab = "Deviasi Lifting Cost (USD)", xlab = "Bulan ke-")

# 2. Skenario: Respon Lifting Cost terhadap Guncangan Inflasi Material (IHPB)
irf_ihpb <- irf(model_final, impulse = "IHPB", response = "Lifting_Cost_USD", 
                n.ahead = 24, boot = TRUE)
plot(irf_ihpb, main = "Respon Lifting Cost terhadap Lonjakan Inflasi B2B",
     ylab = "Deviasi Lifting Cost (USD)", xlab = "Bulan ke-")
# 3. Skenario: Respon Lifting Cost terhadap Guncangan Suku Bunga (BI Rate)
irf_birate <- irf(model_final, impulse = "BI.Rate", response = "Lifting_Cost_USD", 
                  n.ahead = 24, boot = TRUE)
plot(irf_birate, main = "Respon Lifting Cost thd Pengetatan Moneter (BI Rate)",
     ylab = "Deviasi Lifting Cost (USD)", xlab = "Bulan ke-")

# 4. Skenario: Respon Lifting Cost terhadap Guncangan Harga Minyak (ICP)
irf_icp_baru <- irf(model_final, impulse = "ICP", response = "Lifting_Cost_USD", 
                    n.ahead = 24, boot = TRUE)
plot(irf_icp_baru, main = "Respon Lifting Cost thd Siklus Harga Minyak (ICP)",
     ylab = "Deviasi Lifting Cost (USD)", xlab = "Bulan ke-")

##EKSTRAKSI & PLOTTING IRF KE GGPLOT2
# Membuat fungsi agar tidak perlu menulis kode berulang untuk tiap variabel
plot_irf_ggplot <- function(irf_object, impulse_name, title_text) {
  
  # Mengekstrak nilai tengah, batas bawah, dan batas atas dari objek IRF
  estimasi <- irf_object$irf[[impulse_name]][, "Lifting_Cost_USD"]
  bawah <- irf_object$Lower[[impulse_name]][, "Lifting_Cost_USD"]
  atas <- irf_object$Upper[[impulse_name]][, "Lifting_Cost_USD"]
  
  # Menyusunnya menjadi data frame
  df_irf <- data.frame(
    Bulan = 1:length(estimasi),
    Estimasi = estimasi,
    Batas_Bawah = bawah,
    Batas_Atas = atas
  )
  
  # Membangun grafik ggplot2
  g <- ggplot(df_irf, aes(x = Bulan, y = Estimasi)) +
    # Area arsir untuk Confidence Interval 95% (menggantikan garis putus-putus merah)
    geom_ribbon(aes(ymin = Batas_Bawah, ymax = Batas_Atas), fill = "steelblue", alpha = 0.2) +
    # Garis keseimbangan nol (Baseline)
    geom_hline(yintercept = 0, color = "red", linetype = "dashed", linewidth = 0.7) +
    # Garis utama respon (Impulse)
    geom_line(color = "midnightblue", linewidth = 1) +
    labs(title = title_text,
         x = "Periode (Bulan)",
         y = "Deviasi (USD)") +
    theme_minimal() +
    theme(plot.title = element_text(face = "bold", size = 11),
          axis.title = element_text(size = 9),
          panel.grid.minor = element_blank())
  
  return(g)
}

## EKSEKUSI VISUALISASI UNTUK KEEMPAT SKENARIO
g_kurs   <- plot_irf_ggplot(irf_kurs, "Kurs", "Respon thd Depresiasi Rupiah")
g_ihpb   <- plot_irf_ggplot(irf_ihpb, "IHPB", "Respon thd Inflasi B2B")
g_birate <- plot_irf_ggplot(irf_birate, "BI.Rate", "Respon thd Pengetatan Moneter")
g_icp    <- plot_irf_ggplot(irf_icp_baru, "ICP", "Respon thd Siklus Harga Minyak")

## PENGGABUNGAN GRAFIK (DASHBOARD LAYOUT)
# Menggunakan patchwork untuk layout 2x2
dashboard_irf <- (g_kurs | g_ihpb) / (g_birate | g_icp) +
  plot_annotation(
    title = "Macroeconomic Stress-Testing: Sensitivitas Lifting Cost PHR",
    subtitle = "Impulse Response Function (IRF) dengan 95% Bootstrap Confidence Interval",
    theme = theme(plot.title = element_text(face = "bold", size = 16, hjust = 0.5),
                  plot.subtitle = element_text(size = 12, hjust = 0.5, color = "darkgray"))
  )

# Menampilkan hasil akhir
print(dashboard_irf)

##FORECAST ERROR VARIANCE DECOMPOSITION (FEVD) & VISUALISASI
# Menghitung Dekomposisi Varians
vd_lifting <- fevd(model_final, n.ahead = 24)

# Persiapan palet warna dan nama variabel
warna <- c("#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "#FF7F00")
nama_variabel <- names(vd_lifting)

# Layout 3x2 (5 panel grafik + 1 panel legenda)
par(mfrow = c(3, 2), mar = c(3, 4, 3, 1), oma = c(0, 0, 3, 0))

# Looping plot diagram batang FEVD
for (var in nama_variabel) {
  matriks <- t(vd_lifting[[var]])
  barplot(matriks, main = paste("FEVD:", var), ylab = "Proporsi", col = warna,
          border = "white", lwd = 0.5, las = 1) 
}

# Pembuatan panel khusus Legenda
par(mar = c(0, 0, 0, 0)) # Hapus margin agar teks tidak terpotong
plot.new()
legend("center", legend = rownames(t(vd_lifting[[1]])), fill = warna, 
       bty = "n", cex = 1.1, title = "Keterangan Warna (Sumber Guncangan):")
mtext("Forecast Error Variance Decomposition (FEVD) Keseluruhan Variabel", outer = TRUE, font = 2, cex = 1.2, col = "black")

# Kembalikan ke layout normal
par(mfrow = c(1, 1), mar = c(5, 4, 4, 2) + 0.1, oma = c(0, 0, 0, 0))
