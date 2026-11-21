import SwiftUI

/// The page's list when its search hides every row: "No <items> match" with Clear Search, which empties the toolbar's field
/// (`FrameModel.search`). Every searchable page draws this one in place of its list.
struct FrameSearchNoMatch: View {
    /// Plural, as the field names them ("skills").
    let items: String
    let search: FrameSearch

    var body: some View {
        SearchNoMatchState(title: FrameSearchWording.noMatchTitle(items), text: FrameSearchWording.noMatchText(search.text)) {
            search.clear()
        }
    }
}
