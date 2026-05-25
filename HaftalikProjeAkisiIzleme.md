# Ağ Tabanlı Paralel Dağıtım Sistemleri Projesi
## AdventureWorks2022 Veritabanı - Veri Temizleme ve ETL Süreçleri


##  1. HAFTA - VERİ KEŞFİ VE TEMİZLEME HAZIRLIĞI

Bu haftada temel altyapı kurulması, veri tabanlarının hazırlanması ve temizleme süreçlerinin planlanması yapılmıştır.

### 1.1 Staging Tabloları Oluşturma
Person.Person tablosundan müşteri verilerini depolayan `stg_Person` staging tablosu oluşturuldu. Tablo ValidationStatus ve ErrorDescription sütunlarıyla kalite kontrolü yaparak hatalı verileri karantinada tutar.

### 1.2 E-posta Adresleri İçin Staging Tablosu
`stg_EmailAddress` staging tablosu Person.EmailAddress tablosundan e-posta verilerini alır. EmailValidationPattern sütunu e-posta formatlarını kontrol ederek geçersiz adresler tanımlar.

### 1.3 Eksik Verileri Tespit Etme Raporu
`DataQuality_MissingData` tablosu her sütun için eksik veri sayısı, toplam kayıt ve yüzdesini kaydeder. Bu raporlar temizleme önceliklerini belirlemek için kullanılır.

### 1.4 Veri Uyumsuzluklarını Takip Tablosu
`DataQuality_Inconsistency` tablosu tutarsız verileri DUPLICATE, FORMAT, RANGE ve REFERENCE kategorilerine ayırır. Her sorun açılış tarihi, çözüm durumu ve kapatılış tarihi ile belgelenir.

### 1.5 Veri Dönüştürme Kurallarını Tanımlama
`ETL_TransformationRules` tablosu veri dönüştürme işlemlerini tanımlar. FirstName ve LastName için TRIM/UPPER, EmailAddress için LOWER/TRIM gibi standart kurallar belirlenir.

### 1.6 Kaynak Verilerini Staging'e Yükleme (Person)
Person.Person tablosundan tüm müşteri verileri `stg_Person`'a yüklenir. GETDATE() ile yükleme tarihi otomatik kaydedilir ve EXISTS kontrolü ile çift yükleme önlenir.

### 1.7 E-posta Verilerini Staging'e Yükleme
EmailAddress tablosundan tüm e-posta verileri `stg_EmailAddress`'a yüklenir. Her kayıt ValidationStatus = 'PENDING' olarak işaretlenir ve EmailAddressID ile çift yükleme önlenir.

### 1.8 Eksik Veri Analizi ve Raporlama
FirstName, LastName ve EmailAddress alanlarında NULL veya boş değerler taranır. Her eksiklik sayı ve yüzdesiyle raporlanır ve temizleme öncelikleri belirlenir.

### 1.9 E-posta Format Doğrulaması
E-posta adreslerinin '@' ve '.' içerip içermediği kontrol edilir. Geçersiz formatlar ValidationStatus = 'INVALID_FORMAT' ile işaretlenir ve hata açıklaması kaydedilir.

### 1.10 Standart Dönüştürme Kurallarının Uygulanması ve Veri Entegrasyonu
ETL_TransformationRules tablosuna 5 temel kural tanımlanır: FirstName/LastName için TRIM/UPPER, EmailAddress için LOWER/TRIM, BusinessEntityID referansı ve ModifiedDate güncellemesi. Adres ve telefon verilerinin de benzer kuralları tanımlanıp tüm staging verisi için eksik veri analizi yapılır.

---

##  2. HAFTA - ETL UYGULAMASI VE VERİ DÖNÜŞTÜRME

Bu haftada staging tablolarındaki veriler temizlenerek ana tablolara yüklenir ve kapsamlı raporlar hazırlanır.

### 2.1 Temizlenmiş Tablolar Oluşturma
Cleaned_Person, Cleaned_EmailAddress, Cleaned_Address ve Cleaned_PersonPhone tabloları oluşturulur. Her tablo NOT NULL kısıtları, doğrulama skorları ve IsVerified alanları içerir.

### 2.2 Müşteri Verilerini Temizleyerek Yükleme
stg_Person'dan FirstName ve LastName NULL olmayan kayıtlar alınır. LTRIM, RTRIM, UPPER ile standartlaştırılıp Cleaned_Person'a yüklenir. ETL_ProcessLog'a başarı durumu kaydedilir.

### 2.3 Adres Verilerini Temizleyerek Yükleme
stg_Address'den AddressLine1, City ve PostalCode'ları geçerli olan kayıtlar Cleaned_Address'e yüklenir. Posta kodu 4-10 karakter kontrolü yapılır ve AddressValidationScore hesaplanır.

### 2.4 E-posta ve Telefon Verilerini Temizleyerek Yükleme
stg_EmailAddress ve stg_PersonPhone tablolarından geçerli veriler seçilir. E-postalar LOWER/TRIM ile, telefonlar tire ve parantez kaldırılarak temizlenir. Cleaned_EmailAddress ve Cleaned_PersonPhone'a yüklenir.

### 2.5 Yinelenen Kayıtları Tespit ve Veri Kalitesi Raporu
GROUP BY BusinessEntityID ile aynı müşteri için birden fazla kayıt olup olmadığı kontrol edilir. Yinelenen kayıtlar DataQuality_Inconsistency'e DUPLICATE olarak işaretlenir.

### 2.6 ETL Performans ve İşlem Günlüğü
ETL_ProcessLog tablosuna her temizleme adımının başlangıç/bitiş saati, işlenen kayıt sayıları ve hata durumu kaydedilir. vw_ETL_Performance view'i ile her adımın süresi ve başarı oranı görülür.

### 2.7 Bütünleşik Müşteri Profilleri View'leri
vw_Cleaned_Customer_Data ve vw_Cleaned_Customer_Complete_Profile view'leri oluşturulur. Müşteri bilgileri e-posta, adres ve telefon verileriyle LEFT JOIN ile birleştirilir.

### 2.8 Veri Kalitesi Karşılaştırma ve Metrikleri
vw_Data_Quality_Comparison view'i Staging ve Cleaned tablolar arasındaki farkları gösterir. Genel veri kalitesi yüzdesi, eksik veri raporları ve risk seviyeleri hesaplanır.

### 2.9 Kapsamlı Raporlar - Hata, Eksik Veri ve Performans
DataQuality_Inconsistency, DataQuality_MissingData ve ETL_ProcessLog tabloları detaylı şekilde sorgulanır. Hata tipleri, eksik veri yüzdeleri ve işlem performansları raporlanır.

### 2.10 Proje Tamamlama Raporu ve Son İstatistikler
ETL İşlemi Özet Raporu sunulur. Toplam işlenen, temizlenen, doğrulanan kayıt sayıları, genel veri kalitesi yüzdesi ve proje tamamlanma tarihi belirtilir.

Gerekli Video Linklerim:
[Final 3. ProjeV1:(Proje 5: Veri Temizleme ve ETL Süreçleri Tasarımı)](https://drive.google.com/file/d/1e6bvomdhwSxS_xMZ4ox9Hl23wolZwxY7/view?usp=drive_link)
[Final 3. ProjeV2:(Proje 5: Veri Temizleme ve ETL Süreçleri Tasarımı)](https://drive.google.com/file/d/1h6YWU3Z1aYzAaB0UO3U6PIA--2XD9Aoz/view?usp=drive_link)