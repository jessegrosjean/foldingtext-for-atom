# ChangeLog

## 0.2.1

- Fixed problem where outlines couldn't load/save after you dragged and dropped another file on it to create a link.

## 0.2.0

- Added support for opening and editing `.opml` files
- Added commands to cut/copy/paste the current selection as OPML, TEXT, or the default FTML
- When you paste will try to detect in order FTML, OPML, Inline HTML, or fallback to TEXT
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

- Added tagging popup
- Added text formatting popup
- Select word under cursor on right click
- Remove item attribute when set to `undefined` or `null`
- Fixed opening of file path links that contain spaces
