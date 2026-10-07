class InputContext {

    static let shared = InputContext()

    var composeString: String = ""
    var matchedLength: [Int]? = []
    var currentIndex: Int = 0

    private var _candidates: [String] = []
    private var _numberedCandidates: [String] = []

    var candidates: [String] {
        get { return _candidates }
        set {
            _candidates = newValue
            _numberedCandidates = []
            for i in 0..<_candidates.count {
                _numberedCandidates.append("\(i+1). \(_candidates[i])")
            }
        }
    }

    var currentNumberedCandidate: String {
        if currentIndex >= 0 && currentIndex < _numberedCandidates.count {
            return _numberedCandidates[currentIndex]
        } else {
            return ""
        }
    }

    var numberedCandidates: [String] {
        return _numberedCandidates
    }

    func clean() {
        currentIndex = 0
        matchedLength = []
        composeString = ""
        _candidates = []
        _numberedCandidates = []
    }
}
