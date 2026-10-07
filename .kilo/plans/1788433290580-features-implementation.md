> **Status: ✅ DONE — shipped in commit `4a7936a` (search, cross-bucket copy, multi-folder upload, drag-and-drop).**
> Root-level files missing from folder uploads were tracked and fixed separately in `.hermes/plans/2026-10-06_182351-fix-delete-and-folder-upload.md`.

# Implementation Plan: 4 Features

## Overview
Implement 4 requested features for the S3 Scout application:
1. Multiple folder/file selection for upload (single native dialog)
2. Drag and drop upload
3. Copy across different buckets
4. Client-side search/filter

---

## Feature 1: Multiple Folder & File Upload (Single Native Dialog)

### Current State
- `upload_button.dart` uses `FilePicker.platform.getDirectoryPath()` which only allows single folder selection
- Upload flow processes one folder at a time
- Project uses `file_picker: ^6.1.1`

### Dependency Upgrade
- **`pubspec.yaml`**: Upgrade `file_picker` from `^6.1.1` to `^12.2.0`
  - Version 12.2.0 introduces `FilePicker.platform.pickFileAndDirectoryPaths()` which opens a single native OS dialog allowing the user to select both files and directories simultaneously
  - Returns `Future<List<String>>` — a list of absolute paths (mix of file and directory paths)
  - Supports macOS, Windows, Linux

### Implementation
**File: `lib/widgets/upload_button.dart`**

1. **Replace `_uploadFolder` method** (line 204-327):
   - Replace `FilePicker.platform.getDirectoryPath()` with `FilePicker.platform.pickFileAndDirectoryPaths()`
   - This opens a single native OS picker where the user can select multiple files AND multiple folders simultaneously
   - Returns `List<String>` of absolute paths

2. **UI Flow**:
   - User clicks "Upload Files & Folders" (rename from "Upload Folder")
   - Single native OS file picker dialog opens
   - User selects any combination of files and folders (using Cmd/Ctrl+click or Shift+click)
   - Dialog closes, upload begins immediately
   - Progress dialog shows overall progress across all selected items
   - Files are uploaded directly; folders are uploaded recursively preserving structure

3. **Processing Logic**:
   - Iterate through returned paths
   - For each path, check `FileSystemEntity.typeSync(path)`:
     - If `FileSystemEntityType.file` → upload as individual file (like `_uploadFiles`)
     - If `FileSystemEntityType.directory` → upload recursively (like current `_uploadFolder` logic)
   - Count total files across all selections for progress tracking
   - Preserve folder structure for directory uploads (same as current logic)
   - For individual files, upload to current prefix with just the filename

4. **Update bottom sheet option** (line 54-61):
   - Rename "Upload Folder" → "Upload Files & Folders"
   - Update subtitle to "Select files and folders to upload"
   - Update icon to `Icons.folder_open` (keep same)

5. **Rename `_uploadFolder` → `_uploadFilesAndFolders`**:
   - Accept `List<String> paths` parameter
   - First pass: count total files (files + files inside directories)
   - Second pass: upload each item with progress tracking
   - Reuse existing content-type detection and upload logic

---

## Feature 2: Drag and Drop Upload

### Current State
- No drag-and-drop functionality exists
- Upload only via file picker button

### Implementation
**File: `lib/screens/browser_screen.dart`**

1. **Wrap ObjectList area with drag target**:
   - Import `dart:ui` for drag-drop support
   - Wrap the main content area (ObjectList) with `DragTarget<FileSystemEntity>`
   - Add visual feedback when dragging over (border/background change)

2. **Handle drop events**:
   - `onAccept`: Process dropped files/folders
   - `onWillAccept`: Validate file types
   - Show upload progress dialog after drop

**File: `lib/widgets/object_list.dart`**

3. **Alternative approach** (if DragTarget doesn't work well):
   - Use `GestureDetector` with `onDragUpdate`, `onDragEnd`
   - Track drag state in AppState
   - Show overlay when dragging detected

4. **Upload logic**:
   - Extract file paths from drop event
   - Reuse existing upload methods from `upload_button.dart`
   - Handle both files and folders

**Note**: Flutter desktop drag-drop support varies by platform. May need platform-specific code for macOS/Windows.

---

## Feature 3: Copy Across Buckets

### Current State
- `copyObject` API already supports cross-bucket copy (aws_service.dart:459-471)
- Move operation exists (app_state.dart:525-571) but no explicit "Copy" UI
- Move uses copy + delete pattern

### Implementation
**File: `lib/widgets/unified_action_bar.dart`**

1. **Add "Copy" button** (next to Move button, around line 239):
   - Icon: `Icons.content_copy`
   - Enabled when objects are selected
   - Opens copy destination dialog

2. **Copy Destination Dialog**:
   - Dropdown: Select destination bucket (populate from `appState.buckets`)
   - Text field: Destination prefix/path within bucket
   - Pre-fill with current bucket and prefix
   - "Copy" button triggers operation

**File: `lib/providers/app_state.dart`**

3. **Add `copySelected` method** (similar to `moveSelected`):
   ```dart
   Future<void> copySelected(String destBucket, String destPrefix) async {
     // For each selected object:
     // 1. If folder: recursively list all objects, copy each to new location
     // 2. If file: copy to new location
     // NO delete (unlike move)
     // Log tasks, show progress
   }
   ```

4. **Key differences from move**:
   - No delete operation after copy
   - Destination can be different bucket
   - Preserve metadata during copy

---

## Feature 4: Client-Side Search/Filter

### Current State
- No search functionality exists
- Objects loaded via `listObjects` with prefix/delimiter

### Implementation
**File: `lib/providers/app_state.dart`**

1. **Add search state**:
   - `_searchQuery: String` - Current search term
   - `_filteredObjects: List<S3Object>` - Filtered results
   - `searchObjects(String query)` method
   - `clearSearch()` method

2. **Filter logic**:
   - Filter `_objects` list by checking if object key contains search query (case-insensitive)
   - Update `_filteredObjects`
   - Notify listeners

**File: `lib/widgets/unified_action_bar.dart`**

3. **Add search field** (in action bar, around line 50):
   - TextField with search icon
   - Debounce input (300ms) to avoid excessive filtering
   - Clear button (X icon) when text is present
   - Placeholder: "Search files and folders..."

**File: `lib/widgets/object_list.dart`**

4. **Display filtered results**:
   - Check if `appState.searchQuery` is not empty
   - If searching: display `appState.filteredObjects`
   - If not searching: display `appState.objects`
   - Show "No results found" if filtered list is empty

5. **UI considerations**:
   - Search should work across current folder only (not recursive)
   - Clear search when navigating to different folder/bucket
   - Highlight matching text (optional enhancement)

---

## Implementation Order

**Recommended sequence** (minimizes dependencies):
1. **Feature 4: Search** - Independent, no dependencies on other features
2. **Feature 3: Copy across buckets** - Independent, builds on existing move logic
3. **Feature 1: Multiple folder upload** - Modifies upload_button.dart
4. **Feature 2: Drag and drop** - Most complex, may need platform testing

---

## Files to Modify

### Core Changes
- `lib/widgets/upload_button.dart` - Multiple folder selection
- `lib/widgets/unified_action_bar.dart` - Copy button + search field
- `lib/widgets/object_list.dart` - Display search results, drag-drop target
- `lib/providers/app_state.dart` - Search state, copySelected method
- `lib/screens/browser_screen.dart` - Drag-drop wrapper (if needed)

### No Changes Required
- `lib/services/aws_service.dart` - copyObject already supports cross-bucket
- `lib/models/` - No model changes needed
- `lib/services/` - No service changes needed

---

## Testing & Validation

### Feature 1: Multiple Folder & File Upload
- [ ] Upgrade `file_picker` to `^12.2.0` in pubspec.yaml, run `flutter pub get`
- [ ] Verify `pickFileAndDirectoryPaths()` compiles and runs on macOS
- [ ] Select mix of files and folders in single dialog, verify all appear in upload
- [ ] Verify folder structure preserved for directory selections
- [ ] Verify individual files uploaded to current prefix
- [ ] Verify progress dialog shows cumulative progress across all items
- [ ] Verify empty folder handled gracefully

### Feature 2: Drag and Drop
- [ ] Drag files onto object list area
- [ ] Drag folders onto object list area
- [ ] Verify visual feedback during drag
- [ ] Verify upload starts after drop
- [ ] Test on macOS and Windows (if applicable)

### Feature 3: Copy Across Buckets
- [ ] Select files, click Copy
- [ ] Choose different bucket from dropdown
- [ ] Enter destination path
- [ ] Verify files copied (originals still exist)
- [ ] Verify folder copy works recursively
- [ ] Verify metadata preserved

### Feature 4: Search
- [ ] Type search query, verify instant filtering
- [ ] Clear search, verify all objects reappear
- [ ] Search with no results, verify "No results" message
- [ ] Navigate to different folder, verify search cleared
- [ ] Case-insensitive search verification

---

## Potential Challenges

1. **Drag and Drop**: Flutter desktop drag-drop support may require platform-specific code or may not work consistently across platforms. May need to test on target platform.

2. **file_picker Upgrade**: Upgrading from `^6.1.1` to `^12.2.0` is a major version jump. Check for breaking changes in the API. The `pickFileAndDirectoryPaths()` method is new in v12.2.0 and may have platform-specific limitations.

3. **Search Performance**: For buckets with thousands of objects, client-side filtering should still be fast, but may need optimization if performance issues arise.

4. **Copy Across Buckets**: Cross-bucket copy requires appropriate IAM permissions. Should handle permission errors gracefully.

---

## Dependencies

- **Upgrade required**: `file_picker` from `^6.1.1` to `^12.2.0` (for `pickFileAndDirectoryPaths()` support)
- All other features use existing packages (provider, aws_s3_api)

---

## Rollout Strategy

Implement features sequentially, testing each before moving to next:
1. Implement Feature 4 (Search) → Test → Commit
2. Implement Feature 3 (Copy) → Test → Commit
3. Implement Feature 1 (Multi-folder) → Test → Commit
4. Implement Feature 2 (Drag-drop) → Test → Commit

Each feature is independent, so order can be adjusted if needed.
