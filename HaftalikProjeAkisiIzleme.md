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

