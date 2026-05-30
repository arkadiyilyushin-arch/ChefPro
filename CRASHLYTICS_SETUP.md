# Adding FirebaseCrashlytics to ChefPro

The source-level integration is already in place (imports and configure calls are present but commented out). The only remaining step is linking the `FirebaseCrashlytics` product to the Xcode target.

## Option A — Xcode GUI (easiest)

1. Open `ChefPro.xcodeproj` in Xcode.
2. Click the **ChefPro** project in the Project Navigator.
3. Select the **ChefPro** app target.
4. Go to the **General** tab → scroll down to **Frameworks, Libraries, and Embedded Content**.
5. Click the **+** button.
6. In the search box type `FirebaseCrashlytics`.
7. Select **FirebaseCrashlytics** (it is part of the `firebase-ios-sdk` package already fetched by the project) and click **Add**.
8. Xcode will add the necessary entries to `project.pbxproj` automatically.

## Option B — Manual pbxproj edit

The firebase-ios-sdk remote package reference UUID in this project is:
`06C65A9E2FB828F8004DAE17`

Add the following three blocks to `ChefPro.xcodeproj/project.pbxproj`:

### 1. PBXBuildFile section (near the other Firebase entries ~line 11)
```
		AABB1100AABB1100AABB1100 /* FirebaseCrashlytics in Frameworks */ = {isa = PBXBuildFile; productRef = AABB1101AABB1101AABB1101 /* FirebaseCrashlytics */; };
```

### 2. PBXFrameworksBuildPhase (inside the `files = (...)` list for the ChefPro target ~line 66)
```
				AABB1100AABB1100AABB1100 /* FirebaseCrashlytics in Frameworks */,
```

### 3. packageProductDependencies list in the ChefPro target (~line 132)
```
				AABB1101AABB1101AABB1101 /* FirebaseCrashlytics */,
```

### 4. XCSwiftPackageProductDependency section (~line 601)
```
		AABB1101AABB1101AABB1101 /* FirebaseCrashlytics */ = {
			isa = XCSwiftPackageProductDependency;
			package = 06C65A9E2FB828F8004DAE17 /* XCRemoteSwiftPackageReference "firebase-ios-sdk" */;
			productName = FirebaseCrashlytics;
		};
```

Replace the placeholder UUIDs (`AABB1100...` / `AABB1101...`) with real unique values — run `uuidgen | tr -d '-' | head -c 24` twice to generate them.

## After linking the product

Uncomment the two lines in the source files:

**ChefProApp.swift**
```swift
import FirebaseCrashlytics
// ...
Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
```

**Store.swift** (inside `logError(_:context:)`)
```swift
Crashlytics.crashlytics().record(error: error)
```

## Uploading dSYMs for symbolication

Add a Run Script build phase **after** the Compile Sources phase:

```sh
"${BUILD_DIR%Build/*}SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
```

Input files:
```
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}
$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)
```

This uploads dSYMs automatically on each archive build so crash reports are fully symbolicated.
