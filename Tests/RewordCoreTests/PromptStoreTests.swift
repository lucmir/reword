import XCTest
@testable import RewordCore

final class PromptStoreTests: XCTestCase {
    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("presets.json")
    }

    func testSeedsDefaultPresetsOnFirstLoad() {
        let store = PromptStore(fileURL: tempURL)
        XCTAssertEqual(store.presets.count, 5)
        XCTAssertEqual(store.presets.filter(\.isDefault).count, 1)
        XCTAssertEqual(store.defaultPreset.name, "Improve writing")
    }

    func testPersistsAcrossInstances() {
        let store = PromptStore(fileURL: tempURL)
        let preset = Preset(id: UUID(), name: "Pirate", prompt: "Rewrite as a pirate.", isDefault: false)
        store.add(preset)

        let reloaded = PromptStore(fileURL: tempURL)
        XCTAssertTrue(reloaded.presets.contains(preset))
    }

    func testSetDefaultIsExclusive() {
        let store = PromptStore(fileURL: tempURL)
        let target = store.presets[2]
        store.setDefault(id: target.id)
        XCTAssertEqual(store.presets.filter(\.isDefault).map(\.id), [target.id])
        XCTAssertEqual(store.defaultPreset.id, target.id)
    }

    func testDeleteReassignsDefaultWhenDefaultDeleted() {
        let store = PromptStore(fileURL: tempURL)
        let original = store.defaultPreset
        store.delete(id: original.id)
        XCTAssertFalse(store.presets.contains { $0.id == original.id })
        XCTAssertEqual(store.presets.filter(\.isDefault).count, 1)
    }

    func testUpdateEditsInPlace() {
        let store = PromptStore(fileURL: tempURL)
        var preset = store.presets[0]
        preset.prompt = "New prompt text."
        store.update(preset)
        XCTAssertEqual(PromptStore(fileURL: tempURL).presets[0].prompt, "New prompt text.")
    }

    func testCannotDeleteLastPreset() {
        let store = PromptStore(fileURL: tempURL)
        for preset in store.presets.dropFirst() {
            store.delete(id: preset.id)
        }
        XCTAssertEqual(store.presets.count, 1)
        let last = store.presets[0]
        store.delete(id: last.id)
        XCTAssertEqual(store.presets, [last])
        XCTAssertEqual(store.defaultPreset.id, last.id)
    }

    func testSetDefaultWithUnknownIDIsNoOp() {
        let store = PromptStore(fileURL: tempURL)
        let before = store.presets
        store.setDefault(id: UUID())
        XCTAssertEqual(store.presets, before)
        XCTAssertEqual(store.presets.filter(\.isDefault).count, 1)
    }

    func testUpdatePreservesStoredDefaultFlag() {
        let store = PromptStore(fileURL: tempURL)
        let target = store.presets[1]
        store.setDefault(id: target.id)

        var stale = target           // simulates the editor's stale copy
        stale.prompt = "edited"      // isDefault is still false in the copy
        store.update(stale)

        XCTAssertEqual(store.defaultPreset.id, target.id)
        XCTAssertEqual(store.presets.filter(\.isDefault).count, 1)
        XCTAssertEqual(store.presets[1].prompt, "edited")
    }
}
