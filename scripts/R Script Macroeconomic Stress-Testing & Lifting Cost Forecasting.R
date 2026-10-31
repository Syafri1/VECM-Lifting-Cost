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

# 2. Skenario: Respon Lifting Cost terhadap Guncangan Harga Perdagangan Besar (IHPB)
irf_ihpb <- irf(model_final, impulse = "IHPB", response = "Lifting_Cost_USD", 
                n.ahead = 24, boot = TRUE)
plot(irf_ihpb, main = "Respon Lifting Cost terhadap Lonjakan Harga Perdagangan Besar",
     ylab = "Deviasi Lifting Cost (USD)", xlab = "Bulan ke-")
# 3. Skenario: Respon Lifting Cost terhadap Guncangan Suku Bunga (BI Rate)
irf_birate <- irf(model_final, impulse = "BI.Rate", response = "Lifting_Cost_USD", 
                  n.ahead = 24, boot = TRUE)
plot(irf_birate, main = "Respon Lifting Cost terhadap Pengetatan Moneter Domestik (BI Rate)",
     ylab = "Deviasi Lifting Cost (USD)", xlab = "Bulan ke-")

# 4. Skenario: Respon Lifting Cost terhadap Guncangan Harga Minyak (ICP)
irf_icp_baru <- irf(model_final, impulse = "ICP", response = "Lifting_Cost_USD", 
                    n.ahead = 24, boot = TRUE)
plot(irf_icp_baru, main = "Respon Lifting Cost terhadap Siklus Harga Minyak (ICP)",
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
g_kurs   <- plot_irf_ggplot(irf_kurs, "Kurs", "Respon terhadap Depresiasi Rupiah")
g_ihpb   <- plot_irf_ggplot(irf_ihpb, "IHPB", "Respon terhadap Harga Perdagangan Besar")
g_birate <- plot_irf_ggplot(irf_birate, "BI.Rate", "Respon terhadap Pengetatan Moneter Domestik")
g_icp    <- plot_irf_ggplot(irf_icp_baru, "ICP", "Respon terhadap Siklus Harga Minyak")

## PENGGABUNGAN GRAFIK (DASHBOARD LAYOUT)
# Menggunakan patchwork untuk layout 2x2
dashboard_irf <- (g_kurs | g_ihpb) / (g_birate | g_icp) +
  plot_annotation(
    title = "Macroeconomic Stress-Testing: Sensitivitas Lifting Cost",
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



# ==============================================================================
# TAMBAHAN 1: EKSTRAKSI HASIL IRF DALAM BENTUK TABEL TEKS
# ==============================================================================

# Fungsi untuk mengekstrak hasil IRF
ekstrak_irf_teks <- function(irf_object, impulse_name, skenario) {
  
  estimasi <- irf_object$irf[[impulse_name]][, "Lifting_Cost_USD"]
  bawah <- irf_object$Lower[[impulse_name]][, "Lifting_Cost_USD"]
  atas <- irf_object$Upper[[impulse_name]][, "Lifting_Cost_USD"]
  
  hasil <- data.frame(
    Skenario = skenario,
    Periode = seq_along(estimasi) - 1,
    Estimasi_IRF = as.numeric(estimasi),
    Batas_Bawah_95 = as.numeric(bawah),
    Batas_Atas_95 = as.numeric(atas)
  )
  
  # Menentukan signifikansi berdasarkan confidence interval
  hasil$Signifikansi <- ifelse(
    hasil$Batas_Bawah_95 > 0 | hasil$Batas_Atas_95 < 0,
    "Signifikan",
    "Tidak Signifikan"
  )
  
  return(hasil)
}

# Mengekstrak keempat skenario IRF
hasil_irf_kurs <- ekstrak_irf_teks(
  irf_kurs, "Kurs", "Depresiasi Rupiah"
)

hasil_irf_ihpb <- ekstrak_irf_teks(
  irf_ihpb, "IHPB", "Indeks Harga Perdagangan Besar"
)

hasil_irf_birate <- ekstrak_irf_teks(
  irf_birate, "BI.Rate", "Pengetatan Moneter Domestik"
)

hasil_irf_icp <- ekstrak_irf_teks(
  irf_icp_baru, "ICP", "Guncangan Harga Minyak"
)

# Menggabungkan seluruh hasil IRF
tabel_irf <- rbind(
  hasil_irf_kurs,
  hasil_irf_ihpb,
  hasil_irf_birate,
  hasil_irf_icp
)

# Menampilkan hasil IRF secara keseluruhan
cat("\n")
cat("====================================================\n")
cat(" HASIL IMPULSE RESPONSE FUNCTION (IRF)\n")
cat("====================================================\n")

print(tabel_irf, row.names = FALSE, digits = 5)

# Menampilkan hasil setiap skenario secara terpisah
cat("\n=== IRF: DEPRESIASI RUPIAH ===\n")
print(hasil_irf_kurs, row.names = FALSE, digits = 5)

cat("\n=== IRF: INDEKS HARGA PERDAGANGAN BESAR ===\n")
print(hasil_irf_ihpb, row.names = FALSE, digits = 5)

cat("\n=== IRF: PENGETATAN MONETER ===\n")
print(hasil_irf_birate, row.names = FALSE, digits = 5)

cat("\n=== IRF: GUNCANGAN HARGA MINYAK ===\n")
print(hasil_irf_icp, row.names = FALSE, digits = 5)

# Menyimpan hasil IRF ke CSV
write.csv(
  tabel_irf,
  "Hasil_IRF_Lifting_Cost.csv",
  row.names = FALSE
)

cat("\nHasil IRF berhasil disimpan: Hasil_IRF_Lifting_Cost.csv\n")


# ==============================================================================
# TAMBAHAN 2: EKSTRAKSI HASIL FEVD DALAM BENTUK TABEL TEKS
# ==============================================================================

# Menghitung FEVD
vd_lifting <- fevd(model_final, n.ahead = 24)

# Fungsi untuk mengubah objek FEVD menjadi tabel
ekstrak_fevd_teks <- function(vd_object) {
  
  daftar_hasil <- list()
  
  for (var in names(vd_object)) {
    
    matriks <- as.matrix(vd_object[[var]])
    
    # Mengubah matriks menjadi format tabel
    df <- as.data.frame(matriks)
    
    colnames(df) <- colnames(matriks)
    
    df$Variabel_Dependennya <- var
    df$Periode <- seq_len(nrow(df))
    
    # Mengubah proporsi menjadi persentase
    for (kolom in colnames(matriks)) {
      df[[kolom]] <- df[[kolom]] * 100
    }
    
    daftar_hasil[[var]] <- df
  }
  
  hasil <- do.call(rbind, daftar_hasil)
  
  rownames(hasil) <- NULL
  
  return(hasil)
}

# Mengekstrak seluruh hasil FEVD
tabel_fevd <- ekstrak_fevd_teks(vd_lifting)

# Menampilkan seluruh hasil FEVD
cat("\n")
cat("====================================================\n")
cat(" HASIL FORECAST ERROR VARIANCE DECOMPOSITION\n")
cat("====================================================\n")

print(tabel_fevd, row.names = FALSE, digits = 5)

# Menampilkan FEVD khusus variabel Lifting Cost
cat("\n")
cat("====================================================\n")
cat(" FEVD KHUSUS LIFTING COST (%)\n")
cat("====================================================\n")

fevd_lifting_cost <- tabel_fevd[
  tabel_fevd$Variabel_Dependennya == "Lifting_Cost_USD",
]

print(fevd_lifting_cost, row.names = FALSE, digits = 5)

# Menyimpan hasil FEVD keseluruhan
write.csv(
  tabel_fevd,
  "Hasil_FEVD_Seluruh_Variabel.csv",
  row.names = FALSE
)

# Menyimpan hasil FEVD khusus Lifting Cost
write.csv(
  fevd_lifting_cost,
  "Hasil_FEVD_Lifting_Cost.csv",
  row.names = FALSE
)

cat("\nHasil FEVD berhasil disimpan dalam file CSV.\n")

# ==============================================================================
# TAMBAHAN 3: IDENTIFIKASI FAKTOR DOMINAN FEVD LIFTING COST
# ==============================================================================

# Mengambil hasil FEVD Lifting Cost
matriks_lifting <- as.matrix(
  vd_lifting[["Lifting_Cost_USD"]]
)

# Mengubah menjadi persentase
matriks_lifting_persen <- matriks_lifting * 100

# Membuat tabel FEVD khusus Lifting Cost
tabel_dominan <- data.frame(
  Periode = seq_len(nrow(matriks_lifting_persen)),
  matriks_lifting_persen,
  check.names = FALSE
)

# Mengidentifikasi variabel dengan kontribusi terbesar
variabel_guncangan <- colnames(matriks_lifting_persen)

tabel_dominan$Faktor_Dominan <- apply(
  matriks_lifting_persen,
  1,
  function(x) variabel_guncangan[which.max(x)]
)

tabel_dominan$Kontribusi_Tertinggi <- apply(
  matriks_lifting_persen,
  1,
  max
)

# Menampilkan hasil
cat("\n")
cat("====================================================\n")
cat(" IDENTIFIKASI FAKTOR DOMINAN LIFTING COST\n")
cat("====================================================\n")

print(tabel_dominan, row.names = FALSE, digits = 5)

# Menampilkan faktor dominan pada periode ke-24
cat("\n")
cat("FAKTOR DOMINAN PADA HORIZON 24 BULAN:\n")

faktor_24 <- tabel_dominan[
  tabel_dominan$Periode == 24,
]

print(faktor_24, row.names = FALSE, digits = 5)

# Menyimpan hasil identifikasi faktor dominan
write.csv(
  tabel_dominan,
  "Faktor_Dominan_Lifting_Cost.csv",
  row.names = FALSE
)

