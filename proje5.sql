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

-- ============================================================================
-- 2. HAFTA - ETL UYGRULAMASI VE VERİ DÖNÜŞTÜRME
-- ============================================================================
-- Bu hafta: Veri temizleme, dönüştürme ve final yükleme işlemleri

-- 2.1 Temizlenmiş Müşteri Tablosu Oluşturma
-- Amacı: Temizlenen ve doğrulanmış müşteri verilerini saklamak
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Cleaned_Person')
BEGIN
    CREATE TABLE dbo.Cleaned_Person
    (
        CleanedID INT IDENTITY(1,1) PRIMARY KEY,
        BusinessEntityID INT NOT NULL UNIQUE,
        FirstName NVARCHAR(50) NOT NULL,
        LastName NVARCHAR(50) NOT NULL,
        MiddleName NVARCHAR(50) NULL,
        PersonType NCHAR(2) NOT NULL,
        EmailPromotion INT NOT NULL,
        CleanedDate DATETIME DEFAULT GETDATE(),
        SourceValidationID INT,
        DataQualityScore DECIMAL(3,2)
    )
END
GO

-- 2.2 Temizlenmiş E-posta Tablosu Oluşturma
-- Amacı: Doğrulanmış e-posta adreslerini saklamak
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Cleaned_EmailAddress')
BEGIN
    CREATE TABLE dbo.Cleaned_EmailAddress
    (
        CleanedEmailID INT IDENTITY(1,1) PRIMARY KEY,
        BusinessEntityID INT NOT NULL,
        EmailAddress NVARCHAR(50) NOT NULL,
        EmailValidationScore DECIMAL(3,2),
        CleanedDate DATETIME DEFAULT GETDATE(),
        IsVerified BIT DEFAULT 0
    )
END
GO

-- 2.3 ETL İşlem Günlüğü Tablosu
-- Amacı: Tüm ETL işlemlerinin başarı/başarısızlığını kaydetmek
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ETL_ProcessLog')
BEGIN
    CREATE TABLE dbo.ETL_ProcessLog
    (
        LogID INT IDENTITY(1,1) PRIMARY KEY,
        ProcessName NVARCHAR(100),
        StartTime DATETIME,
        EndTime DATETIME,
        RecordsProcessed INT,
        RecordsSuccessful INT,
        RecordsFailed INT,
        ErrorMessage NVARCHAR(MAX) NULL,
        ProcessStatus NVARCHAR(20) -- SUCCESS, FAILED, PARTIAL
    )
END
GO

-- 2.3a Temizlenmiş Adres Tablosu
-- Amacı: Doğrulanmış adres verilerini saklamak
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Cleaned_Address')
BEGIN
    CREATE TABLE dbo.Cleaned_Address
    (
        CleanedAddressID INT IDENTITY(1,1) PRIMARY KEY,
        AddressID INT NOT NULL UNIQUE,
        AddressLine1 NVARCHAR(60) NOT NULL,
        AddressLine2 NVARCHAR(60) NULL,
        City NVARCHAR(30) NOT NULL,
        StateProvinceID INT NOT NULL,
        PostalCode NVARCHAR(15) NOT NULL,
        CleanedDate DATETIME DEFAULT GETDATE(),
        AddressValidationScore DECIMAL(3,2),
        IsVerified BIT DEFAULT 0
    )
END
GO

-- 2.3b Temizlenmiş Telefon Numaraları Tablosu
-- Amacı: Doğrulanmış ve formatı düzeltilmiş telefon numaralarını saklamak
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Cleaned_PersonPhone')
BEGIN
    CREATE TABLE dbo.Cleaned_PersonPhone
    (
        CleanedPhoneID INT IDENTITY(1,1) PRIMARY KEY,
        BusinessEntityID INT NOT NULL,
        PhoneNumber NVARCHAR(25) NOT NULL,
        PhoneNumberCleaned NVARCHAR(20) NOT NULL,
        PhoneType NVARCHAR(50) NULL,
        CleanedDate DATETIME DEFAULT GETDATE(),
        PhoneValidationScore DECIMAL(3,2),
        IsVerified BIT DEFAULT 0
    )
END
GO

-- 2.4 Müşteri Verilerini Temizleyerek Yükleme
-- Amacı: stg_Person'dan hatasız verileri Cleaned_Person'a aktarmak
INSERT INTO dbo.ETL_ProcessLog
(ProcessName, StartTime, RecordsProcessed, RecordsSuccessful, RecordsFailed, ProcessStatus)
VALUES ('ETL_Clean_Person_Start', GETDATE(), 0, 0, 0, 'RUNNING')

DECLARE @LogID INT = SCOPE_IDENTITY();

BEGIN TRY
    INSERT INTO dbo.Cleaned_Person
    (BusinessEntityID, FirstName, LastName, MiddleName, PersonType, EmailPromotion, SourceValidationID, DataQualityScore)
    SELECT 
        sp.BusinessEntityID,
        LTRIM(RTRIM(UPPER(sp.FirstName))),
        LTRIM(RTRIM(UPPER(sp.LastName))),
        LTRIM(RTRIM(sp.MiddleName)),
        sp.PersonType,
        sp.EmailPromotion,
        sp.StagingID,
        CASE 
            WHEN sp.FirstName IS NOT NULL AND sp.LastName IS NOT NULL THEN 0.95
            WHEN sp.FirstName IS NULL OR sp.LastName IS NULL THEN 0.70
            ELSE 0.50
        END
    FROM dbo.stg_Person sp
    WHERE sp.FirstName IS NOT NULL 
    AND sp.LastName IS NOT NULL 
    AND LTRIM(RTRIM(sp.FirstName)) <> ''
    AND LTRIM(RTRIM(sp.LastName)) <> ''
    
    UPDATE dbo.ETL_ProcessLog
    SET EndTime = GETDATE(),
        RecordsProcessed = @@ROWCOUNT,
        RecordsSuccessful = @@ROWCOUNT,
        ProcessStatus = 'SUCCESS'
    WHERE LogID = @LogID
END TRY
BEGIN CATCH
    UPDATE dbo.ETL_ProcessLog
    SET EndTime = GETDATE(),
        ErrorMessage = ERROR_MESSAGE(),
        ProcessStatus = 'FAILED'
    WHERE LogID = @LogID
END CATCH
GO

-- 2.4a Adres Verilerini Temizleyerek Yükleme
-- Amacı: stg_Address'den hatasız adres verilerini Cleaned_Address'e aktarmak
INSERT INTO dbo.ETL_ProcessLog
(ProcessName, StartTime, RecordsProcessed, RecordsSuccessful, RecordsFailed, ProcessStatus)
VALUES ('ETL_Clean_Address_Start', GETDATE(), 0, 0, 0, 'RUNNING')

DECLARE @LogID_Addr INT = SCOPE_IDENTITY();

BEGIN TRY
    INSERT INTO dbo.Cleaned_Address
    (AddressID, AddressLine1, AddressLine2, City, StateProvinceID, PostalCode, AddressValidationScore, IsVerified)
    SELECT 
        sa.AddressID,
        LTRIM(RTRIM(UPPER(sa.AddressLine1))),
        LTRIM(RTRIM(sa.AddressLine2)),
        LTRIM(RTRIM(UPPER(sa.City))),
        sa.StateProvinceID,
        LTRIM(RTRIM(sa.PostalCode)),
        CASE 
            WHEN sa.AddressLine1 IS NOT NULL AND sa.City IS NOT NULL AND sa.PostalCode IS NOT NULL THEN 0.98
            WHEN sa.AddressLine1 IS NOT NULL AND sa.City IS NOT NULL THEN 0.85
            ELSE 0.70
        END,
        CASE 
            WHEN sa.AddressLine1 IS NOT NULL AND sa.City IS NOT NULL AND sa.PostalCode IS NOT NULL 
                 AND LEN(LTRIM(RTRIM(sa.PostalCode))) BETWEEN 4 AND 10 THEN 1
            ELSE 0
        END
    FROM dbo.stg_Address sa
    WHERE sa.AddressLine1 IS NOT NULL 
    AND sa.City IS NOT NULL 
    AND LTRIM(RTRIM(sa.AddressLine1)) <> ''
    AND LTRIM(RTRIM(sa.City)) <> ''
    AND sa.PostalCode IS NOT NULL
    AND LEN(LTRIM(RTRIM(sa.PostalCode))) BETWEEN 4 AND 10
    
    UPDATE dbo.ETL_ProcessLog
    SET EndTime = GETDATE(),
        RecordsProcessed = @@ROWCOUNT,
        RecordsSuccessful = @@ROWCOUNT,
        ProcessStatus = 'SUCCESS'
    WHERE LogID = @LogID_Addr
END TRY
BEGIN CATCH
    UPDATE dbo.ETL_ProcessLog
    SET EndTime = GETDATE(),
        ErrorMessage = ERROR_MESSAGE(),
        ProcessStatus = 'FAILED'
    WHERE LogID = @LogID_Addr
END CATCH
GO

-- 2.4b Telefon Numaralarını Temizleyerek Yükleme
-- Amacı: stg_PersonPhone'den temizlenmiş telefon verilerini yüklemek
INSERT INTO dbo.ETL_ProcessLog
(ProcessName, StartTime, RecordsProcessed, RecordsSuccessful, RecordsFailed, ProcessStatus)
VALUES ('ETL_Clean_PersonPhone_Start', GETDATE(), 0, 0, 0, 'RUNNING')

DECLARE @LogID_Phone INT = SCOPE_IDENTITY();

BEGIN TRY
    INSERT INTO dbo.Cleaned_PersonPhone
    (BusinessEntityID, PhoneNumber, PhoneNumberCleaned, PhoneType, PhoneValidationScore, IsVerified)
    SELECT 
        spp.BusinessEntityID,
        spp.PhoneNumber,
        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(spp.PhoneNumber, '-', ''), '(', ''), ')', ''), ' ', ''), '.', ''),
        spp.PhoneType,
        CASE 
            WHEN LEN(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(spp.PhoneNumber, '-', ''), '(', ''), ')', ''), ' ', ''), '.', '')) = 10 THEN 0.98
            WHEN LEN(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(spp.PhoneNumber, '-', ''), '(', ''), ')', ''), ' ', ''), '.', '')) BETWEEN 10 AND 15 THEN 0.85
            ELSE 0.70
        END,
        CASE 
            WHEN LEN(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(spp.PhoneNumber, '-', ''), '(', ''), ')', ''), ' ', ''), '.', '')) = 10 
                 AND spp.PhoneNumber IS NOT NULL THEN 1
            ELSE 0
        END
    FROM dbo.stg_PersonPhone spp
    WHERE spp.PhoneNumber IS NOT NULL 
    AND LEN(spp.PhoneNumber) >= 10
    
    UPDATE dbo.ETL_ProcessLog
    SET EndTime = GETDATE(),
        RecordsProcessed = @@ROWCOUNT,
        RecordsSuccessful = @@ROWCOUNT,
        ProcessStatus = 'SUCCESS'
    WHERE LogID = @LogID_Phone
END TRY
BEGIN CATCH
    UPDATE dbo.ETL_ProcessLog
    SET EndTime = GETDATE(),
        ErrorMessage = ERROR_MESSAGE(),
        ProcessStatus = 'FAILED'
    WHERE LogID = @LogID_Phone
END CATCH
GO

-- 2.5 E-posta Verilerini Temizleyerek Yükleme
-- Amacı: Geçerli e-posta adreslerini Cleaned_EmailAddress'e aktarmak
INSERT INTO dbo.ETL_ProcessLog
(ProcessName, StartTime, RecordsProcessed, RecordsSuccessful, RecordsFailed, ProcessStatus)
VALUES ('ETL_Clean_EmailAddress_Start', GETDATE(), 0, 0, 0, 'RUNNING')

DECLARE @LogID2 INT = SCOPE_IDENTITY();

BEGIN TRY
    INSERT INTO dbo.Cleaned_EmailAddress
    (BusinessEntityID, EmailAddress, EmailValidationScore, IsVerified)
    SELECT 
        sea.BusinessEntityID,
        LTRIM(RTRIM(LOWER(sea.EmailAddress))),
        CASE 
            WHEN sea.EmailAddress LIKE '%@%.%' AND LEN(sea.EmailAddress) > 5 THEN 0.98
            WHEN sea.EmailAddress LIKE '%@%.%' THEN 0.85
            ELSE 0.50
        END,
        CASE 
            WHEN sea.EmailAddress LIKE '%@%.%' AND LEN(sea.EmailAddress) > 5 THEN 1
            ELSE 0
        END
    FROM dbo.stg_EmailAddress sea
    WHERE sea.ValidationStatus = 'PENDING'
    AND sea.EmailAddress IS NOT NULL 
    AND sea.EmailAddress LIKE '%@%.%'
    
    UPDATE dbo.ETL_ProcessLog
    SET EndTime = GETDATE(),
        RecordsProcessed = @@ROWCOUNT,
        RecordsSuccessful = @@ROWCOUNT,
        ProcessStatus = 'SUCCESS'
    WHERE LogID = @LogID2
END TRY
BEGIN CATCH
    UPDATE dbo.ETL_ProcessLog
    SET EndTime = GETDATE(),
        ErrorMessage = ERROR_MESSAGE(),
        ProcessStatus = 'FAILED'
    WHERE LogID = @LogID2
END CATCH
GO

-- 2.6 Yinelenen Kayıtları Tespit Etme
-- Amacı: Aynı BusinessEntityID ile birden fazla kayıt olup olmadığını bulmak
INSERT INTO dbo.DataQuality_Inconsistency
(SourceTable, RecordID, IssueDescription, InconsistencyType, ResolutionStatus)
SELECT 
    'stg_EmailAddress',
    BusinessEntityID,
    'Aynı müşteri için ' + CAST(COUNT(*) AS NVARCHAR(10)) + ' e-posta adresi bulunmaktadır',
    'DUPLICATE',
    'OPEN'
FROM dbo.stg_EmailAddress
GROUP BY BusinessEntityID
HAVING COUNT(*) > 1
GO

-- 2.7 Veri Kalitesi Özet Raporu
-- Amacı: Genel veri kalitesi metriklerini göstermek
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DataQuality_Summary')
BEGIN
    CREATE TABLE dbo.DataQuality_Summary
    (
        SummaryID INT IDENTITY(1,1) PRIMARY KEY,
        ReportDate DATETIME DEFAULT GETDATE(),
        TotalStagingRecords INT,
        CleanedRecords INT,
        InvalidRecords INT,
        DuplicateRecords INT,
        OverallDataQualityPercentage DECIMAL(5,2),
        ReportDetails NVARCHAR(MAX)
    )
END

INSERT INTO dbo.DataQuality_Summary
(TotalStagingRecords, CleanedRecords, InvalidRecords, DuplicateRecords, OverallDataQualityPercentage)
VALUES (
    (SELECT COUNT(*) FROM dbo.stg_Person),
    (SELECT COUNT(*) FROM dbo.Cleaned_Person),
    (SELECT COUNT(*) FROM dbo.stg_Person WHERE FirstName IS NULL OR LastName IS NULL),
    (SELECT COUNT(DISTINCT InconsistencyType) FROM dbo.DataQuality_Inconsistency WHERE InconsistencyType = 'DUPLICATE'),
    CAST((SELECT COUNT(*) FROM dbo.Cleaned_Person) * 100.0 / (SELECT COUNT(*) FROM dbo.stg_Person) AS DECIMAL(5,2))
)
GO

-- 2.8 ETL Performans Raporu
-- Amacı: Her ETL adımının performansını ölçmek

DROP VIEW IF EXISTS dbo.vw_ETL_Performance;
GO

CREATE VIEW dbo.vw_ETL_Performance AS
SELECT 
    ProcessName,
    StartTime,
    EndTime,
    DATEDIFF(SECOND, StartTime, EndTime) AS DurationSeconds,
    RecordsProcessed,
    RecordsSuccessful,
    RecordsFailed,
    CAST(RecordsSuccessful * 100.0 / NULLIF(RecordsProcessed, 0) AS DECIMAL(5,2)) AS SuccessRate,
    ProcessStatus
FROM dbo.ETL_ProcessLog;
GO


-- 2.9 Final Veri Yükleme - Müşteri Adresleri
-- Amacı: Temizlenmiş müşteri verilerini main tablolarla ilişkilendirmek

DROP VIEW IF EXISTS dbo.vw_Cleaned_Customer_Data;
GO

CREATE VIEW dbo.vw_Cleaned_Customer_Data AS
SELECT 
    cp.CleanedID,
    cp.BusinessEntityID,
    cp.FirstName + ' ' + ISNULL(cp.MiddleName + ' ', '') + cp.LastName AS FullName,
    ISNULL(cea.EmailAddress, 'N/A') AS PrimaryEmail,
    cea.EmailValidationScore,
    cp.DataQualityScore,
    cp.CleanedDate
FROM dbo.Cleaned_Person cp
LEFT JOIN dbo.Cleaned_EmailAddress cea 
    ON cp.BusinessEntityID = cea.BusinessEntityID
WHERE cea.IsVerified = 1 OR cea.EmailAddress IS NULL;
GO


-- 2.9a Temizlenmiş Müşteri Profilleri - Adres ve İletişim Bilgileriyle
-- Amacı: Adres ve telefon bilgileriyle bütünleşik müşteri profilleri oluşturmak

DROP VIEW IF EXISTS dbo.vw_Cleaned_Customer_Complete_Profile;
GO

CREATE VIEW dbo.vw_Cleaned_Customer_Complete_Profile AS
SELECT 
    cp.CleanedID,
    cp.BusinessEntityID,
    cp.FirstName + ' ' + ISNULL(cp.MiddleName + ' ', '') + cp.LastName AS FullName,
    ISNULL(cea.EmailAddress, 'N/A') AS Email,
    ISNULL(ca.AddressLine1, 'N/A') + ', ' + ISNULL(ca.City, '') AS Address,
    ISNULL(ca.PostalCode, 'N/A') AS PostalCode,
    ISNULL(cpp.PhoneNumberCleaned, 'N/A') AS Phone,
    cp.DataQualityScore,
    CASE 
        WHEN cea.IsVerified = 1 AND ca.IsVerified = 1 AND cpp.IsVerified = 1 THEN 'COMPLETE'
        WHEN cea.IsVerified = 1 OR ca.IsVerified = 1 OR cpp.IsVerified = 1 THEN 'PARTIAL'
        ELSE 'INCOMPLETE'
    END AS ProfileCompleteness
FROM dbo.Cleaned_Person cp
LEFT JOIN dbo.Cleaned_EmailAddress cea 
    ON cp.BusinessEntityID = cea.BusinessEntityID
LEFT JOIN Person.BusinessEntityAddress bea
    ON cp.BusinessEntityID = bea.BusinessEntityID
LEFT JOIN dbo.Cleaned_Address ca 
    ON bea.AddressID = ca.AddressID
LEFT JOIN dbo.Cleaned_PersonPhone cpp 
    ON cp.BusinessEntityID = cpp.BusinessEntityID;
GO


-- 2.9b Veri Kalitesi Karşılaştırma Raporu
-- Amacı: Staging ve temizlenmiş veriler arasındaki farkı göstermek

DROP VIEW IF EXISTS dbo.vw_Data_Quality_Comparison;
GO

CREATE VIEW dbo.vw_Data_Quality_Comparison AS
SELECT 
    'Person' AS DataEntity,
    (SELECT COUNT(*) FROM dbo.stg_Person) AS StagingRecords,
    (SELECT COUNT(*) FROM dbo.Cleaned_Person) AS CleanedRecords,
    CAST(
        (SELECT COUNT(*) FROM dbo.Cleaned_Person) * 100.0 / 
        NULLIF((SELECT COUNT(*) FROM dbo.stg_Person), 0)
        AS DECIMAL(5,2)
    ) AS CleaningSuccessRate,
    (SELECT COUNT(*) 
     FROM dbo.stg_Person 
     WHERE FirstName IS NULL OR LastName IS NULL) AS RejectedRecords

UNION ALL

SELECT 
    'Address' AS DataEntity,
    (SELECT COUNT(*) FROM dbo.stg_Address) AS StagingRecords,
    (SELECT COUNT(*) FROM dbo.Cleaned_Address) AS CleanedRecords,
    CAST(
        (SELECT COUNT(*) FROM dbo.Cleaned_Address) * 100.0 / 
        NULLIF((SELECT COUNT(*) FROM dbo.stg_Address), 0)
        AS DECIMAL(5,2)
    ) AS CleaningSuccessRate,
    (SELECT COUNT(*) 
     FROM dbo.stg_Address 
     WHERE AddressLine1 IS NULL OR City IS NULL) AS RejectedRecords

UNION ALL

SELECT 
    'Phone' AS DataEntity,
    (SELECT COUNT(*) FROM dbo.stg_PersonPhone) AS StagingRecords,
    (SELECT COUNT(*) FROM dbo.Cleaned_PersonPhone) AS CleanedRecords,
    CAST(
        (SELECT COUNT(*) FROM dbo.Cleaned_PersonPhone) * 100.0 / 
        NULLIF((SELECT COUNT(*) FROM dbo.stg_PersonPhone), 0)
        AS DECIMAL(5,2)
    ) AS CleaningSuccessRate,
    (SELECT COUNT(*) 
     FROM dbo.stg_PersonPhone 
     WHERE PhoneNumber IS NULL OR LEN(PhoneNumber) < 10) AS RejectedRecords;
GO

-- 2.10 Veri Migrasyonu Sonuç Raporu
-- Amacı: Tüm ETL işleminin özet sonuçlarını göstermek
SELECT 
    'ETL İşlemi Özet Raporu' AS ReportTitle,
    (SELECT COUNT(*) FROM dbo.stg_Person) AS TotalSourceRecords,
    (SELECT COUNT(*) FROM dbo.Cleaned_Person) AS TotalCleanedRecords,
    (SELECT COUNT(*) FROM dbo.Cleaned_EmailAddress WHERE IsVerified = 1) AS ValidatedEmailRecords,
    (SELECT COUNT(*) FROM dbo.DataQuality_Inconsistency WHERE ResolutionStatus = 'OPEN') AS OpenIssues,
    CAST((SELECT COUNT(*) FROM dbo.Cleaned_Person) * 100.0 / (SELECT COUNT(*) FROM dbo.stg_Person) AS DECIMAL(5,2)) AS DataQualityPercentage,
    GETDATE() AS ReportGeneratedDate

GO

-- 2.10a Detaylı ETL İşlem Raporu
-- Amacı: Her veri türü için ayrıntılı temizleme sonuçlarını göstermek
SELECT 
    'Person Temizleme' AS ProcessType,
    (SELECT COUNT(*) FROM dbo.stg_Person) AS TotalRecords,
    (SELECT COUNT(*) FROM dbo.Cleaned_Person) AS SuccessfulRecords,
    (SELECT COUNT(*) FROM dbo.stg_Person) - (SELECT COUNT(*) FROM dbo.Cleaned_Person) AS FailedRecords,
    CAST((SELECT COUNT(*) FROM dbo.Cleaned_Person) * 100.0 / (SELECT COUNT(*) FROM dbo.stg_Person) AS DECIMAL(5,2)) AS SuccessPercentage

UNION ALL

SELECT 
    'Address Temizleme' AS ProcessType,
    (SELECT COUNT(*) FROM dbo.stg_Address) AS TotalRecords,
    (SELECT COUNT(*) FROM dbo.Cleaned_Address) AS SuccessfulRecords,
    (SELECT COUNT(*) FROM dbo.stg_Address) - (SELECT COUNT(*) FROM dbo.Cleaned_Address) AS FailedRecords,
    CAST((SELECT COUNT(*) FROM dbo.Cleaned_Address) * 100.0 / (SELECT COUNT(*) FROM dbo.stg_Address) AS DECIMAL(5,2)) AS SuccessPercentage

UNION ALL

SELECT 
    'Phone Temizleme' AS ProcessType,
    (SELECT COUNT(*) FROM dbo.stg_PersonPhone) AS TotalRecords,
    (SELECT COUNT(*) FROM dbo.Cleaned_PersonPhone) AS SuccessfulRecords,
    (SELECT COUNT(*) FROM dbo.stg_PersonPhone) - (SELECT COUNT(*) FROM dbo.Cleaned_PersonPhone) AS FailedRecords,
    CAST((SELECT COUNT(*) FROM dbo.Cleaned_PersonPhone) * 100.0 / (SELECT COUNT(*) FROM dbo.stg_PersonPhone) AS DECIMAL(5,2)) AS SuccessPercentage

UNION ALL

SELECT 
    'Email Temizleme' AS ProcessType,
    (SELECT COUNT(*) FROM dbo.stg_EmailAddress) AS TotalRecords,
    (SELECT COUNT(*) FROM dbo.Cleaned_EmailAddress) AS SuccessfulRecords,
    (SELECT COUNT(*) FROM dbo.stg_EmailAddress) - (SELECT COUNT(*) FROM dbo.Cleaned_EmailAddress) AS FailedRecords,
    CAST((SELECT COUNT(*) FROM dbo.Cleaned_EmailAddress) * 100.0 / (SELECT COUNT(*) FROM dbo.stg_EmailAddress) AS DECIMAL(5,2)) AS SuccessPercentage

GO

-- 2.10b Veri Kalitesi Metrikleri Özeti
-- Amacı: Tüm temizleme işlemindeki kalite metriklerini sunmak
SELECT 
    'Genel Veri Kalitesi Özeti' AS MetricCategory,
    CAST(
        ((SELECT COUNT(*) FROM dbo.Cleaned_Person) + 
         (SELECT COUNT(*) FROM dbo.Cleaned_Address) + 
         (SELECT COUNT(*) FROM dbo.Cleaned_PersonPhone) + 
         (SELECT COUNT(*) FROM dbo.Cleaned_EmailAddress))
        * 100.0 / 
        ((SELECT COUNT(*) FROM dbo.stg_Person) + 
         (SELECT COUNT(*) FROM dbo.stg_Address) + 
         (SELECT COUNT(*) FROM dbo.stg_PersonPhone) + 
         (SELECT COUNT(*) FROM dbo.stg_EmailAddress))
        AS DECIMAL(5,2)
    ) AS OverallQualityPercentage,
    (SELECT COUNT(*) FROM dbo.DataQuality_Inconsistency WHERE ResolutionStatus = 'OPEN') AS TotalOpenIssues,
    (SELECT COUNT(*) FROM dbo.DataQuality_MissingData) AS TotalMissingDataReports,
    GETDATE() AS GeneratedDate

GO

-- 2.10c Hata ve Uyumsuzluk Detay Raporu
-- Amacı: Tespit edilen tüm hataları ve uyumsuzlukları listelemek
SELECT 
    InconsistencyID,
    SourceTable,
    RecordID,
    IssueDescription,
    InconsistencyType,
    DetectionDate,
    ResolutionStatus
FROM dbo.DataQuality_Inconsistency
ORDER BY DetectionDate DESC, ResolutionStatus

GO

-- 2.10d Eksik Veri Detay Raporu
-- Amacı: Hangi alanlarda ne kadar eksik veri olduğunu göstermek
SELECT 
    SourceTable,
    ColumnName,
    MissingRecordCount,
    TotalRecordCount,
    MissingPercentage,
    DetectionDate,
    CASE 
        WHEN MissingPercentage > 20 THEN 'KRITIK'
        WHEN MissingPercentage > 10 THEN 'UYARI'
        ELSE 'DÜŞÜK'
    END AS RiskLevel
FROM dbo.DataQuality_MissingData
ORDER BY MissingPercentage DESC

GO

-- 2.10e ETL İşlem Performans Özeti
-- Amacı: Tüm ETL işlemlerinin performans metrikleri
SELECT 
    ProcessName,
    COUNT(*) AS ExecutionCount,
    AVG(DATEDIFF(SECOND, StartTime, EndTime)) AS AvgDurationSeconds,
    MAX(DATEDIFF(SECOND, StartTime, EndTime)) AS MaxDurationSeconds,
    MIN(DATEDIFF(SECOND, StartTime, EndTime)) AS MinDurationSeconds,
    SUM(RecordsProcessed) AS TotalRecordsProcessed,
    SUM(RecordsSuccessful) AS TotalRecordsSuccessful
FROM dbo.ETL_ProcessLog
WHERE ProcessStatus = 'SUCCESS'
GROUP BY ProcessName
ORDER BY MAX(DATEDIFF(SECOND, StartTime, EndTime)) DESC

GO

-- ============================================================================
-- VERİ DOĞRULAMA SORGUSU
-- ============================================================================
-- Temizleme işleminin başarısını doğrulamak için kullanılacak

SELECT 
    'Staging Verisi' AS DataSource,
    COUNT(*) AS RecordCount,
    COUNT(CASE WHEN FirstName IS NULL THEN 1 END) AS MissingFirstName,
    COUNT(CASE WHEN LastName IS NULL THEN 1 END) AS MissingLastName
FROM dbo.stg_Person

UNION ALL

SELECT 
    'Temizlenmiş Veri' AS DataSource,
    COUNT(*) AS RecordCount,
    0 AS MissingFirstName,
    0 AS MissingLastName
FROM dbo.Cleaned_Person
GO

-- ============================================================================
-- ADRES VERİLERİ DOĞRULAMA SORGUSU
-- ============================================================================

SELECT 
    'Staging Adres' AS DataSource,
    COUNT(*) AS RecordCount,
    COUNT(CASE WHEN AddressLine1 IS NULL THEN 1 END) AS MissingAddress,
    COUNT(CASE WHEN City IS NULL THEN 1 END) AS MissingCity,
    COUNT(CASE WHEN PostalCode IS NULL THEN 1 END) AS MissingPostalCode
FROM dbo.stg_Address

UNION ALL

SELECT 
    'Temizlenmiş Adres' AS DataSource,
    COUNT(*) AS RecordCount,
    0 AS MissingAddress,
    0 AS MissingCity,
    0 AS MissingPostalCode
FROM dbo.Cleaned_Address
GO

-- ============================================================================
-- TELEFON VERİLERİ DOĞRULAMA SORGUSU
-- ============================================================================

SELECT 
    'Staging Telefon' AS DataSource,
    COUNT(*) AS RecordCount,
    COUNT(CASE WHEN PhoneNumber IS NULL THEN 1 END) AS MissingPhone,
    COUNT(CASE WHEN LEN(PhoneNumber) < 10 THEN 1 END) AS InvalidLength
FROM dbo.stg_PersonPhone

UNION ALL

SELECT 
    'Temizlenmiş Telefon' AS DataSource,
    COUNT(*) AS RecordCount,
    0 AS MissingPhone,
    0 AS InvalidLength
FROM dbo.Cleaned_PersonPhone
GO

-- ============================================================================
-- ETL HATA KONTROL RAPORU
-- ============================================================================

SELECT 
    ProcessName,
    COUNT(*) AS FailureCount,
    MAX(EndTime) AS LastFailureDate
FROM dbo.ETL_ProcessLog
WHERE ProcessStatus = 'FAILED'
GROUP BY ProcessName
ORDER BY FailureCount DESC
GO

-- ============================================================================
-- PROJE ÖZET İSTATİSTİKLERİ
-- ============================================================================

SELECT 
    'VERİ TEMİZLEME PROJE ÖZET' AS ProjectSummary,
    COUNT(DISTINCT 'PERSON_DATA') AS ProcessedDataTypes,
    (SELECT SUM(RecordsSuccessful) FROM dbo.ETL_ProcessLog WHERE ProcessStatus = 'SUCCESS') AS TotalSuccessfulRecords,
    (SELECT SUM(RecordsFailed) FROM dbo.ETL_ProcessLog WHERE ProcessStatus = 'FAILED') AS TotalFailedRecords,
    GETDATE() AS ProjectCompletionDate
GO



