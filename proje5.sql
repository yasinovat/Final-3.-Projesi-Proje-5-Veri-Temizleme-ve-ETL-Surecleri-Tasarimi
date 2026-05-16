-- ============================================================================
-- Ağ Tabanlı Paralel Dağıtım Sistemleri PROJESİ
-- AdventureWorks2022 Veritabanı - Veri Temizleme ve ETL Süreçleri
-- ============================================================================

USE AdventureWorks2022;
GO

-- 1. HAFTA - VERİ KEŞFİ VE TEMİZLEME HAZIRLIĞI
-- Bu hafta: Staging tabloları, veri kalitesi kontrolleri ve temizleme kurallarının oluşturulması

-- 1.1 Staging Tablosu Oluşturma - Müşteri Verileri
-- Amacı: Person.Person tablosundan hatalı verileri karantinada tutmak
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'stg_Person')
BEGIN
    CREATE TABLE dbo.stg_Person
    (
        StagingID INT IDENTITY(1,1) PRIMARY KEY,
        BusinessEntityID INT NULL,
        PersonType NCHAR(2) NULL,
        NameStyle BIT NULL,
        FirstName NVARCHAR(50) NULL,
        MiddleName NVARCHAR(50) NULL,
        LastName NVARCHAR(50) NULL,
        Suffix NVARCHAR(10) NULL,
        EmailPromotion INT NULL,
        AdditionalContactInfo XML NULL,
        Demographics XML NULL,
        rowguid UNIQUEIDENTIFIER NULL,
        ModifiedDate DATETIME NULL,
        LoadDate DATETIME DEFAULT GETDATE(),
        ValidationStatus NVARCHAR(50) DEFAULT 'PENDING',
        ErrorDescription NVARCHAR(MAX) NULL
    )
END
GO

-- 1.2 Müşteri İletişim Bilgileri İçin Staging Tablosu
-- Amacı: EmailAddress tablosundan hatalı e-posta adreslerini temizlemek
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'stg_EmailAddress')
BEGIN
    CREATE TABLE dbo.stg_EmailAddress
    (
        StagingID INT IDENTITY(1,1) PRIMARY KEY,
        BusinessEntityID INT NULL,
        EmailAddressID INT NULL,
        EmailAddress NVARCHAR(50) NULL,
        rowguid UNIQUEIDENTIFIER NULL,
        ModifiedDate DATETIME NULL,
        LoadDate DATETIME DEFAULT GETDATE(),
        ValidationStatus NVARCHAR(50) DEFAULT 'PENDING',
        EmailValidationPattern INT NULL,
        ErrorDescription NVARCHAR(MAX) NULL
    )
END
GO

-- 1.3 Eksik Verileri Tespit Etme - Raporlama Tablosu
-- Amacı: Boş ve eksik veri alanlarını raporlamak
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DataQuality_MissingData')
BEGIN
    CREATE TABLE dbo.DataQuality_MissingData
    (
        QualityID INT IDENTITY(1,1) PRIMARY KEY,
        SourceTable NVARCHAR(100),
        ColumnName NVARCHAR(100),
        MissingRecordCount INT,
        TotalRecordCount INT,
        MissingPercentage DECIMAL(5,2),
        DetectionDate DATETIME DEFAULT GETDATE(),
        Resolution NVARCHAR(MAX) NULL
    )
END
GO

-- 1.4 Tutarsız Veri Tespit Etme Tablosu
-- Amacı: Veri uyumsuzluklarını kaydetmek
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DataQuality_Inconsistency')
BEGIN
    CREATE TABLE dbo.DataQuality_Inconsistency
    (
        InconsistencyID INT IDENTITY(1,1) PRIMARY KEY,
        SourceTable NVARCHAR(100),
        RecordID INT,
        IssueDescription NVARCHAR(MAX),
        InconsistencyType NVARCHAR(50), -- DUPLICATE, FORMAT, RANGE, REFERENCE
        DetectionDate DATETIME DEFAULT GETDATE(),
        ResolutionStatus NVARCHAR(20) DEFAULT 'OPEN',
        ResolvedDate DATETIME NULL
    )
END
GO

-- 1.5 Veri Dönüştürme Kuralları Tablosu
-- Amacı: Hangi verilerin nasıl dönüştürülüceğini tanımlamak
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ETL_TransformationRules')
BEGIN
    CREATE TABLE dbo.ETL_TransformationRules
    (
        RuleID INT IDENTITY(1,1) PRIMARY KEY,
        SourceField NVARCHAR(100),
        TargetField NVARCHAR(100),
        TransformationType NVARCHAR(50), -- STANDARDIZE, FORMAT, CALCULATE, LOOKUP
        TransformationLogic NVARCHAR(MAX),
        CreatedDate DATETIME DEFAULT GETDATE(),
        IsActive BIT DEFAULT 1
    )
END
GO

-- 1.6 Müşteri Verisini Staging'e Aktarma
-- Amacı: Person tablosundaki tüm müşteri verilerini staging'e yüklemek
INSERT INTO dbo.stg_Person
SELECT 
    p.BusinessEntityID,
    p.PersonType,
    p.NameStyle,
    p.FirstName,
    p.MiddleName,
    p.LastName,
    p.Suffix,
    p.EmailPromotion,
    p.AdditionalContactInfo,
    p.Demographics,
    p.rowguid,
    p.ModifiedDate,
    GETDATE(),
    'PENDING',
    NULL
FROM Person.Person p
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.stg_Person 
    WHERE BusinessEntityID = p.BusinessEntityID
)
GO

-- 1.7 E-posta Verilerini Staging'e Aktarma
-- Amacı: EmailAddress tablosundan tüm verileri staging'e yüklemek
INSERT INTO dbo.stg_EmailAddress
SELECT 
    ea.BusinessEntityID,
    ea.EmailAddressID,
    ea.EmailAddress,
    ea.rowguid,
    ea.ModifiedDate,
    GETDATE(),
    'PENDING',
    0,
    NULL
FROM Person.EmailAddress ea
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.stg_EmailAddress 
    WHERE EmailAddressID = ea.EmailAddressID
)
GO

-- 1.8 Eksik Verileri Tespit Etme Sorgusu
-- Amacı: stg_Person tablosundaki boş alanları raporlamak
INSERT INTO dbo.DataQuality_MissingData
SELECT 
    'stg_Person' AS SourceTable,
    'FirstName' AS ColumnName,
    COUNT(*) AS MissingRecordCount,
    (SELECT COUNT(*) FROM dbo.stg_Person) AS TotalRecordCount,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM dbo.stg_Person) AS DECIMAL(5,2)) AS MissingPercentage,
    GETDATE(),
    NULL
FROM dbo.stg_Person
WHERE FirstName IS NULL OR FirstName = ''

UNION ALL

SELECT 
    'stg_Person' AS SourceTable,
    'LastName' AS ColumnName,
    COUNT(*) AS MissingRecordCount,
    (SELECT COUNT(*) FROM dbo.stg_Person) AS TotalRecordCount,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM dbo.stg_Person) AS DECIMAL(5,2)) AS MissingPercentage,
    GETDATE(),
    NULL
FROM dbo.stg_Person
WHERE LastName IS NULL OR LastName = ''

UNION ALL

SELECT 
    'stg_EmailAddress' AS SourceTable,
    'EmailAddress' AS ColumnName,
    COUNT(*) AS MissingRecordCount,
    (SELECT COUNT(*) FROM dbo.stg_EmailAddress) AS TotalRecordCount,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM dbo.stg_EmailAddress) AS DECIMAL(5,2)) AS MissingPercentage,
    GETDATE(),
    NULL
FROM dbo.stg_EmailAddress
WHERE EmailAddress IS NULL OR EmailAddress = ''
GO

-- 1.9 Hatalı E-posta Formatlarını Tespit Etme
-- Amacı: Geçersiz e-posta adreslerini bulmak
UPDATE dbo.stg_EmailAddress
SET ValidationStatus = 'INVALID_FORMAT',
    ErrorDescription = 'E-posta adresi @ işareti içermemektedir'
WHERE (EmailAddress NOT LIKE '%@%.%' OR EmailAddress IS NULL)
GO

-- 1.10 Veri Dönüştürme Kurallarını Tanımlama
-- Amacı: Hangi verilerin nasıl standartlaştırılacağını belirtmek
INSERT INTO dbo.ETL_TransformationRules
(SourceField, TargetField, TransformationType, TransformationLogic)
VALUES 
    ('FirstName', 'FirstName_Cleaned', 'STANDARDIZE', 'TRIM() ve UPPER()'),
    ('LastName', 'LastName_Cleaned', 'STANDARDIZE', 'TRIM() ve UPPER()'),
    ('EmailAddress', 'EmailAddress_Cleaned', 'FORMAT', 'LOWER() ve TRIM()'),
    ('BusinessEntityID', 'CustomerID', 'LOOKUP', 'Sales.Customer tablosuna referans'),
    ('ModifiedDate', 'LoadDate', 'CALCULATE', 'GETDATE() ile güncelleme')
GO

-- 1.11 Adres Verileri Staging Tablosu
-- Amacı: Address tablosundan hatalı adres verilerini kontrol etmek
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'stg_Address')
BEGIN
    CREATE TABLE dbo.stg_Address
    (
        StagingID INT IDENTITY(1,1) PRIMARY KEY,
        AddressID INT NULL,
        AddressLine1 NVARCHAR(60) NULL,
        AddressLine2 NVARCHAR(60) NULL,
        City NVARCHAR(30) NULL,
        StateProvinceID INT NULL,
        PostalCode NVARCHAR(15) NULL,
        rowguid UNIQUEIDENTIFIER NULL,
        ModifiedDate DATETIME NULL,
        LoadDate DATETIME DEFAULT GETDATE(),
        ValidationStatus NVARCHAR(50) DEFAULT 'PENDING',
        ErrorDescription NVARCHAR(MAX) NULL
    )
END
GO

-- 1.12 Telefon Numaraları Staging Tablosu
-- Amacı: PersonPhone tablosundan hatalı telefon numaralarını tespit etmek
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'stg_PersonPhone')
BEGIN
    CREATE TABLE dbo.stg_PersonPhone
    (
        StagingID INT IDENTITY(1,1) PRIMARY KEY,
        BusinessEntityID INT NULL,
        PhoneNumber NVARCHAR(25) NULL,
        PhoneNumberTypeID INT NULL,
        PhoneType NVARCHAR(50) NULL,
        ModifiedDate DATETIME NULL,
        LoadDate DATETIME DEFAULT GETDATE(),
        ValidationStatus NVARCHAR(50) DEFAULT 'PENDING',
        ErrorDescription NVARCHAR(MAX) NULL
    )
END
GO

-- 1.13 Adres Verilerini Staging'e Yükleme
-- Amacı: Address tablosundan tüm adres verilerini staging'e aktarmak
INSERT INTO dbo.stg_Address
SELECT 
    a.AddressID,
    a.AddressLine1,
    a.AddressLine2,
    a.City,
    a.StateProvinceID,
    a.PostalCode,
    a.rowguid,
    a.ModifiedDate,
    GETDATE(),
    'PENDING',
    NULL
FROM Person.Address a
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.stg_Address 
    WHERE AddressID = a.AddressID
)
GO

-- 1.14 Telefon Verilerini Staging'e Yükleme
-- Amacı: PersonPhone tablosundan tüm telefon verilerini staging'e aktarmak
INSERT INTO dbo.stg_PersonPhone
SELECT 
    pp.BusinessEntityID,
    pp.PhoneNumber,
    pp.PhoneNumberTypeID,
    ppt.Name,
    pp.ModifiedDate,
    GETDATE(),
    'PENDING',
    NULL
FROM Person.PersonPhone pp
LEFT JOIN Person.PhoneNumberType ppt ON pp.PhoneNumberTypeID = ppt.PhoneNumberTypeID
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.stg_PersonPhone 
    WHERE BusinessEntityID = pp.BusinessEntityID AND PhoneNumber = pp.PhoneNumber
)
GO

-- 1.15 Adres Verilerini Doğrulama
-- Amacı: Eksik ve hatalı adres verilerini belirlemek
UPDATE dbo.stg_Address
SET ValidationStatus = 'INVALID_ADDRESS',
    ErrorDescription = 'Adres satırı 1 boş bırakılmıştır'
WHERE AddressLine1 IS NULL OR LTRIM(RTRIM(AddressLine1)) = ''

UPDATE dbo.stg_Address
SET ValidationStatus = 'INVALID_CITY',
    ErrorDescription = 'Şehir bilgisi boş bırakılmıştır'
WHERE City IS NULL OR LTRIM(RTRIM(City)) = ''

UPDATE dbo.stg_Address
SET ValidationStatus = 'INVALID_POSTALCODE',
    ErrorDescription = 'Posta kodu geçersiz formattadır'
WHERE PostalCode IS NULL OR LEN(LTRIM(RTRIM(PostalCode))) < 3 OR LEN(LTRIM(RTRIM(PostalCode))) > 10
GO

-- 1.16 Telefon Numarası Doğrulaması
-- Amacı: Geçersiz telefon numaralarını tanımlamak
UPDATE dbo.stg_PersonPhone
SET ValidationStatus = 'INVALID_PHONE',
    ErrorDescription = 'Telefon numarası 10 karakterden az'
WHERE PhoneNumber IS NULL OR LEN(REPLACE(REPLACE(REPLACE(PhoneNumber, '-', ''), '(', ''), ')', '')) < 10

UPDATE dbo.stg_PersonPhone
SET ValidationStatus = 'INVALID_PHONE',
    ErrorDescription = 'Telefon numarası 15 karakterden fazla'
WHERE LEN(PhoneNumber) > 15
GO

-- 1.17 Posta Kodu Aralık Kontrolleri
-- Amacı: Geçersiz posta kodlarını tespit etmek
INSERT INTO dbo.DataQuality_Inconsistency
(SourceTable, RecordID, IssueDescription, InconsistencyType, ResolutionStatus)
SELECT 
    'stg_Address',
    AddressID,
    'Posta kodu aralık dışında: ' + ISNULL(PostalCode, 'NULL'),
    'RANGE',
    'OPEN'
FROM dbo.stg_Address
WHERE PostalCode IS NOT NULL 
AND (LEN(LTRIM(RTRIM(PostalCode))) < 4 OR LEN(LTRIM(RTRIM(PostalCode))) > 10)
GO

-- 1.18 Şehir ve Bölge Eşleştirme Doğrulaması
-- Amacı: StateProvinceID ile City arasında uyumsuzluk olup olmadığını tespit etmek
INSERT INTO dbo.DataQuality_Inconsistency
(SourceTable, RecordID, IssueDescription, InconsistencyType, ResolutionStatus)
SELECT 
    'stg_Address',
    sa.AddressID,
    'StateProvinceID: ' + ISNULL(CAST(sa.StateProvinceID AS NVARCHAR(10)), 'NULL') + ', City: ' + sa.City,
    'REFERENCE',
    'OPEN'
FROM dbo.stg_Address sa
WHERE sa.StateProvinceID IS NULL AND sa.City IS NOT NULL
GO

-- 1.19 Telefon Numarası Biçim Normalizasyonu Kuralı
-- Amacı: Farklı telefon formatlarını standartlaştırma kuralı tanımlama
INSERT INTO dbo.ETL_TransformationRules
(SourceField, TargetField, TransformationType, TransformationLogic)
VALUES 
    ('PhoneNumber', 'PhoneNumber_Cleaned', 'FORMAT', 'Tire ve parantez kaldırıp sadece rakam tutma'),
    ('City', 'City_Cleaned', 'STANDARDIZE', 'TRIM() ve UPPER()'),
    ('PostalCode', 'PostalCode_Cleaned', 'FORMAT', 'TRIM() ve standart uzunluk kontrol')
GO

-- 1.20 Veri Entegrasyonu Durumu Raporlaması
-- Amacı: Staging verilerinin tamamlama yüzdesini hesaplamak
INSERT INTO dbo.DataQuality_MissingData
SELECT 
    'stg_Address' AS SourceTable,
    'AddressLine1' AS ColumnName,
    COUNT(*) AS MissingRecordCount,
    (SELECT COUNT(*) FROM dbo.stg_Address) AS TotalRecordCount,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM dbo.stg_Address) AS DECIMAL(5,2)) AS MissingPercentage,
    GETDATE(),
    NULL
FROM dbo.stg_Address
WHERE AddressLine1 IS NULL OR LTRIM(RTRIM(AddressLine1)) = ''

UNION ALL

SELECT 
    'stg_PersonPhone' AS SourceTable,
    'PhoneNumber' AS ColumnName,
    COUNT(*) AS MissingRecordCount,
    (SELECT COUNT(*) FROM dbo.stg_PersonPhone) AS TotalRecordCount,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM dbo.stg_PersonPhone) AS DECIMAL(5,2)) AS MissingPercentage,
    GETDATE(),
    NULL
FROM dbo.stg_PersonPhone
WHERE PhoneNumber IS NULL
GO


