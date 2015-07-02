Map Birch outline to "native" text editor.

Stop writing own editor. Instead use existing editor such as Atom, CodeMirror, or NSTextView. But allow for features like folding, filtering, and outline structure API for manipulating content. Use .ftml as serialization format.

To make this work will need to:

1. Load .ftml into Outline.
2. Generate "flat" view of all visible items using line manager
3. Map from this flat item view to editor using:
  - Tabs to represent indentation level past hoisted item
  - Marked ranges for formatting, bold, italic, links
  - Paragraph styling for types, heading, etc


Replace existing OutlineEditor folder with new OutlineEdtor that maps an outline to a text-buffer. This new OutlineEditor is responsible for mapping visible items to lines in text buffer, which a native text editor can then display and edit. First goal should be:

1. Load .ftml into Outline
2. Create OutlineEditor from Outline
3. Map OutlineEditor TextBuffer to Atom TextBuffer
4. Ignoring Attributes, display that TextBuffer and Edit the Outline by editing the buffer