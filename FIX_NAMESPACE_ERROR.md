# Fix Namespace Error - Google ML Kit

## Lỗi gặp phải

```
Could not create an instance of type com.android.build.api.variant.impl.LibraryVariantBuilderImpl.
Namespace not specified for google_mlkit_commons
```

## ✅ Đã fix

### 1. Cập nhật version google_mlkit_face_detection

**File: `pubspec.yaml`**
```yaml
google_mlkit_face_detection: ^0.11.0  # Từ 0.7.0 lên 0.11.0
```

### 2. Cải thiện xử lý namespace

**File: `android/build.gradle`**
- Thêm logic tự động extract namespace từ AndroidManifest.xml
- Fallback về project.group hoặc default namespace

### 3. Thêm compatibility flags

**File: `android/gradle.properties`**
```properties
android.defaults.buildfeatures.buildconfig=true
android.nonTransitiveRClass=false
android.nonFinalResIds=false
```

## 🔧 Các bước đã thực hiện

```bash
# 1. Clean project
flutter clean

# 2. Get dependencies với version mới
flutter pub get

# 3. Build lại
flutter build apk --debug
# hoặc
flutter run
```

## 📝 Nếu vẫn lỗi

### Option 1: Xóa cache Gradle

```bash
# Windows
cd android
.\gradlew clean
cd ..

# Xóa .gradle folder
rm -rf android\.gradle
rm -rf android\app\.gradle

# Build lại
flutter clean
flutter pub get
flutter run
```

### Option 2: Cập nhật Gradle version

**File: `android/gradle/wrapper/gradle-wrapper.properties`**
```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.0-all.zip
```

**File: `android/settings.gradle`**
```gradle
pluginManagement {
    def flutterSdkPath = {
        def properties = new Properties()
        file("local.properties").withInputStream { properties.load(it) }
        def flutterSdkPath = properties.getProperty("flutter.sdk")
        assert flutterSdkPath != null, "flutter.sdk not set in local.properties"
        return flutterSdkPath
    }()

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.1.0" apply false
    id "org.jetbrains.kotlin.android" version "1.8.22" apply false
}

include ":app"
```

### Option 3: Fix thủ công plugin build.gradle

Nếu các cách trên không work, edit trực tiếp file plugin:

**Location:** 
```
C:\Users\[YourUser]\AppData\Local\Pub\Cache\hosted\pub.dev\google_mlkit_commons-0.8.1\android\build.gradle
```

**Thêm vào đầu block android:**
```gradle
android {
    namespace 'com.google_mlkit_commons'  // Thêm dòng này
    compileSdkVersion 33
    // ... rest of config
}
```

## ✅ Verification

Sau khi fix, verify bằng cách:

```bash
# 1. Clean
flutter clean

# 2. Get dependencies
flutter pub get

# 3. Check dependencies
flutter pub deps

# 4. Build
flutter build apk --debug

# 5. Run
flutter run
```

## 📊 Version đang dùng

- **google_mlkit_face_detection**: 0.11.0 (updated from 0.7.0)
- **google_mlkit_commons**: 0.8.1 (auto dependency)
- **camera**: 0.10.0
- **tflite_flutter**: 0.9.0

## 🔍 Root Cause

Lỗi này xảy ra do:
1. Android Gradle Plugin 8.0+ yêu cầu namespace trong build.gradle
2. Các version cũ của ML Kit plugins chưa có namespace
3. Flutter chưa tự động handle namespace cho plugins

## 💡 Prevention

Để tránh lỗi tương tự:
1. Luôn dùng version mới nhất của plugins
2. Thêm namespace handling trong `android/build.gradle`
3. Set compatibility flags trong `gradle.properties`
4. Test sau mỗi lần update dependencies

## 📞 Support

Nếu vẫn gặp lỗi:
1. Check Flutter version: `flutter --version`
2. Check Gradle version: `cd android && .\gradlew --version`
3. Review error logs: `flutter run -v`
4. Clean all caches: `flutter clean && cd android && .\gradlew clean`
