# ChangeLog

## 0.4.0

- Selection is now included in Copy Path to Clipboard command.
- Fixed copy path to clipboard works when file isn't yet saved
- Fixed remove `data-tags` attribute when last tag is removed

## 0.3.1

- Fixed crash started in Atom 0.202.0 by temporarily disabling syntax highlighting of FoldingText's search field.

## 0.3.0

- You can now encode search, hoisted, expansion, and selection state in URL query parameters appended to the end of the paths that you open in Atom.

- *Edit > Copy Path* now encodes search and hoist state as URL query parameters appended to the end of the path.

- Changed to `em` sizing. You can now size the entire outline with:

        ft-outline-editor {
          font-size: 16px;
        }

- Fixed Command-F to focus search field in both outline and text modes

- Fix error loading on case sensitive file systems.

- Fixed fully expand/collapse keyboard shortcut.

## 0.2.2

- Fixed reading expansion state from OPML files

## 0.2.1

- Fixed problem where outlines couldn't load/save after you dragged and dropped another file on it to create a link.

## 0.2.0

- Added support for opening and editing `.opml` files
- Added commands to cut/copy/paste the current selection as OPML, TEXT, or the default FTML
- When you paste will try to detect in order FTML, OPML, in-line HTML, or fall back to TEXT
- Changed item path syntax to always expand attribute names from @name to @data-name.
- Fixed expanded state so that it is is preserved when you copy/paste items
- Fixed dropping file onto empty outline new creates link instead of error

## 0.1.4

- Fix error when clicking on item badge to filter.

## 0.1.2

- Fix "edit link" popover panel.

## 0.1.1

- Fix crashes that started in Atom 0.199 release.

## 0.1.0

- Faster loading and activation
- Added menus at Packages > FoldingText
- Better error reporting when loading invalid .ftml files.
- Make 'should' a dependency so specs run when installing from Atom.io
- Fixed bug that could sometimes make `escape` jump to search field when in text mode.

## 0.0.2

- Added tagging pop-up
- Added text formatting pop-up
- Select word under cursor on right click
- Remove item attribute when set to `undefined` or `null`
- Fixed opening of file path links that contain spaces
