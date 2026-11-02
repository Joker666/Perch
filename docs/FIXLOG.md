# Fix log

Bugs that were hard to find, and the rule each one taught. Newest first.

## 2026-11-02: build.sh failed after an edit to a comment

After an edit that changed only a comment, SwiftPM did not relink the binary,
because the compiled code was the same. build.sh saw a source file newer than
the binary and reported a failed build. Found while adding a `// grid: ok` note.
Fix: when the binary looks older, build.sh builds again, and fails only when
that build prints an error.

Rule: A check that compares file dates must allow a build that had nothing to do.

## 2026-11-02: Many adds at one spot put todos in the wrong order

After about 30 adds in one place (Return in the middle of the List, or
`perch todos add --after`), new todos went to the wrong position. `save()`
renumbered the cached `todos` array, which every caller reloads only after
saving. The todo just added was not in it, so it kept its old order value
while the others got new ones. Found during the 2026-11-02 architecture review.
Fix: `save()` fetches the open todos again before it checks and renumbers them.
Check: self-test "40 adds at one spot keep their order".

Rule: Code that runs inside a change reads the store, never an array that is
reloaded after the change.
