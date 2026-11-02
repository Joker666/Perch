import Foundation
import Testing
@testable import PerchKit

@Test("Clean todo text", arguments: [
    ("Buy milk", "Buy milk"),
    ("  Buy   milk \n", "Buy milk"),
    ("Line\nbreak", "Line break"),
])
func cleans(_ input: String, expected: String) {
    #expect(TodoText.clean(input) == expected)
}

@Test("Empty text is no todo", arguments: ["", "   ", "\n\t"])
func emptyText(_ input: String) {
    #expect(TodoText.clean(input) == nil)
}

@Test func orderBetweenNeighbors() {
    #expect(TodoOrder.between(0, 1024) == 512)
    #expect(TodoOrder.between(2048, nil) == 2048 + TodoOrder.step)
    #expect(TodoOrder.between(nil, 0) == -TodoOrder.step)
    #expect(TodoOrder.between(nil, nil) == 0)
}

@Test func crowdedOrders() {
    #expect(TodoOrder.isCrowded([0, 1e-9]))
    #expect(!TodoOrder.isCrowded([0, 1, 2]))
    #expect(TodoOrder.renumbered(count: 3) == [0, 1024, 2048])
}

@Test func movingKeepsRelativeOrder() {
    let list = ["a", "b", "c", "d", "e"]
    #expect(TodoOrder.moving(list, indices: [1], to: 4) == ["a", "c", "d", "b", "e"])
    #expect(TodoOrder.moving(list, indices: [3], to: 0) == ["d", "a", "b", "c", "e"])
    #expect(TodoOrder.moving(list, indices: [1, 2], to: 5) == ["a", "d", "e", "b", "c"])
    #expect(TodoOrder.moving(list, indices: [4], to: 5) == list)
}

@Test func selectionMovesAndExtends() {
    let list = [1, 2, 3, 4]
    var s = ListSelection(2)
    s = s.moved(by: 1, extend: true, in: list)
    #expect(s.ids(in: list) == [2, 3])
    s = s.moved(by: -2, extend: true, in: list)
    #expect(s.ids(in: list) == [1, 2])
    s = s.moved(by: 1, extend: false, in: list)
    #expect(s.ids(in: list) == [2])
    #expect(ListSelection(4).moved(by: 1, extend: false, in: list).cursor == 4)
    #expect(ListSelection(1).extended(to: 3).ids(in: list) == [1, 2, 3])
    #expect(ListSelection(9).ids(in: list).isEmpty)
}

@Test func neighborAfterRemoving() {
    let list = [1, 2, 3, 4]
    #expect(list.neighbor(afterRemoving: [2, 3]) == 4)
    #expect(list.neighbor(afterRemoving: [4]) == 3)
    #expect(list.neighbor(afterRemoving: [1, 2, 3, 4]) == nil)
}

@Test func panelHeightFitsRows() {
    let m = PanelMetrics(fontSize: 14)
    #expect(m.rowHeight == 36)
    #expect(m.circleSize == 18)
    #expect(m.height(rows: 3) == 4 + 36 + 4 + 3 * 36 + 16)
    #expect(m.height(rows: 100, maxHeight: 500) == 500)
    #expect(PanelMetrics.clampWidth(100) == PanelMetrics.minWidth)
    #expect(PanelMetrics.clampWidth(900) == PanelMetrics.maxWidth)
}

@Test func rubberBandResists() {
    #expect(PanelMetrics.rubberBand(0) == 0)
    #expect(PanelMetrics.rubberBand(20) < 20)
    #expect(PanelMetrics.rubberBand(10_000) < 60)
    #expect(PanelMetrics.rubberBand(-20) == -PanelMetrics.rubberBand(20))
}

@Test func keyComboSymbolsUseApplesOrder() {
    let all = KeyCombo(keyCode: 40, modifiers: KeyCombo.command | KeyCombo.shift | KeyCombo.option | KeyCombo.control)
    #expect(all.modifierSymbols == "⌃⌥⇧⌘")
    #expect(KeyCombo.defaultShowHide.modifierSymbols == "⌃⌥")
    #expect(KeyCombo.specialName(49) == "Space")
    #expect(KeyCombo.specialName(122) == "F1")
    #expect(KeyCombo.specialName(0) == nil)
}

@Test func globalShortcutsNeedAModifier() {
    #expect(!KeyCombo(keyCode: 0, modifiers: 0).isAllowedGlobally)
    #expect(!KeyCombo(keyCode: 0, modifiers: KeyCombo.shift).isAllowedGlobally)
    #expect(KeyCombo(keyCode: 0, modifiers: KeyCombo.option).isAllowedGlobally)
    #expect(KeyCombo(keyCode: 96, modifiers: 0).isAllowedGlobally)
}

@Test func keyComboDropsOtherFlagsAndRoundTrips() throws {
    let combo = KeyCombo(keyCode: 49, modifiers: KeyCombo.control | 0x4000)
    #expect(combo.modifiers == KeyCombo.control)
    let data = try JSONEncoder().encode(combo)
    #expect(try JSONDecoder().decode(KeyCombo.self, from: data) == combo)
}

// MARK: Focus rules

@Test func neighborStopsAtTheEnds() {
    let ids = [1, 2, 3]
    #expect(FocusRules.neighbor(of: 2, step: 1, in: ids) == 3)
    #expect(FocusRules.neighbor(of: 2, step: -1, in: ids) == 1)
    #expect(FocusRules.neighbor(of: 1, step: -1, in: ids) == nil)
    #expect(FocusRules.neighbor(of: 3, step: 1, in: ids) == nil)
    #expect(FocusRules.neighbor(of: 9, step: 1, in: ids) == nil)
}

@Test func cursorTypesInListAndSelectsInArchive() {
    let ids = [1, 2, 3]
    #expect(FocusRules.cursor(from: .none, step: 1, in: ids, isList: true) == .editing(1))
    #expect(FocusRules.cursor(from: .none, step: -1, in: ids, isList: true) == .editing(3))
    #expect(FocusRules.cursor(from: .none, step: 1, in: ids, isList: false) == .selection(ListSelection(1)))
    let range = RowFocus.selection(ListSelection(anchor: 1, cursor: 2))
    #expect(FocusRules.cursor(from: range, step: 1, in: ids, isList: true) == .editing(3))
    #expect(FocusRules.cursor(from: .none, step: 1, in: [Int](), isList: true) == nil)
}

@Test func shiftArrowsExtendFromTheTypedRow() {
    let ids = [1, 2, 3]
    #expect(FocusRules.extending(.none, step: 1, in: ids) == .selection(ListSelection(1)))
    #expect(FocusRules.extending(.none, step: -1, in: ids) == .selection(ListSelection(3)))
    #expect(FocusRules.extending(.editing(2), step: 1, in: ids) == .selection(ListSelection(anchor: 2, cursor: 3)))
    let range = RowFocus.selection(ListSelection(anchor: 2, cursor: 3))
    #expect(FocusRules.extending(range, step: -2, in: ids) == .selection(ListSelection(anchor: 2, cursor: 1)))
    // A new row left empty is gone when the edit ends, so there is nothing to extend from.
    #expect(FocusRules.extending(.editing(9), step: 1, in: ids) == nil)
    #expect(FocusRules.extending(RowFocus<Int>.none, step: 1, in: []) == nil)
}

@Test func clicksTypeOrSelect() {
    #expect(FocusRules.click(2, extend: false, from: .none, isList: true) == .editing(2))
    #expect(FocusRules.click(2, extend: false, from: .editing(1), isList: false) == .selection(ListSelection(2)))
    #expect(FocusRules.click(3, extend: true, from: .editing(1), isList: true) == .selection(ListSelection(anchor: 1, cursor: 3)))
    let range = RowFocus.selection(ListSelection(anchor: 2, cursor: 3))
    #expect(FocusRules.click(1, extend: true, from: range, isList: true) == .selection(ListSelection(anchor: 2, cursor: 1)))
    #expect(FocusRules.click(2, extend: true, from: .none, isList: true) == .selection(ListSelection(2)))
}

@Test func removingSelectsTheNextRow() {
    let ids = [1, 2, 3, 4]
    #expect(FocusRules.afterRemoving([2, 3], from: ids) == .selection(ListSelection(4)))
    #expect(FocusRules.afterRemoving([4], from: ids) == .selection(ListSelection(3)))
    #expect(FocusRules.afterRemoving([1, 2, 3, 4], from: ids) == .none)
}

@Test func focusNamesItsRows() {
    let ids = [1, 2, 3]
    #expect(RowFocus.editing(2).editingID == 2)
    #expect(RowFocus.selection(ListSelection(2)).editingID == nil)
    #expect(RowFocus.editing(2).selectedIDs(in: ids) == [2])
    #expect(RowFocus.selection(ListSelection(anchor: 3, cursor: 1)).selectedIDs(in: ids) == [1, 2, 3])
    #expect(RowFocus<Int>.none.selectedIDs(in: ids).isEmpty)
}

// MARK: Dragging to reorder

@Test func destinationAccountsForTheShift() {
    let list = ["a", "b", "c", "d"]
    #expect(TodoOrder.destination(from: 0, to: 2) == 3)
    #expect(TodoOrder.moving(list, indices: [0], to: TodoOrder.destination(from: 0, to: 2)) == ["b", "c", "a", "d"])
    #expect(TodoOrder.destination(from: 3, to: 1) == 1)
    #expect(TodoOrder.moving(list, indices: [3], to: TodoOrder.destination(from: 3, to: 1)) == ["a", "d", "b", "c"])
}

@Test func dragTargetFollowsWholeRows() {
    let drag = DragReorder(from: 1, translation: 80, rowHeight: 36, count: 5)
    #expect(drag.target == 3)
    #expect(DragReorder(from: 1, translation: 17, rowHeight: 36, count: 5).target == 1)
    #expect(DragReorder(from: 1, translation: -500, rowHeight: 36, count: 5).target == 0)
    #expect(DragReorder(from: 1, translation: 500, rowHeight: 36, count: 5).target == 4)
    #expect(drag.destination == 4)
}

@Test func passedRowsMakeRoom() {
    let down = DragReorder(from: 1, translation: 80, rowHeight: 36, count: 5)
    #expect(down.offset(at: 1) == 80)
    #expect(down.offset(at: 2) == -36)
    #expect(down.offset(at: 3) == -36)
    #expect(down.offset(at: 0) == 0)
    #expect(down.offset(at: 4) == 0)
    let up = DragReorder(from: 3, translation: -72, rowHeight: 36, count: 5)
    #expect(up.offset(at: 1) == 36)
    #expect(up.offset(at: 2) == 36)
    #expect(up.offset(at: 4) == 0)
}

// MARK: Shortcuts in the menus

@Test func shortcutMatchesMenuItems() {
    let commandN = KeyCombo(keyCode: 45, modifiers: KeyCombo.command)
    #expect(commandN.matches(keyEquivalent: "n", modifiers: KeyCombo.command, layoutCharacter: "n"))
    #expect(!commandN.matches(keyEquivalent: "n", modifiers: KeyCombo.command | KeyCombo.option, layoutCharacter: "n"))
    #expect(!commandN.matches(keyEquivalent: "m", modifiers: KeyCombo.command, layoutCharacter: "n"))
    // An uppercase key equivalent means Shift, as AppKit draws ⇧⌘Z for "Z".
    let redo = KeyCombo(keyCode: 6, modifiers: KeyCombo.command | KeyCombo.shift)
    #expect(redo.matches(keyEquivalent: "Z", modifiers: KeyCombo.command, layoutCharacter: "z"))
    #expect(redo.matches(keyEquivalent: "z", modifiers: KeyCombo.command | KeyCombo.shift, layoutCharacter: "z"))
}

@Test func shortcutMatchesKeysWithoutLetters() {
    let up = KeyCombo(keyCode: 126, modifiers: KeyCombo.command | KeyCombo.option)
    #expect(up.matches(keyEquivalent: "\u{F700}", modifiers: KeyCombo.command | KeyCombo.option, layoutCharacter: nil))
    let complete = KeyCombo(keyCode: 36, modifiers: KeyCombo.command)
    #expect(complete.matches(keyEquivalent: "\r", modifiers: KeyCombo.command, layoutCharacter: nil))
    let delete = KeyCombo(keyCode: 51, modifiers: KeyCombo.command)
    #expect(delete.matches(keyEquivalent: "\u{8}", modifiers: KeyCombo.command, layoutCharacter: nil))
    #expect(!delete.matches(keyEquivalent: "\r", modifiers: KeyCombo.command, layoutCharacter: nil))
}

// MARK: Window placement

@Test func windowsStayOnScreen() {
    let visible = CGRect(x: 0, y: 67, width: 2560, height: 1343) // a screen with the Dock at the bottom
    let fits = CGRect(x: 1044, y: 600, width: 520, height: 374)
    #expect(WindowPlacement.keptOnScreen(fits, in: visible) == fits)
    // Grown down past the Dock: moves up just enough.
    let low = CGRect(x: 1044, y: -100, width: 520, height: 480)
    #expect(WindowPlacement.keptOnScreen(low, in: visible) == CGRect(x: 1044, y: 67, width: 520, height: 480))
    // Past the right edge and under the menu bar.
    let corner = CGRect(x: 2400, y: 1200, width: 520, height: 400)
    #expect(WindowPlacement.keptOnScreen(corner, in: visible) == CGRect(x: 2040, y: 1010, width: 520, height: 400))
    // Taller than the screen: the top edge stays on screen.
    let tall = CGRect(x: 100, y: 0, width: 520, height: 2000)
    #expect(WindowPlacement.keptOnScreen(tall, in: visible).maxY == visible.maxY)
}
