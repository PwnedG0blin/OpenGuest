import XCTest
@testable import StratovoCore

final class LocalizationTests: XCTestCase {
    func testSystemLanguageRegionsAndUnsupportedFallback() {
        let cases = ["de-DE":"de", "en-GB":"en", "fr-CA":"fr", "es-MX":"es", "it-IT":"it", "pt-BR":"pt", "nl-NL":"nl", "pl-PL":"pl", "tr-TR":"tr", "uk-UA":"uk", "ar-SA":"ar", "zh-CN":"zh-Hans", "ja-JP":"ja", "ko-KR":"ko"]
        for (input, expected) in cases {
            XCTAssertEqual(L10n.resolve(preference: "system", preferredLanguages: [input]), expected)
        }
        XCTAssertEqual(L10n.resolve(preference: "system", preferredLanguages: ["sv-SE", "fr-FR"]), "fr")
        XCTAssertEqual(L10n.resolve(preference: "system", preferredLanguages: ["sv-SE"]), "en")
        XCTAssertEqual(L10n.resolve(preference: "ja", preferredLanguages: ["de-DE"]), "ja")
    }
    func testAllFourteenPackagedLanguageFoldersAreReadable() {
        let expected = ["de":"Abbrechen", "en":"Cancel", "fr":"Annuler", "es":"Cancelar", "it":"Annulla", "pt":"Cancelar", "nl":"Annuleren", "pl":"Anuluj", "tr":"İptal", "uk":"Скасувати", "ar":"إلغاء", "zh-Hans":"取消", "ja":"キャンセル", "ko":"취소"]
        XCTAssertEqual(Set(L10n.languages.map(\.code)), Set(expected.keys))
        for (code, translation) in expected { XCTAssertEqual(L10n.text("Abbrechen", language: code), translation, code) }
    }
    func testEnglishFallbackForMissingTechnicalTranslation() {
        XCTAssertEqual(L10n.text("H.264-Konfiguration nicht unterstützt.", language: "fr"), "Unsupported H.264 configuration.")
        XCTAssertEqual(L10n.text("untranslated.log.marker", language: "ja"), "untranslated.log.marker")
    }
    func testInterpolationKeepsUserDataLiteralAndSupportsReordering() {
        let path = "/Volumes/Drive {2}/テスト"
        let free = "7 GiB"
        let reserve = 10
        XCTAssertEqual(L10n.message("Am gewählten Speicherort \(path) sind nur \(free) frei. Für diesen Start sind mindestens \(reserve) GB Reserve vorgesehen.", language: "en"),
                       "Only 7 GiB available at /Volumes/Drive {2}/テスト. At least 10 GB of free space is required for this launch.")
        XCTAssertEqual(L10n.message("Android \(17) laden und installieren …", language: "en"), "Download and install Android 17 …")
    }
}
