import XCTest
@testable import Sekine

final class NotificationSoundTests: XCTestCase {

    // MARK: - isAvailable

    func testDefaultIsAlwaysAvailable() {
        XCTAssertTrue(NotificationSound.default.isAvailable)
    }

    func testChimeIsAvailableBecauseFileIsBundled() {
        // Sekine/Resources/Sounds/chime.caf gerçekten repoda var.
        XCTAssertTrue(NotificationSound.chime.isAvailable)
    }

    func testEzanIsNotAvailableUntilFileIsAdded() {
        // ezan.caf henüz bundle'da yok (bkz. NotificationSound.swift dokümantasyonu).
        // Dosya eklenince bu test kırılır — o an beklenen davranış budur, test
        // güncellenmeli (isAvailable artık true dönecektir).
        XCTAssertFalse(NotificationSound.ezan.isAvailable)
    }

    // MARK: - unSound(silent:) zaten dosya yoksa varsayılana düşüyor (regresyon)

    func testUnSoundFallsBackToDefaultWhenFileMissing() {
        XCTAssertNotNil(NotificationSound.ezan.unSound(silent: false))
    }

    func testUnSoundNilWhenSilent() {
        XCTAssertNil(NotificationSound.default.unSound(silent: true))
    }

    // MARK: - Migrasyon mantığı (AppSettings.migrateUnavailableSounds ile aynı kural)
    //
    // AppSettings init'i UserDefaults(suiteName: AppGroup.identifier) kullandığından ve
    // App Group entitlement'ı test hedefinde bulunmadığından burada doğrudan AppSettings
    // örnekleyip UserDefaults round-trip'i test etmiyoruz (o coupling bu testi kırılgan ve
    // gerçek dışı kılardı — hataya .standard'a sessizce düşer, App Group'u test etmez).
    // Bunun yerine, AppSettings.migrateUnavailableSounds içindeki KURALIN kendisini
    // (mevcut olmayan bir ses seçiliyse .default'a normalize et) NotificationSound
    // seviyesinde doğruluyoruz — asıl mantık `isAvailable` üzerine kurulu ve o yukarıda
    // test edildi. Regresyon riski: biri `isAvailable`'ı yanlış tanımlarsa (ör. sabit
    // `true` dönerse) bu testler kırılır ve migrasyon sessizce devre dışı kaldığı fark
    // edilir.
    func testMigrationRuleNormalizesUnavailableSoundToDefault() {
        func migrate(_ raw: String) -> String {
            guard let sound = NotificationSound(rawValue: raw), !sound.isAvailable else { return raw }
            return NotificationSound.default.rawValue
        }
        XCTAssertEqual(migrate(NotificationSound.ezan.rawValue), NotificationSound.default.rawValue)
        XCTAssertEqual(migrate(NotificationSound.chime.rawValue), NotificationSound.chime.rawValue)
        XCTAssertEqual(migrate(NotificationSound.default.rawValue), NotificationSound.default.rawValue)
    }

    // MARK: - AppSettings.migrateUnavailableSounds — uçtan uca (gerçek kod yolu)
    //
    // `AppSettings.init`, `UserDefaults(suiteName: AppGroup.identifier)` başarısız olursa
    // `.standard`'a düşer — ama SİMÜLATÖRDE app group suite'i, gerçek bir entitlement
    // eşleşmesi olmadan da genelde başarıyla açılır (Apple'ın bilinen bir simülatör
    // davranışı). Bu yüzden testin AppSettings ile AYNI store'u hedeflemesi gerekiyor;
    // `.standard`'a yazıp AppSettings'in sessizce app-group suite'ini okuduğu bir senaryoda
    // test hiçbir şeyi doğrulamadan "yeşil" görünürdü. Anahtar string'leri
    // AppSettings.Keys (private) ile birebir eşleşmeli — orada değişirse bu test kırılır,
    // bu kasıtlı bir coupling: persistence format testidir.
    private static let soundKey = "settings.sound"
    private static let perPrayerKey = "settings.perPrayerSounds"
    private static var store: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    override func tearDown() {
        Self.store.removeObject(forKey: Self.soundKey)
        Self.store.removeObject(forKey: Self.perPrayerKey)
        super.tearDown()
    }

    @MainActor
    func testAppSettingsMigratesEzanGeneralSoundToDefaultOnLoad() {
        Self.store.set(NotificationSound.ezan.rawValue, forKey: Self.soundKey)

        let settings = AppSettings()

        XCTAssertEqual(settings.notificationSound, NotificationSound.default.rawValue)
    }

    @MainActor
    func testAppSettingsMigratesEzanPerPrayerSoundOnLoad() {
        Self.store.set([Prayer.fajr.rawValue: NotificationSound.ezan.rawValue],
                        forKey: Self.perPrayerKey)

        let settings = AppSettings()

        XCTAssertNil(settings.perPrayerSounds[.fajr])
    }

    @MainActor
    func testAppSettingsLeavesAvailableSoundUntouchedOnLoad() {
        Self.store.set(NotificationSound.chime.rawValue, forKey: Self.soundKey)

        let settings = AppSettings()

        XCTAssertEqual(settings.notificationSound, NotificationSound.chime.rawValue)
    }
}
