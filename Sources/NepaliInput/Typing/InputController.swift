import Foundation
import InputMethodKit

@objc(InputController)
class InputController: IMKInputController {

    /// The controller of the text field currently using this keyboard, if any.
    static weak var active: InputController?

    private static var sharedCandidates: IMKCandidates?
    private let candidates: IMKCandidates
    private var isActive: Bool = false

    override init!(server: IMKServer, delegate: Any, client inputClient: Any) {
        NSLog("\(#function)(\(inputClient))")

        // One panel for the whole process. IMK keeps an unretained reference to every
        // IMKCandidates created on the server and asks it `isVisible` when a keyboard
        // deactivates; a per-controller panel is freed with its controller, so that call
        // landed on a dead object (EXC_BAD_ACCESS in deactivateServer, issues #1 and #2).
        if Self.sharedCandidates == nil {
            Self.sharedCandidates = IMKCandidates(
                server: server, panelType: kIMKSingleRowSteppingCandidatePanel)
        }
        self.candidates = Self.sharedCandidates!

        super.init(server: server, delegate: delegate, client: inputClient)
    }

    override func client() -> (IMKTextInput & NSObjectProtocol)! {
        let c = super.client()
        return c
    }

    override func activateServer(_ sender: Any!) {
        guard let client = sender as? IMKTextInput else {
            return
        }

        NSLog("\(#function)(\(client))")

        isActive = true
        Self.active = self
        client.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.US")
    }

    override func deactivateServer(_ sender: Any) {
        guard let client = sender as? IMKTextInput else {
            return
        }

        NSLog("\(#function)(\(client))")

        isActive = false
        if Self.active === self { Self.active = nil }
        InputContext.shared.clean()
        if !UISettings.SystemUI {
            CandidatesWindow.shared.hide()
        }
    }

    func getAndRenderCandidates(_ compString: String) {

        DispatchQueue.global().async { [weak self] in

            let (candidates, matchedLength) = CloudInputEngine.shared.requestCandidatesSync(
                compString)

            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.isActive,
                      compString == InputContext.shared.composeString else {
                    return
                }

                InputContext.shared.candidates = candidates
                InputContext.shared.matchedLength = matchedLength

                // update candidates window
                if UISettings.SystemUI {
                    self.candidates.update()
                } else {
                    CandidatesWindow.shared.update(sender: self.client())
                }
            }
        }
    }

    func updateCandidatesWindow() {
        NSLog("\(#function)")

        let compString = InputContext.shared.composeString

        // set text at cursor
        let range = NSMakeRange(NSNotFound, NSNotFound)
        client().setMarkedText(compString, selectionRange: range, replacementRange: range)

        if UISettings.SystemUI {
            if compString.count > 0 {
                self.getAndRenderCandidates(compString)
                self.candidates.show(kIMKLocateCandidatesBelowHint)
            } else {
                self.candidates.hide()
            }
        } else {
            if compString.count > 0 {
                self.getAndRenderCandidates(compString)
                CandidatesWindow.shared.show()
            } else {
                InputContext.shared.currentIndex = 0
                CandidatesWindow.shared.hide()
            }
        }
    }
    

    func commitComposedString(client sender: Any!) {
        let compString = InputContext.shared.composeString

        client().insertText(compString, replacementRange: NSMakeRange(NSNotFound, NSNotFound))

        InputContext.shared.clean()
        self.candidates.update()
        self.candidates.hide()

        if !UISettings.SystemUI {
            CandidatesWindow.shared.update(sender: client())
        }
    }

    func commitCandidate(client sender: Any!) {
        NSLog("\(#function)")

        let compString = InputContext.shared.composeString
        let index = InputContext.shared.currentIndex
        let candidate = InputContext.shared.candidates[index]
        let matched = InputContext.shared.matchedLength?[index] ?? compString.count


        let fromIndex = compString.index(
            compString.endIndex, offsetBy: matched - compString.count)
        let remain = compString[fromIndex...]


        client().insertText(candidate, replacementRange: NSMakeRange(0, matched))
        let range = NSMakeRange(NSNotFound, NSNotFound)
        client().setMarkedText(remain, selectionRange: range, replacementRange: range)

        InputContext.shared.clean()
        InputContext.shared.composeString = String(remain)
        updateCandidatesWindow()

        if !UISettings.SystemUI {
            CandidatesWindow.shared.update(sender: client())
        }
    }

    override func candidates(_ sender: Any!) -> [Any]! {
        NSLog("\(#function)")

        return InputContext.shared.candidates
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        NSLog("\(#function)")

        let candidate = candidateString?.string ?? ""
        let id = InputContext.shared.candidates.firstIndex(of: candidate) ?? 0

        InputContext.shared.currentIndex = id
        commitCandidate(client: self.client())
    }

    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        NSLog("\(#function)")

        let candidate = candidateString?.string ?? ""
        let id = InputContext.shared.candidates.firstIndex(of: candidate) ?? 0

        InputContext.shared.currentIndex = id
    }

    override func commitComposition(_ sender: Any!) {
        NSLog("\(#function)")
    }

    override func updateComposition() {
        NSLog("\(#function)")
    }

    override func cancelComposition() {
        NSLog("\(#function)")
    }

    override func selectionRange() -> NSRange {
        NSLog("\(#function)")

        return NSMakeRange(NSNotFound, NSNotFound)
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask([.keyDown, .flagsChanged]).rawValue)
    }

    override func menu() -> NSMenu! {
        let menu = NSMenu()
        DictationController.shared.populate(menu, target: self, action: #selector(dictationMenuAction(_:)))
        return menu
    }

    /// Input-method menu actions arrive here with a dictionary describing the chosen item.
    @objc func dictationMenuAction(_ sender: Any) {
        let item = (sender as? [String: Any])?[kIMKCommandMenuItemName] as? NSMenuItem ?? sender as? NSMenuItem
        if let item { DictationController.shared.menuAction(item) }
    }

    /// Types dictated text straight into the client, finishing any word being composed first.
    func insertDictation(_ text: String) -> Bool {
        guard isActive, let client = client() else { return false }
        if !InputContext.shared.composeString.isEmpty {
            commitComposedString(client: client)
        }
        client.insertText(text, replacementRange: NSMakeRange(NSNotFound, NSNotFound))
        return true
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        // Right Option hold-to-talk works here even without Accessibility.
        DictationController.shared.hotkey.feed(event)

        // ⌘ and ⌃ shortcuts are handled by the app before they reach us as key events, so the
        // modifier going down is our only cue that the word being typed is over.
        if event.type == .flagsChanged,
           !event.modifierFlags.intersection([.command, .control]).isEmpty,
           !InputContext.shared.composeString.isEmpty {
            commitComposedString(client: sender)
        }

        if event.type == NSEvent.EventType.keyDown {
            //check if the key is a modifier key
            if event.modifierFlags.contains(NSEvent.ModifierFlags.command) ||
                event.modifierFlags.contains(NSEvent.ModifierFlags.control) ||
                event.modifierFlags.contains(NSEvent.ModifierFlags.option) ||
                event.modifierFlags.contains(NSEvent.ModifierFlags.shift)
            {
                // A shortcut (⌘A, ⌃…, ⌥…) ends the word being typed; otherwise the stale
                // composition would swallow the next Delete/Return after the shortcut.
                if !event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command),
                   !InputContext.shared.composeString.isEmpty {
                    commitComposedString(client: sender)
                }
                return false
            }
            guard let inputString = event.characters, let key = inputString.first else {
                return false
            }

            if key.isLetter {
                InputContext.shared.composeString.append(inputString)
                updateCandidatesWindow()
                return true
            }

            else if key.isNumber {
                let keyValue = Int(key.hexDigitValue!)
                let count = InputContext.shared.candidates.count

                if (count > 0) && (keyValue > 0) && (keyValue <= count) {
                    InputContext.shared.currentIndex = keyValue - 1
                    commitCandidate(client: sender)
                    return true
                }
                else {
                    InputContext.shared.composeString.append(inputString)
                    updateCandidatesWindow()
                    return true
                }
            }

            // Handle Purnabiram (|)
            else if key == "/" {
                client().insertText("।", replacementRange: NSMakeRange(NSNotFound, NSNotFound))
                return true
            }

            // Handle Devanagari numbers (०-९)
            else if event.modifierFlags.contains(NSEvent.ModifierFlags.option) && key.isNumber {
                let devanagariNumbers = ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"]
                let keyValue = Int(key.hexDigitValue!)
                if keyValue >= 0 && keyValue <= 9 {
                    client().insertText(devanagariNumbers[keyValue], replacementRange: NSMakeRange(NSNotFound, NSNotFound))
                    return true
                }
            }

            else if event.keyCode == kVK_LeftArrow || event.keyCode == kVK_RightArrow {

                if event.keyCode == kVK_LeftArrow && InputContext.shared.currentIndex > 0 {
                    InputContext.shared.currentIndex -= 1
                }

                if event.keyCode == kVK_RightArrow
                    && InputContext.shared.currentIndex < InputContext.shared.candidates.count
                        - 1
                {
                    InputContext.shared.currentIndex += 1
                }

                if UISettings.SystemUI {
                    self.candidates.interpretKeyEvents([event])
                } else {
                    // keep the marked text unchanged
                    let compString = InputContext.shared.composeString
                    let range = NSMakeRange(NSNotFound, NSNotFound)
                    self.client().setMarkedText(
                        compString, selectionRange: range, replacementRange: range)
                    CandidatesWindow.shared.update(sender: self.client())
                }

                return true
            }

            else if event.keyCode == kVK_ANSI_Equal {
                self.candidates.pageDown(sender)
                return true
            }

            else if event.keyCode == kVK_ANSI_Minus {
                self.candidates.pageUp(sender)
                return true
            }

            else if event.keyCode == kVK_Delete && InputContext.shared.composeString.count > 0 {
                InputContext.shared.composeString.removeLast()
                updateCandidatesWindow()
                return true
            }

            else if (event.keyCode == kVK_Shift)
                && InputContext.shared.composeString.count > 0
            {
                commitComposedString(client: sender)
                return true
            }
            
            else if event.keyCode == kVK_Space {
                if InputContext.shared.candidates.count > 0 {
                    let space = " "
                     commitCandidate(client: sender)
                    client().insertText(space, replacementRange: NSMakeRange(NSNotFound, NSNotFound))
                    
                    InputContext.shared.clean()
                    self.candidates.update()
                    self.candidates.hide()
                    
                    if !UISettings.SystemUI {
                        CandidatesWindow.shared.update(sender: client())
                    }
                    
                    return true
                }
            }


            else if (event.keyCode == kVK_Return) && InputContext.shared.candidates.count > 0 {
                commitCandidate(client: sender)
                return true
            }

            else if event.keyCode == kVK_Escape {
                InputContext.shared.clean()
                self.candidates.update()
                self.candidates.hide()
                return true
            }

            else {
                commitComposedString(client: sender)
                return false
            }
        }

        return false
    }
}